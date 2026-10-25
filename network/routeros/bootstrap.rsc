# Applied once, straight after a factory reset:
#   /system reset-configuration no-defaults=yes skip-backup=yes run-after-reset=bootstrap.rsc
#
# Gives the router just enough config for OpenTofu to take over: a rescue
# port, an API user and HTTPS. Everything else lives in *.tf.
#
# This is a template. `task router:bootstrap` fills in the passwords and
# writes out/bootstrap.rsc, which is the file that gets uploaded. The script
# deletes itself from the router when it finishes.

# Interfaces take a moment to appear after a reset.
:delay 15s

/system identity set name=router

# Rescue port: outside the bridge and never managed by OpenTofu, so a bad
# apply can't take away the way back in. No gateway or DNS is handed out, so
# a laptop on this port keeps using its other connection for the internet.
/ip address add address=10.10.99.1/24 interface=ether5 comment="rescue (bootstrap)"
/ip pool add name=rescue ranges=10.10.99.2-10.10.99.9 comment="rescue (bootstrap)"
/ip dhcp-server add name=rescue interface=ether5 address-pool=rescue comment="rescue (bootstrap)"
/ip dhcp-server network add address=10.10.99.0/24 comment="rescue (bootstrap)"

/user set [find name=admin] password="${ROUTEROS_ADMIN_PASSWORD}"
/user add name=tofu group=full password="${TF_VAR_routeros_password}" comment="OpenTofu (bootstrap)"

# HTTPS for the REST API. OpenTofu pins router-ca.crt, exported below.
/certificate add name=router-ca common-name=router-ca key-usage=key-cert-sign,crl-sign days-valid=3650
/certificate sign router-ca
:delay 20s
/certificate add name=router common-name=router subject-alt-name="IP:10.10.99.1,IP:10.10.10.1,IP:10.10.30.1,IP:10.10.40.1" key-usage=digital-signature,key-encipherment,tls-server days-valid=825
/certificate sign router ca=router-ca
:delay 20s
/certificate export-certificate router-ca file-name=router-ca
/ip service set www-ssl certificate=router disabled=no

/file remove bootstrap.rsc
