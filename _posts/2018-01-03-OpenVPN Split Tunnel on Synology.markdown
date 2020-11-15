---
layout: post
title:  "OpenVPN Split Tunnel on Synology Diskstation"
date:   2018-01-03 00:52:05 -0700
updated: Oct 21, 2019
categories: [VPN]
tags: VPN Synology OpenVPN MacOS
excerpt: Exhaustive guide on configuring Synology's built-in OpenVPN server and further configuration of the .ovpn files to setup split-tunnel VPN home, emphasizing one-click client configuration, including MacOS, iOS, and Windows clients.    
---
Last [Updated](#history) Oct 21, 2019

* TOC
{:toc}

## Purpose

Remote access to home network supporting choice of split/full tunnel.

## Requirements

1. Ease of deployment. Preferably 1-click.
2. Support for MacOS, iOS and, secondarily Windows.
3. Strong encryption; compression is a plus.
4. User authentication; either by passkey or public key. In case of a passkey autoblock should be configured after few failed attempts.
5. Supported/commercial solution is a plus (as opposed to hacking one together and supporting it forever)

## What's available 

The following equipment supports Remote acces VPN:

**Unifi USG gateway**: Supports PPTP and L2TP with Radius. PPTP is not serious and L2TP clashes with Back to My Mac ports

**Sophos XG firewall**: Supports all sorts of IPSEC but can't terminate VPN connections in the bridge mode, until version 18.

**VPN Server on Synology Diskstation**: Supports PPTP, L2TP and OpenVPN, with various user authentication options - Radius, LDAP, internal user base (which uses Radius as a backend anyway, as a plugin). 

## Proposal

OpenVPN seems like obvious choice -- the only downside being Synology can either be VPN Server or VPN Client but not both. This breaks a few useful scenarios such as mutual replication but we'll deal with this later. 

## Assumptions

We will make the following assumptions:

    LAN:            10.0.17.0/24, suffix - home.example.com
    Another LAN:    10.0.16.0/24 (you might have one)
    Yet more LAN:   192.168.100.0/24 (common cable modem address)
    VPN:            10.0.22.0/24
    DNS:            10.0.17.1
    Synology:       10.0.17.130
    FDQN:           home.example.com
    User1:          greg; greg@example.com
    User2:          emili; emili@example.com
    IPv6:           We don't bother for now

## Configuring Server
### Setup OpenVPN Server
This is fairly straightforward -- from the Package Manager install OpenVPN server. 

Launch it; on the General settings select:
- Network Interface to bind to
- Account types. Supported are Local Users, LDAP and Radius, if configured.
- Configure AutoBlock

On the Privilege page select users. 

On the OpenVPN page configure the server. Sample configuration on the screenshot:

![OpenVPN configuration page]({{ "/assets/synology-openvpnserver-openvpn.png" | absolute_url }})

- Configure IP 
- Port: leave at default, `1194`
- Protocol: `UDP` works well
- Encryption: `AES-256-CBC` is recommended as secure and performant enough
- Authentication: `SHA256` shall do.
- Enable Compression. 
- Set "allow clients to access Server's LAN".

Export configuration.



### Generate and edit .ovpn profiles 

Now some trickery.

You will get four files
- VPNConfig.ovpn
- ca_bundle.crt
- ca.crt
- README.txt

Read through the VPNConfig.ovpn and make changes as directed below: 

    dev tun
    tls-client

Add FDQN pointing to your external interface - likely on a gateway. It shall be configured to update via DDNS

    remote home.example.com 1194

The [float option](https://openvpn.net/index.php/open-source/documentation/manuals/65-openvpn-20x-manpage.html) is useful for mobile clients - I haven't played with it much yet.

    # The "float" tells OpenVPN to accept authenticated packets from any address,
    # not only the address which was specified in the --remote option.
    # This is useful when you are connecting to a peer which holds a dynamic address
    # such as a dial-in user or DHCP client.
    # (Please refer to the manual of OpenVPN for more information.)

    #float

The next option `redirect-gateway` is important. You would want to make a two copies of .ovpn profiles, one we will use for split tunnel, in which `redirect-gateway` shall be commented out. 
In the other one, for full tunnel, leave it uncommented and add another line `redirect-gateway ipv6`. This is due to a requirement [described here](https://openvpn.net/vpn-server-resources/faq-regarding-openvpn-connect-ios/): 
>  Note that iOS 7 and higher requires that if redirect-gateway is used, that it is used for both IPv4 and IPv6 as the above directive accomplishes.

The end result for full tunnel version of your file should look like this:

    # If redirect-gateway is enabled, the client will redirect it's
    # default network gateway through the VPN.
    # It means the VPN connection will firstly connect to the VPN Server
    # and then to the Internet.
    # (Please refer to the manual of OpenVPN for more information.)

    redirect-gateway def1
    redirect-gateway ipv6



The `dhcp-option DNS` is configured automatically, but you would want to add the next two lines to facilitate split tunnel functionality:
 
    # dhcp-option DNS: To set primary domain name server address.
    # Repeat this option to set secondary DNS server addresses.

    dhcp-option DNS 10.0.17.1
    dhcp-option DOMAIN home.example.com
    dhcp-option DOMAIN-SEARCH home.example.com

Add additional static routes to reach other subnets if desired:

    # Additional static routes

    route 10.0.16.0 255.255.255.0 vpn_gateway
    route 192.168.100.0 255.255.255.0 vpn_gateway

    # Pull other configuration pushed from the server
    pull

If your server has an SSL certificate (for example, obtained from Lets Encrypt automatically if using Synology DDNS, or commercially purchased certificate) you might want to turn on server certificate validation. It's not much, it just requires that server certificate was signed with an explicit key usage and extended key usage based on RFC3280 TLS rules; in other words to ensure that you are connecting to a designated server. No reason not to enable it really

    remote-cert-tls server

Next, I would comment out `script-security` statement - we don't really need that, and this will avoid warnings in the clients. I would also add `auth-nocache`. Leave the rest of options intact.

    # If you want to connect by Server's IPv6 address, you should use
    # "proto udp6" in UDP mode or "proto tcp6-client" in TCP mode
    proto udp

    #script-security 2
    reneg-sec 0

    auth-nocache
    comp-lzo
    cipher AES-256-CBC
    auth SHA256
    auth-user-pass

If you see references to certificate files - insert contents of ca_bundle.crt inline.

    <ca>
    -----BEGIN CERTIFICATE-----
    ... 
    -----END CERTIFICATE-----
    -----BEGIN CERTIFICATE-----
    ...
    -----END CERTIFICATE-----
    </ca>


Now you should have `full-tunnel.ovpn` and `split-tunnel.ovpn`.

### Configure DDNS and Firewall
On your gateway and/or firewall allow OpenVPN traffic from WAN to Synology box, and forward port `1194/udp`.

## Configuring Clients
Deploy both profiles, and select one or the other depending on whether full or split tunnel is required.

### macOS
Synology recommends Tunnelblick but I had some weird issues with it, and instead suggest using [Viscosity](https://www.sparklabs.com/viscosity/) (this is a non-affiliate link) for both MacOS and Windows. 

Install it and drop .ovpn file onto it. That's pretty much the end of it, nothing else needs to change -- the default are sensible and the rest of the configuration will be populated from the ovpn file.

You would need to configure username and password, or you will be prompted when connecting, with an option to save it to keychain. The rest should just work, including split channel mode.

To confirm, on a Mac run `scutil --dns` -- observe the sequence of dns suffix and resolvers in the very top.

So, does split tunnel actually work? Well, lets try. I'm connected to corporate network corporate.com and started OpenVPN split tunnel connection to home.example.com. chipmunk.home.example.com is another machine at home. hedgehog.corporate.com is a machine at the local lan.

    $ ping chipmunk
    PING chipmunk.home.example.com (10.0.17.12): 56 data bytes
    ^C

    $ ping hedgehog
    PING hedgehog.corporate.com (172.16.11.21): 56 data bytes
    ^

Ain't that [grate](https://en.wikipedia.org/wiki/Grate)!

### iOS

On iOS it is just as easy: 
1. Install [OpenVPN Connect](https://itunes.apple.com/us/app/openvpn-connect/id590379981)
2. Airdrop yourself .ovpn profile. It will open with OpenVPN app. Add the profile when prompted. 
This works most of the time; if it does not -- email it to yourself, preferably not via Internet, use local mail-server instead in the LAN. Opening profile from the email never failed. 

Note, you would need to initiate connection from OpenVPN app; attempting to start VPN session from Settings -> VPN will not work, at least when using `user-auth-pass`.

Does split tunnel actually work here as well? Yes. You can verify by pinging similar hosts via your favorite tool (such as [Network Tools](http://networktools.he.net)).


### Windows
Haven't tried myself, but I'm pretty sure [Viscosity](https://www.sparklabs.com/viscosity/) would do just fine.

## History

|------|------|
|January 1, 2018 | Initial publication|
|February 27, 2019 | Added static routes <br>Added server certificate verification<br>Fixed a few typos|
|October 21, 2019 |Added required ipv6 configuration for iOS devices to work in full tunnel mode|
