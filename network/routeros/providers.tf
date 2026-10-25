provider "routeros" {
  hosturl  = var.routeros_url
  username = var.routeros_username
  password = var.routeros_password

  # The router's HTTPS certificate is signed by a CA created in bootstrap.rsc.
  # Its public certificate is copied here once (see the first-boot runbook).
  ca_certificate = "${path.module}/router-ca.crt"
}
