# The radios exist from the factory, so they are imported by name rather
# than created.
import {
  for_each = local.radios
  to       = routeros_wifi.radio[each.key]
  id       = each.key
}

resource "routeros_wifi" "radio" {
  for_each = local.radios

  name     = each.key
  disabled = false

  configuration = {
    mode    = "ap"
    ssid    = "lab"
    country = "Ireland"
  }

  security = {
    authentication_types = "wpa2-psk,wpa3-psk"
    passphrase           = var.wifi_passphrase
  }
}
