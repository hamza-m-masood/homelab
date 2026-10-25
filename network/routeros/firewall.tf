# Rules are applied in list order (routeros_move_items enforces it), keyed by
# name so inserting a rule doesn't renumber and recreate the others.
# Intent is documented in docs/network.md, "Firewall intent".
#
# Each chain ends in a drop, defined separately below and created only after
# every other rule. Created in parallel with the rest, a drop can land in
# front of the accepts mid-apply and cut OpenTofu off from the router (seen
# when testing against RouterOS CHR).
#
# Renaming a rule recreates it. Never rename in-established or in-admin:
# while they're gone, the drop at the end of the chain blocks the apply.

locals {
  fw_admin = routeros_interface_list.admin.name
  fw_mgmt  = routeros_interface_list.mgmt.name
  fw_wan   = routeros_interface_list.wan.name

  node_ips = "${local.nodes.node1.ip}-${local.nodes.node3.ip}"

  firewall_rules = [
    # Traffic to the router itself.
    { name = "in-established", chain = "input", action = "accept", connection_state = "established,related,untracked" },
    { name = "in-invalid", chain = "input", action = "drop", connection_state = "invalid" },
    { name = "in-icmp", chain = "input", action = "accept", protocol = "icmp" },
    { name = "in-admin", chain = "input", action = "accept", in_interface_list = local.fw_admin },
    { name = "in-mgmt-dns-udp", chain = "input", action = "accept", in_interface_list = local.fw_mgmt, protocol = "udp", dst_port = "53" },
    { name = "in-mgmt-dns-tcp", chain = "input", action = "accept", in_interface_list = local.fw_mgmt, protocol = "tcp", dst_port = "53" },
    { name = "in-mgmt-dhcp", chain = "input", action = "accept", in_interface_list = local.fw_mgmt, protocol = "udp", dst_port = "67" },
    { name = "in-mgmt-bgp", chain = "input", action = "accept", in_interface_list = local.fw_mgmt, protocol = "tcp", dst_port = "179", src_address = local.node_ips },
    { name = "in-wan-wireguard", chain = "input", action = "accept", in_interface_list = local.fw_wan, protocol = "udp", dst_port = tostring(local.wireguard.port) },

    # Traffic through the router.
    { name = "fwd-fasttrack", chain = "forward", action = "fasttrack-connection", connection_state = "established,related" },
    { name = "fwd-established", chain = "forward", action = "accept", connection_state = "established,related,untracked" },
    { name = "fwd-invalid", chain = "forward", action = "drop", connection_state = "invalid" },
    { name = "fwd-admin-kube-talos", chain = "forward", action = "accept", in_interface_list = local.fw_admin, out_interface_list = local.fw_mgmt, protocol = "tcp", dst_port = "6443,50000" },
    { name = "fwd-admin-mgmt-icmp", chain = "forward", action = "accept", in_interface_list = local.fw_admin, out_interface_list = local.fw_mgmt, protocol = "icmp" },
    { name = "fwd-admin-lb-pool", chain = "forward", action = "accept", in_interface_list = local.fw_admin, dst_address = local.lb_pool },
    { name = "fwd-mgmt-internet", chain = "forward", action = "accept", in_interface_list = local.fw_mgmt, out_interface_list = local.fw_wan },
    { name = "fwd-admin-internet", chain = "forward", action = "accept", in_interface_list = local.fw_admin, out_interface_list = local.fw_wan },
  ]

  firewall_rule_defaults = {
    connection_state   = null
    in_interface_list  = null
    out_interface_list = null
    protocol           = null
    dst_port           = null
    src_address        = null
    dst_address        = null
  }

  firewall_rules_by_name = {
    for rule in local.firewall_rules : rule.name => merge(local.firewall_rule_defaults, rule)
  }
}

resource "routeros_ip_firewall_filter" "rule" {
  for_each = local.firewall_rules_by_name

  comment            = each.key
  chain              = each.value.chain
  action             = each.value.action
  connection_state   = each.value.connection_state
  in_interface_list  = each.value.in_interface_list
  out_interface_list = each.value.out_interface_list
  protocol           = each.value.protocol
  dst_port           = each.value.dst_port
  src_address        = each.value.src_address
  dst_address        = each.value.dst_address
}

resource "routeros_ip_firewall_filter" "drop" {
  for_each = toset(["input", "forward"])

  comment    = "${each.key}-drop"
  chain      = each.key
  action     = "drop"
  depends_on = [routeros_ip_firewall_filter.rule]
}

resource "routeros_move_items" "firewall" {
  resource_path = "/ip/firewall/filter"
  sequence = concat(
    [for rule in local.firewall_rules : routeros_ip_firewall_filter.rule[rule.name].id],
    [for chain in ["input", "forward"] : routeros_ip_firewall_filter.drop[chain].id],
  )
}

resource "routeros_ip_firewall_nat" "masquerade" {
  chain              = "srcnat"
  action             = "masquerade"
  out_interface_list = local.fw_wan
  comment            = "lab egress"
}
