#!/bin/bash

CONTINUE=1
function error { echo "Error : $@"; CONTINUE=0; }
function die { echo "$@" ; exit 1; }
function checkpoint { [ "$CONTINUE" = "0" ] && echo "Unrecoverable errors found, exiting ..." && exit 1; }

OPENVPNDIR="/etc/openvpn"


# Providing defaults values for missing env variables
[ "$CERT_COUNTRY" = "" ]    && export CERT_COUNTRY="US"
[ "$CERT_PROVINCE" = "" ]   && export CERT_PROVINCE="AL"
[ "$CERT_CITY" = "" ]       && export CERT_CITY="Birmingham"
[ "$CERT_ORG" = "" ]        && export CERT_ORG="ACME"
[ "$CERT_EMAIL" = "" ]      && export CERT_EMAIL="nobody@example.com"
[ "$CERT_OU" = "" ]         && export CERT_OU="IT"

#VPN POOL
[ "$VPN_NETWORK" = "" ]     && export VPN_NETWORK="10.43.0.0"
[ "$VPNPOOL_CIDR" = "" ]    && export VPNPOOL_CIDR="29"
[ "$REMOTE_IP" = "" ]       && export REMOTE_IP="ipOrHostname"
[ "$REMOTE_PORT" = "" ]     && export REMOTE_PORT="1194"

#Custom VPN settings
[ "$PROTO" = "" ]           && export PROTO="tcp"
[ "$CIPHER" = "" ]          && export CIPHER="AES-128-CBC"
[ "$AUTH" = "" ]            && export AUTH="SHA1"
[ "$COMPRESS" = "" ]        && export COMPRESS=""
[ "$TUN_MTU" = "" ]        && export TUN_MTU=""
[ "$FRAGMENT" = "" ]        && export FRAGMENT=""
[ "$MSSFIX" = "" ]        && export MSSFIX=""

#IP tunnel
[ "$TUNNEL_CIDR" = "" ]    && export TUNNEL_CIDR="29"



# Checks
[ "${#CERT_COUNTRY}" != "2" ] && error "Certificate Country must be a 2 characters long string only"

checkpoint

env | grep "REMOTE_"

# Saving environment variables

[ -e "$OPENVPNDIR/auth.env" ] && rm "$OPENVPNDIR/auth.env"
env | grep "AUTH_" | while read i
do
    var=$(echo "$i" | awk -F= '{print $1}')
    var_data=$( echo "${!var}" | sed "s/'/\\'/g" )
    echo "export $var='$var_data'" >> $OPENVPNDIR/auth.env
done

env | grep "REMOTE_" | while read i
do
    var=$(echo "$i" | awk -F= '{print $1}')
    var_data=$( echo "${!var}" | sed "s/'/\\'/g" )
    echo "export $var='$var_data'" >> $OPENVPNDIR/remote.env
done

#=====[ Generating server config ]==============================================
VPNPOOL_NETMASK=$(netmask -s $VPN_NETWORK/$VPNPOOL_CIDR | awk -F/ '{print $2}')

cat > $OPENVPNDIR/server.conf <<- EOF
port 1194
proto $PROTO
link-mtu 1500
dev tun
ca easy-rsa/keys/ca.crt
cert easy-rsa/keys/server.crt
key easy-rsa/keys/server.key
dh easy-rsa/keys/dh2048.pem
cipher $CIPHER
auth $AUTH
server $VPN_NETWORK $VPNPOOL_NETMASK
keepalive 10 120
$COMPRESS
$TUN_MTU
$FRAGMENT
$MSSFIX
persist-key
persist-tun
client-to-client
username-as-common-name
client-cert-not-required
topology subnet
script-security 3 system
auth-user-pass-verify /usr/local/bin/openvpn-auth.sh via-env

EOF

echo $OPENVPN_EXTRACONF |sed 's/\\n/\n/g' >> $OPENVPNDIR/server.conf

