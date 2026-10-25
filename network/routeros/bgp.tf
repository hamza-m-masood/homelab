# The hAP peers with each node's Cilium BGP control plane. It accepts only
# /32s from the LoadBalancer pool and advertises nothing back: the nodes
# already have a default route via the mgmt gateway.

locals {
  # Off for now: provider 1.99.1 always sends add-path-out, which RouterOS
  # 7.25 rejects (it became output.add-path). The sessions only matter once
  # Cilium runs BGP (phase 3); switch on when the provider catches up.
  bgp_connections_enabled = false
}

resource "routeros_routing_bgp_instance" "lab" {
  name      = "lab"
  as        = local.bgp.router_as
  router_id = local.bgp.router_id
}

resource "routeros_routing_filter_rule" "from_cilium" {
  chain = "bgp-in-cilium"
  rule  = "if (dst in ${local.lb_pool} && dst-len == 32) { accept } else { reject }"
}

resource "routeros_routing_filter_rule" "to_cilium" {
  chain = "bgp-out-cilium"
  rule  = "reject"
}

resource "routeros_routing_bgp_connection" "node" {
  for_each = local.bgp_connections_enabled ? local.nodes : {}

  name      = each.key
  instance  = routeros_routing_bgp_instance.lab.name
  as        = local.bgp.router_as
  hold_time = "30s"
  connect   = true
  listen    = true

  local {
    address = local.mgmt.gateway
    role    = "ebgp"
  }

  remote {
    address = each.value.ip
    as      = local.bgp.cluster_as
  }

  input {
    filter = routeros_routing_filter_rule.from_cilium.chain
  }

  output {
    filter_chain = routeros_routing_filter_rule.to_cilium.chain
  }
}
