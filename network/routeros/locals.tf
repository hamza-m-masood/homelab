# Addressing from docs/network.md. Change that file first, then this one.

locals {
  wan_port = "ether1"

  # Owned by bootstrap.rsc, not by OpenTofu, so a bad apply can't remove the
  # way back in. Only referenced here (interface lists, firewall).
  rescue_port = "ether5"

  mgmt = {
    vlan_id = 10
    gateway = "10.10.10.1"
    prefix  = "24"
    network = "10.10.10.0/24"
    pool    = "10.10.10.100-10.10.10.199"
  }

  storage_vlan_id = 20 # L2 only: no interface or address on the router

  clients = {
    vlan_id = 30
    gateway = "10.10.30.1"
    prefix  = "24"
    network = "10.10.30.0/24"
    pool    = "10.10.30.100-10.10.30.254"
  }

  wireguard = {
    address = "10.10.40.1/24"
    port    = 51820
  }

  lb_pool  = "10.10.100.0/24"
  kube_vip = "10.10.10.10"

  nodes = {
    node1 = { port = "ether2", ip = "10.10.10.11" }
    node2 = { port = "ether3", ip = "10.10.10.12" }
    node3 = { port = "ether4", ip = "10.10.10.13" }
  }

  # wifi1 and wifi2 are the two radios; both broadcast the same SSID.
  radios = toset(["wifi1", "wifi2"])

  bgp = {
    router_as  = "65000"
    cluster_as = "65001"
    router_id  = local.mgmt.gateway
  }

  # Networks allowed to manage the router (REST API, Winbox, SSH).
  admin_networks = ["10.10.99.0/24", local.clients.network, "10.10.40.0/24"]

  upstream_dns = ["1.1.1.1", "1.0.0.1"]
}
