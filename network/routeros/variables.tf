variable "routeros_url" {
  description = "REST API endpoint. The rescue port by default; any admin network works once applied."
  type        = string
  default     = "https://10.10.99.1"
}

variable "routeros_username" {
  description = "API user created by bootstrap.rsc."
  type        = string
  default     = "tofu"
}

variable "routeros_password" {
  description = "Password of the API user. From secrets.sops.yaml."
  type        = string
  sensitive   = true
}

variable "state_passphrase" {
  description = "Passphrase for state and plan encryption. From secrets.sops.yaml."
  type        = string
  sensitive   = true
}

variable "wifi_passphrase" {
  description = "WPA2/WPA3 passphrase for the lab SSID. From secrets.sops.yaml."
  type        = string
  sensitive   = true
}

variable "domain" {
  description = "Lab domain, hosted on Cloudflare."
  type        = string
  default     = "hamzatest.com"
}

variable "wireguard_peers" {
  description = "WireGuard clients, keyed by name. Addresses come from 10.10.40.0/24."
  type = map(object({
    public_key = string
    address    = string
  }))
  default = {}
}
