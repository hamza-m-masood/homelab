output "wireguard_public_key" {
  description = "Router's WireGuard public key, for client configs."
  value       = routeros_interface_wireguard.wg.public_key
}
