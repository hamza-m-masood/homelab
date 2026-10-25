resource "routeros_system_identity" "identity" {
  name = "router"
}

resource "routeros_system_ntp_client" "ntp" {
  enabled = true
  servers = ["time.cloudflare.com"]
}

# Management services: HTTPS (REST API for OpenTofu), Winbox and SSH,
# reachable only from admin networks. Everything else off.

locals {
  services = {
    www-ssl = { port = 443, enabled = true }
    winbox  = { port = 8291, enabled = true }
    ssh     = { port = 22, enabled = true }
    www     = { port = 80, enabled = false }
    api     = { port = 8728, enabled = false }
    api-ssl = { port = 8729, enabled = false }
    ftp     = { port = 21, enabled = false }
    telnet  = { port = 23, enabled = false }
  }
}

resource "routeros_ip_service" "service" {
  for_each = local.services

  numbers  = each.key
  port     = each.value.port
  disabled = !each.value.enabled
  address  = each.value.enabled ? join(",", local.admin_networks) : null
  # The certificate is created by bootstrap.rsc.
  certificate = each.key == "www-ssl" ? "router" : null
}

# Layer-2 management (MAC-Winbox, neighbour discovery) only on admin
# interfaces. MAC-Winbox on the rescue port is the last resort if IP config
# is broken.

resource "routeros_tool_mac_server" "mac_telnet" {
  allowed_interface_list = "none"
}

resource "routeros_tool_mac_server_winbox" "mac_winbox" {
  allowed_interface_list = routeros_interface_list.admin.name
}

resource "routeros_ip_neighbor_discovery_settings" "discovery" {
  discover_interface_list = routeros_interface_list.admin.name
}