#=====[ Generating certificates ]===============================================
if [ ! -d $OPENVPNDIR/easy-rsa ]; then
   # Copy easy-rsa tools to /etc/openvpn
   rsync -avz /usr/share/easy-rsa $OPENVPNDIR/

    # Configure easy-rsa vars file
   sed -i "s/export KEY_COUNTRY=.*/export KEY_COUNTRY=\"$CERT_COUNTRY\"/g" $OPENVPNDIR/easy-rsa/vars
   sed -i "s/export KEY_PROVINCE=.*/export KEY_PROVINCE=\"$CERT_PROVINCE\"/g" $OPENVPNDIR/easy-rsa/vars
   sed -i "s/export KEY_CITY=.*/export KEY_CITY=\"$CERT_CITY\"/g" $OPENVPNDIR/easy-rsa/vars
   sed -i "s/export KEY_ORG=.*/export KEY_ORG=\"$CERT_ORG\"/g" $OPENVPNDIR/easy-rsa/vars
   sed -i "s/export KEY_EMAIL=.*/export KEY_EMAIL=\"$CERT_EMAIL\"/g" $OPENVPNDIR/easy-rsa/vars
   sed -i "s/export KEY_OU=.*/export KEY_OU=\"$CERT_OU\"/g" $OPENVPNDIR/easy-rsa/vars

   pushd $OPENVPNDIR/easy-rsa
   . ./vars
   ./clean-all || error "Cannot clean previous keys"
   checkpoint
   ./build-ca --batch || error "Cannot build certificate authority"
   checkpoint
   ./build-key-server --batch server || error "Cannot create server key"
   checkpoint
   ./build-dh || error "Cannot create dh file"
   checkpoint
   ./build-key --batch RancherVPNClient
   openvpn --genkey --secret keys/ta.key
   popd
fi

#=====[ Enable tcp forwarding and add iptables MASQUERADE rule ]================
echo 1 > /proc/sys/net/ipv4/ip_forward
iptables -t nat -F
#iptables -t nat -A POSTROUTING -o tun0 -j MASQUERADE
iptables -t nat -A POSTROUTING -s $VPN_NETWORK/$VPNPOOL_NETMASK -j MASQUERADE

#CUSTOM
#pridanie ipip tunnel, maska na 29 - net addr: 0,8,16...

if [ -n "$TUNNEL_LOCAL" ]; then
    ip tunnel add tun1 mode ipip remote $VPN_PEER_REMOTE local $VPN_PEER_LOCAL
	ip link set tun1 up
	ip addr add $TUNNEL_LOCAL/$TUNNEL_CIDR dev tun1
	#nastavenie t nat na containeri
	iptables -t nat -A POSTROUTING -o tun1 -j MASQUERADE
	echo "added IPIP tunnel, local address $TUNNEL_LOCAL/$TUNNEL_CIDR"
	
	if [ -n "$TRUSTED_NETWORK" ]; then
		#route do trusted zony
		ip route add $TRUSTED_NETWORK via $TUNNEL_REMOTE
		echo "added route to network $TRUSTED_NETWORK"
	fi
	
	if [ -n "$TRUSTED_NETWORK2" ]; then
		#route do trusted zony
		ip route add $TRUSTED_NETWORK2 via $TUNNEL_REMOTE
		echo "added route to network $TRUSTED_NETWORK2"
	fi
	
	if [ -n "$TRUSTED_NETWORK3" ]; then
		#route do trusted zony
		ip route add $TRUSTED_NETWORK3 via $TUNNEL_REMOTE
		echo "added route to network $TRUSTED_NETWORK3"
	fi
	
	if [ -n "$TRUSTED_NETWORK4" ]; then
		#route do trusted zony
		ip route add $TRUSTED_NETWORK4 via $TUNNEL_REMOTE
		echo "added route to network $TRUSTED_NETWORK4"
	fi
	
	if [ -n "$TRUSTED_NETWORK5" ]; then
		#route do trusted zony
		ip route add $TRUSTED_NETWORK5 via $TUNNEL_REMOTE
		echo "added route to network $TRUSTED_NETWORK5"
	fi
fi


/usr/local/bin/openvpn-get-client-config.sh > $OPENVPNDIR/client.conf

echo "=====[ OpenVPN Server config ]============================================"
cat $OPENVPNDIR/server.conf
echo "=========================================================================="


#=====[ Display client config  ]================================================
echo ""
echo "=====[ OpenVPN Client config ]============================================"
echo " To regenerate client config, run the 'openvpn-get-client-config.sh' script "
echo "--------------------------------------------------------------------------"
cat $OPENVPNDIR/client.conf
echo ""
echo "=========================================================================="
#=====[ Starting OpenVPN server ]===============================================
/usr/sbin/openvpn --cd /etc/openvpn --config server.conf
