#!/bin/bash

OPENVPNDIR="/etc/openvpn"
. $OPENVPNDIR/remote.env
CA_CONTENT=$(cat $OPENVPNDIR/easy-rsa/keys/ca.crt)

cat <<- EOF
remote $REMOTE_IP $REMOTE_PORT
client
dev tun
proto $PROTO
remote-random
resolv-retry infinite
cipher $CIPHER
auth $AUTH
nobind
link-mtu 1500
persist-key
persist-tun
$COMPRESS
$TUN_MTU
$FRAGMENT
$MSSFIX
verb 3
auth-user-pass
auth-retry interact
ns-cert-type server
<ca>
$CA_CONTENT
</ca>
EOF
