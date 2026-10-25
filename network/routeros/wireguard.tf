# Access from the home LAN (the Virgin hub can't route to the lab) and,
# with a UDP port forward on the hub, from outside.

resource "routeros_interface_wireguard" "wg" {
  name        = "wg0"
  listen_port = local.wireguard.port
  # No private_key: the router generates one, and it only ever lives in
  # the encrypted state.
}

resource "routeros_ip_address" "wireguard" {
  address   = local.wireguard.address
  interface = routeros_interface_wireguard.wg.name
}

resource "routeros_interface_wireguard_peer" "peer" {
  for_each = var.wireguard_peers

  interface       = routeros_interface_wireguard.wg.name
  name            = each.key
  public_key      = each.value.public_key
  allowed_address = [each.value.address]
  comment         = each.key
}
