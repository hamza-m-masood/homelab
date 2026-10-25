# One VLAN-filtering bridge. Node ports carry mgmt untagged and storage
# tagged; the radios carry clients untagged. The router itself only joins
# mgmt and clients (via the "bridge" entry in tagged).

resource "routeros_interface_bridge" "bridge" {
  name              = "bridge"
  vlan_filtering    = true
  ingress_filtering = true
  # The bridge's own (CPU) port only takes tagged frames; it has no use for VLAN 1.
  frame_types = "admit-only-vlan-tagged"
  comment     = "lab bridge"
}

resource "routeros_interface_bridge_port" "node" {
  for_each = local.nodes

  bridge      = routeros_interface_bridge.bridge.name
  interface   = each.value.port
  pvid        = local.mgmt.vlan_id
  frame_types = "admit-all" # untagged mgmt + tagged storage
  comment     = each.key
}

resource "routeros_interface_bridge_port" "radio" {
  for_each = routeros_wifi.radio

  bridge      = routeros_interface_bridge.bridge.name
  interface   = each.value.name
  pvid        = local.clients.vlan_id
  frame_types = "admit-only-untagged-and-priority-tagged"
  comment     = "lab Wi-Fi"
}

resource "routeros_interface_bridge_vlan" "mgmt" {
  bridge   = routeros_interface_bridge.bridge.name
  vlan_ids = [tostring(local.mgmt.vlan_id)]
  tagged   = [routeros_interface_bridge.bridge.name]
  untagged = [for p in routeros_interface_bridge_port.node : p.interface]
  comment  = "mgmt"
}

resource "routeros_interface_bridge_vlan" "storage" {
  bridge   = routeros_interface_bridge.bridge.name
  vlan_ids = [tostring(local.storage_vlan_id)]
  tagged   = [for p in routeros_interface_bridge_port.node : p.interface]
  comment  = "storage (not routed)"
}

resource "routeros_interface_bridge_vlan" "clients" {
  bridge   = routeros_interface_bridge.bridge.name
  vlan_ids = [tostring(local.clients.vlan_id)]
  tagged   = [routeros_interface_bridge.bridge.name]
  untagged = [for p in routeros_interface_bridge_port.radio : p.interface]
  comment  = "clients"
}

resource "routeros_interface_vlan" "mgmt" {
  name      = "vlan${local.mgmt.vlan_id}-mgmt"
  interface = routeros_interface_bridge.bridge.name
  vlan_id   = local.mgmt.vlan_id
}

resource "routeros_interface_vlan" "clients" {
  name      = "vlan${local.clients.vlan_id}-clients"
  interface = routeros_interface_bridge.bridge.name
  vlan_id   = local.clients.vlan_id
}

# Interface lists drive the firewall and the management services.

resource "routeros_interface_list" "wan" {
  name    = "WAN"
  comment = "uplink to the Virgin hub"
}

resource "routeros_interface_list" "mgmt" {
  name    = "MGMT"
  comment = "node network"
}

resource "routeros_interface_list" "admin" {
  name    = "ADMIN"
  comment = "networks allowed to manage the lab"
}

resource "routeros_interface_list_member" "wan" {
  list      = routeros_interface_list.wan.name
  interface = local.wan_port
}

resource "routeros_interface_list_member" "mgmt" {
  list      = routeros_interface_list.mgmt.name
  interface = routeros_interface_vlan.mgmt.name
}

resource "routeros_interface_list_member" "admin" {
  for_each = {
    rescue    = local.rescue_port
    clients   = routeros_interface_vlan.clients.name
    wireguard = routeros_interface_wireguard.wg.name
  }

  list      = routeros_interface_list.admin.name
  interface = each.value
}
