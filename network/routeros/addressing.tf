resource "routeros_ip_dhcp_client" "wan" {
  interface         = local.wan_port
  add_default_route = "yes"
  use_peer_dns      = false
  use_peer_ntp      = false
  comment           = "address from the Virgin hub"
}

resource "routeros_ip_address" "mgmt" {
  address   = "${local.mgmt.gateway}/${local.mgmt.prefix}"
  interface = routeros_interface_vlan.mgmt.name
}

resource "routeros_ip_address" "clients" {
  address   = "${local.clients.gateway}/${local.clients.prefix}"
  interface = routeros_interface_vlan.clients.name
}

# DHCP on mgmt is only for Talos maintenance mode and new nodes; configured
# nodes use static addresses from their machine config.

resource "routeros_ip_pool" "mgmt" {
  name   = "mgmt"
  ranges = [local.mgmt.pool]
}

resource "routeros_ip_dhcp_server" "mgmt" {
  name         = "mgmt"
  interface    = routeros_interface_vlan.mgmt.name
  address_pool = routeros_ip_pool.mgmt.name
  # RouterOS default, set explicitly: left unset, every plan shows a diff.
  dynamic_lease_identifiers = "client-mac,client-id"
}

resource "routeros_ip_dhcp_server_network" "mgmt" {
  address    = local.mgmt.network
  gateway    = local.mgmt.gateway
  dns_server = [local.mgmt.gateway]
}

resource "routeros_ip_pool" "clients" {
  name   = "clients"
  ranges = [local.clients.pool]
}

resource "routeros_ip_dhcp_server" "clients" {
  name         = "clients"
  interface    = routeros_interface_vlan.clients.name
  address_pool = routeros_ip_pool.clients.name
  # RouterOS default, set explicitly: left unset, every plan shows a diff.
  dynamic_lease_identifiers = "client-mac,client-id"
}

resource "routeros_ip_dhcp_server_network" "clients" {
  address    = local.clients.network
  gateway    = local.clients.gateway
  dns_server = [local.clients.gateway]
}

# The router resolves for the lab. App names (argocd., grafana., ...) are
# public records managed by external-dns; infrastructure names live here.

resource "routeros_ip_dns" "dns" {
  servers               = local.upstream_dns
  allow_remote_requests = true
}

resource "routeros_ip_dns_record" "infra" {
  for_each = merge(
    { router = local.mgmt.gateway, k8s = local.kube_vip },
    { for name, node in local.nodes : name => node.ip },
  )

  type    = "A"
  name    = "${each.key}.${var.domain}"
  address = each.value
}
