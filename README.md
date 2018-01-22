# mkvpn
Configurable OpenVPN server with Mikrotik clients support


Image configuration:

Mandatory variables

AUTH_USERNAME - openvpn username

AUTH_PASSWORD - openvpn password



Main variables

VPN_NETWORK (default - 10.43.0.0) - network address of VPN network

VPNPOOL_CIDR (default - 29) - mask prefix for vpn network

PROTO (default - tcp) - network mode of VPN server (tcp / udp)

CIPHER (default - AES-128-CBC )

AUTH (default - SHA1 )

COMPRESS (default empty) (comp-lzo)



Custom variables (IPIP tunnel)

TUNNEL_LOCAL - ip address local interface of IPIP tunnel

TUNNEL_REMOTE - ip address remote interface of IPIP tunnel

TUNNEL_CIDR - (default - 29) - mask prefix for tunnel network

VPN_PEER_LOCAL - local VPN ip address

VPN_PEER_REMOTE - remote VPN ip address

TRUSTED_NETWORK - route to client network (format 192.168.100.0/24)

TRUSTED_NETWORK2 - route to client network (format 192.168.100.0/24)

TRUSTED_NETWORK3 - route to client network (format 192.168.100.0/24)

TRUSTED_NETWORK4 - route to client network (format 192.168.100.0/24)

TRUSTED_NETWORK5 - route to client network (format 192.168.100.0/24)

