---
layout: post
title:  "Strongswan IKEv2 split/full tunnel VPN on Alpine Linux VM on Synology Diskstation"
date:   2018-04-25 00:52:05 -0700
updated: Mar 14, 2019
categories: [VPN]
tags: VPN IKEv2 Synology StrongSwan MacOS
excerpt: Ever wanted to have an always-on VPN on an iOS device? IKEv2 is the answer; unfortunately it is not properly supported by any appliances commonly laying around the house - so we'll improvise. This post is about setup and configuration of an IKEv2 VPN server based on Strongswan running inside of Alpine Linux instance in the virtual machine hosted on Synology Diskstation. Pitfalls and challenges making split-tunnel work seamlessly. And don't have your hopes up too high -- while both full tunnel and split tunnel work just fine on a routing level it is not currently possible to make split-DNS work seamlessly enough, without client-side configuration. See closing notes for details. You might as well jump to OpenVPN article, if that is important.
---
Last [Updated](#history) Mar 14, 2019

* TOC
{:toc}

## Background

I needed to have a VPN server at home that I would connect to from anywhere to enjoy: 
1. Security of encrypted tunnel
2. Access to Web content filter deployed at home 
3. Access to machines in my home network as needed

### Requirements

Nothing unreasonable here:

1. Configuration on a client should be simple. Ideally -- one-click.
2. Connection should be automatic, resilient to network interruptions and should support always-on.
3. Routing between LAN and VPN device shall work
4. DNS resolution shall work
5. Certificate based authentication desirable. EAP will also do.
6. Support for full tunnel and split tunnel, including split-dns mode, and quick switching between the two.
7. iOS, MacOS support are a must, Windows 10 support is desirable

### What's available

- Ubiquiti USG 
    - supports remote access VPN via L2TP and OpenVPN only. 
    - IKEv2 only supported in site-to-site configuration
    
- Sophos XG v17 in bridge mode
    - supports PPTP, L2TP and OpenVPN.
    - Cannot terminate connection in bridge mode, promised in v18.
    - Does not support roadwarrior IKEv2 even in gateway mode, also promised in v18
- Synology VPN Server
    - Supports PPTP, L2TP and OpenVPN. 
    - Limited to either Server or Client but not both (This kills many useful scenarios related to on-demand data replication so it is not suitable)
    - Does not support IKEv2
    
While the OpenVPN route works reasonably well (see my previous post) and as a backup plan in case we hit a roablock we can just setup second OpenVPN server it still has two little drawbacks: 
- Requires OpenVPN app on iOS with atrocious UI and quality issues.
- Does not support always-on scenario on managed devices like IKEv2 does. 

Hence, 

## The Proposal

We shall setup IPSEC solution with IKEv2.

### What
Reviewing whats available led me to consider [Strongswan](https://www.strongswan.org) as pretty much only candidate paired with [Alpine Linux](https://www.alpinelinux.org) -- lightweight and security oriented distribution. 

### Where
I briefly considered raspberry pi: but decided against it due to low reliability and reluctance to add yet another device to the pile.

In Docker on Synology: ipsec will need to fiddle with low level networking settings on the host OS which I don't feel comfortable letting it do. 

This leaves VM. Synology DSM offers VM manager with fancy UI so this seems to be an obvious choice -- all benefits that come with VM and reliability of RAID hardware, including snapshots and great performance.

### How

Subsequent document will be a more or less step-by-step tutorial configuring and installing strongswan in Alpine Linux on Synology VM with IKEv2 with split-tunnel and full-tunnel support. Note Notes sections, these are important.

### Caveats

Read [Closing Notes](#closing-notes) for important details about feasibility of automatic split DNS configuration: IKEv2 does not yet support payload types to provision clients with the private DNS configuration. This means for split DNS to work client-side configuration is unavoidable, at least for now. 

## Assumptions

We will make the following assumptions:

    LAN:        10.0.17.0/24
    VPN:        10.0.26.0/24
    DNS:        10.0.17.1
    Synology:   10.0.17.130
    VM:         10.0.17.250
    FDQN:       vpn.example.com
    User1:      greg; greg@example.com
    User2:      emili; emili@example.com
    IPv6:       We don't bother for now

## Creating Alpine Linux VM on Synology Diskstation 6
  
### Prepare the VM

- [Download Alpine Linux Virtual](https://www.alpinelinux.org/downloads/) `x86_64` iso image and save to on the share.
- Go to Package Center and install [Virtual Machine Manager](https://www.synology.com/en-us/dsm/feature/virtual_machine_manager)
- Create a new virtual machine
    - Start Virtual Machine Manager.
        - If it prompts to enable vSwitch -- you can skip it here.
    - Select `Virtual Machine` in the side bar and click `Create`
    - Select `Linux` or `Other` and specify the following settings:
        - Name: `StrongSwan VM`
        - CPU(s): One is enough
        - Memory: `128 Mb` 
        - Video card: Does not matter. 
        - Storage location: `VM Storage 1`
    - Click Next to go to Storage page
        - ISO File for bootup: Select iso we downloaded in step 1
        - Virtual Disk: `256Mb` is more than enough. Default VirtIO controller is also fine.
    - Click Next to go to Network page.
        - Select `Default VM Network` here.
    - Next to go to Other Settings
        - Autostart: Set to `Yes`. 
        - Leave the rest as default.
    - Next to Permissions page
        - Select users you want to be able to manage the VM. at least admin.
    - Click next, check Power On and Apply.


### Configuring Alpine Linux
We'll need to access the VM through Synology VM Manger provided framebuffer only once, to configure networking and enable SSH. After that subsequent configuration will be done via SSH directly on VM.

- Select newly started virtual machine from the list and click `Connect`. Synology will open another browser window with access to terminal of the client machine. 
- Login as `root` without password.
- Execute [setup\_alpine](https://wiki.alpinelinux.org/wiki/Alpine_setup_scripts). It will be asking a bunch of questions, anwer as you wish, except important ones are outlined below
    - Networking: `DHCP`
    - SSH daemon: `OpenSSH`
    - Installation Mode: `sys`
    - Disk: `/dev/sda`  
- Reboot, and login again
- Create `~/.ssh/authorized_users` and place your public key there (you can just scp it from another machine). Don't forget to set correct permissions:
``` bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys 
```
An alternative would be to uncomment `PasswordAuthentication yes` in `/etc/ssh/sshd_config`, then `ssh-copy-id` from another machine and disable password auth again.
- While at it, configure guest agent for Qemu to communicate with Synology VM host to facilitate snapshots safety among other things.
    - Install by running `apk add qemu-guest-agent`
    - Configure device path: in the `/etc/conf.d/qemu-guest-agent` add line 
``` config
GA_PATH="/dev/vport1p1"
```
    - Start agent and verify the status:
``` bash
service qemu-guest-agent start
service qemu-guest-agent status
```
    - Set runlevel to default for it to auto-start next time and verify
``` bash
rc-update add qemu-guest-agent default
rc-status
```

Now you can close the console and move over to your favourite terminal.

### Installing StrongSwan 
SSH to Alpine as root. It should authenticate with your SSH private key.

Install software:

``` bash
apk --update add \
    bash \
    build-base \
    curl \
    curl-dev \
    ca-certificates \
    ip6tables \
    iproute2 \
    iptables-dev \
    openssl \
    openssl-dev 
``` 
Download, build and install strongswan:

``` bash
mkdir -p /tmp/strongswan
curl -Lo /tmp/strongswan.tar.bz2 \
    https://download.strongswan.org/strongswan.tar.bz2
tar --strip-components=1 -C /tmp/strongswan -xjf /tmp/strongswan.tar.bz2
cd /tmp/strongswan
./configure --prefix=/usr \
            --sysconfdir=/etc \
            --libexecdir=/usr/lib \
            --with-ipsecdir=/usr/lib/strongswan \
            --enable-aesni \
            --enable-chapoly \
            --enable-cmd \
            --enable-curl \
#            --enable-dhcp \
#            --enable-farp \
            --enable-eap-dynamic \
            --enable-eap-identity \
            --enable-eap-md5 \
            --enable-eap-mschapv2 \
            --enable-eap-radius \
            --enable-eap-tls \
            --enable-files \
            --enable-gcm \
            --enable-md4 \
            --enable-newhope \
            --enable-ntru \
            --enable-openssl \
            --enable-sha3 \
            --enable-shared \
            --disable-aes \
            --disable-des \
            --disable-gmp \
            --disable-hmac \
            --disable-ikev1 \
            --disable-md5 \
            --disable-rc2 \
            --disable-sha1 \
            --disable-sha2 \
            --disable-static && \
make && \
make install && \
cd        
```

Cleanup:

``` bash
rm -rf /tmp/*
apk del build-base curl-dev openssl-dev
rm -rf /var/cache/apk/*
```

#### Notes
Note DHCP and FARP are not enabled. Will explain later.

## Preparing configuration files for ipsec
I've used [these](https://github.com/stanback/alpine-strongswan-vpn) as a template. 

### /etc/ipsec.d/ipsec.conf

``` config
config setup
  uniqueids=no

conn %default
  keyexchange=ikev2
  ikelifetime=60m
  keylife=20m
  rekeymargin=3m
  keyingtries=1
  rekey=no
  ike=chacha20poly1305-prfsha256-newhope128,chacha20poly1305-prfsha256-ecp256,aes128gcm16-prfsha256-ecp256,aes256-sha256-modp2048,aes256-sha256-modp1024!
  esp=chacha20poly1305-newhope128,chacha20poly1305-ecp256,aes128gcm16-ecp256,aes256-sha256-modp2048,aes256-sha256,aes256-sha1!
  dpdaction=clear
  dpddelay=120s
  auto=add

conn roadwarrior-full
  left=%any
# This is "Remote ID" that we'll use on the client to select connection. See notes below
  leftid=@full-tunnel.vpn.example.com
  leftauth=pubkey
  leftcert=server_cert.pem
  leftsendcert=always
  leftsubnet=0.0.0.0/0
  leftupdown=/etc/ipsec.d/firewall.updown
  right=%any
  rightauth=pubkey
  rightsourceip=10.0.24.0/24
  rightdns=10.0.17.1

# the only difference here we narrow down left subnet
conn roadwarrior-split
  also=roadwarrior-full
  leftid=@split-tunnel.vpn.example.com
  leftsubnet=10.0.17.0/24

# These two if we want MSCHAPv2 EAP authentication
conn roadwarrior-eap-full
  also=roadwarrior-full
  rightauth=eap-dynamic
  eap_identity=%any

conn roadwarrior-eap-split
  also=roadwarrior-split
  rightauth=eap-dynamic
  eap_identity=%any

# These two for public key authentication
conn roadwarrior-pubkey-eap-full
  also=roadwarrior-full
  rightauth2=eap-dynamic
  eap_identity=%any

conn roadwarrior-pubkey-eap-split
  also=roadwarrior-split
  rightauth2=eap-dynamic
  eap_identity=%any

```

#### Notes
`leftid` shall be mentioned in server certificate, even though it is fake name we just use to select the connection from the client.

`@` means literal, as in "do not resolve".

`leftsubnet` defines the narrowed down networks and even [ports and protocols if needed](https://wiki.strongswan.org/projects/strongswan/wiki/ConnSection) that implements split tunnel for us. 

For `rightsourceip` we have four choices in theory: let strongswan assign virtual IP or delegate that to a nearby DHCP server. In either case we need to make a decision whether we want roadwarrior clients to become part of the same subnet or live on a separate virtual one. 

Lets consider each possibility: 

__Same subnet, no dhcp forwarding.__ 
We will need to ensure that source IP range provided does not overlap with LAN's DHCP server range. 

__Same subnet, dhcp plugin.__ 
Setting `rightsourceip=%dhcp` will tell Strongswan to forward DHCP requests to nearby DHCP server, [configured separately](https://wiki.strongswan.org/projects/strongswan/wiki/DHCPPlugin). Since this situation is a bit confusing -- virtual clients map all to the same mac address -- we'll need to enable [FARP plugin](https://wiki.strongswan.org/projects/strongswan/wiki/FARPPlugin) (fake ARP?) for the VPN server to respond to ARP requests on behalf of VPN clients. 

This setup would be perfect; DHCP options -- such as search domain and suffix -- get delivered to VPN clients seamlessly and because everything is handeld by the single DHCP and DNS server local name resolution "just works".

Unfortunately, this turned out to be far from rainbows and unicorns. It did not work very well, if at all, for no good reason, causing wierd DHCP issues, including duplicate leases. Digging further I stumbled upon [this comment](https://community.ubnt.com/t5/EdgeRouter/StrongSwan-Plugins-DHCP-FARP-missing-in-FW-1-9-1/m-p/2068175/highlight/true#M178168) on Ubuquiti forums that hints that this feature may be broken at the moment.

[Bummer](https://www.bing.com/search?q=define+bummer).

__Different subnet, no dhcp.__ 
This works right away, but I don't see a way to push DHCP options -- DNS server and/or search domain -- which makes split-tunnel case worrisome. 

Maybe not related -- but for some reason MacOS VPN config ignored DNS settings when I manually set them in the connection properties either. This is something that needs to be looked at separately. 

As a side note -- I could not get the ipsec to push correct netmask to clients either -- i.e. I send `10.0.22.0/24` but clients end up with `10.0.22.0/8` instead. This does not matter yet -- as it still works -- but it bothers me.
 
__Different subnets, forward dhcp, no farp.__
This will require setting up another DHCP server, perhaps on the same virtual machine; ensuring that it does not respond on requests from LAN and let it handle issuing virtual addresses and pushing options. 

Now we have two DHCP servers and extra effort is needed to make local name resolution work accross subnets

### /etc/ipsec.d/ipsec.secrets
``` config
# VPN Server private key
: RSA server_key.pem

# EAP secrets if MSCHAPv2 is desired instead of certificates
greg  : EAP "crazy-long-pass-if-greg-does-not-want-to-use-keys"
emili : EAP "even-longer-passw-for-similar-situation-that-might-arize"

# Users' private keys
: RSA greg_key.pem
: RSA emili_key.pem

```
### /etc/strongswan.conf
``` config
charon {
  send_vendor_id = yes
  dns1 = 10.0.17.1
  dns2 = 10.0.17.1
  plugins {
    eap-dynamic {
      preferred = mschapv2, tls, md5
    }
    dhcp {
      identity_lease = no
    }
  }
}
```
#### Notes
1. identity_lease must be off -- otherwise bad things happen -- it would assign same IP address if the same user connects from two devices.  Perhaps it's a bug but I've turned this off fir the time.
2. It would be better to edit files under `/etc/strongswan.d/charon/` and include those above, but this is easier for testing.

### /etc/sysctl.d/99-strongswan.conf
``` config
net.ipv4.ip_forward=1
```

### /etc/ipsec.d/firewall.updown
This is copied entirely from the github project I referenced above. It is important to include this if either server or client or both are behind NAT. The other way to handle it to configre [leftfirewall/rihgtfirewall](https://wiki.strongswan.org/projects/strongswan/wiki/ConnSection) options but those are deprecated(citation needed).
 
``` config
case $PLUTO_VERB in
  up-client)
    IF=$(ip r get ${PLUTO_PEER_CLIENT}|sed -ne 's,^.*dev \(\S\+\) .*,\1,p')
    # NAT for using local IPV4 address in rightsourceip:
    iptables -t nat -A POSTROUTING -s ${PLUTO_PEER_CLIENT} -o $IF -m policy --dir out --pol ipsec -j ACCEPT
    iptables -t nat -A POSTROUTING -s ${PLUTO_PEER_CLIENT} -o $IF -j MASQUERADE
    ;;
  down-client)
    IF=$(ip r get ${PLUTO_PEER_CLIENT}|sed -ne 's,^.*dev \(\S\+\) .*,\1,p')
    # NAT for using local IPV4 address in rightsourceip:
    iptables -t nat -D POSTROUTING -s ${PLUTO_PEER_CLIENT} -o $IF -m policy --dir out --pol ipsec -j ACCEPT
    iptables -t nat -D POSTROUTING -s ${PLUTO_PEER_CLIENT} -o $IF -j MASQUERADE
    ;;
  up-client-v6)
    IF=$(ip -6 r get ${PLUTO_PEER_CLIENT%????}|sed -ne 's,^.*dev \(\S\+\) .*,\1,p')
    # ARP proxy for using public IPv6 address in rightsourceip:
    #ip -6 neigh add proxy ${PLUTO_PEER_CLIENT%????} dev $IF
    # NAT for using local IPv6 address in rightsourceip:
    ip6tables -t nat -A POSTROUTING -s ${PLUTO_PEER_CLIENT%????} -o $IF -m policy --dir out --pol ipsec -j ACCEPT
    ip6tables -t nat -A POSTROUTING -s ${PLUTO_PEER_CLIENT%????} -o $IF -j MASQUERADE
    ;;
  down-client-v6)
    IF=$(ip -6 r get ${PLUTO_PEER_CLIENT%????}|sed -ne 's,^.*dev \(\S\+\) .*,\1,p')
    # ARP proxy for using public IPv6 address in rightsourceip:
    #ip -6 neigh delete proxy ${PLUTO_PEER_CLIENT%????} dev $IF
    # NAT for using local IPv6 address in rightsourceip:
    ip6tables -t nat -D POSTROUTING -s ${PLUTO_PEER_CLIENT%????} -o $IF -m policy --dir out --pol ipsec -j ACCEPT
    ip6tables -t nat -D POSTROUTING -s ${PLUTO_PEER_CLIENT%????} -o $IF -j MASQUERADE
    ;;
esac
```


## Setting up PKI and generating certificates
To generalize slightly lets define some variables:
``` bash
#!/bin/bash
# Country code and Org name
C="ZU"
O="Home Sweet Home"

# Root Certificate Configuration
CA_DN="C=$C, O=$O, CN=Greg and Emili Household Root CA" 
CA_KEY="/etc/ipsec.d/private/ca_key.pem"
CA_CERT="/etc/ipsec.d/cacerts/ca_cert.pem"

# VPN Server Configuration
DOMAIN="example.com"
SERVER_SAN="vpn.$DOMAIN"
REMOTE_ID_FULL="full-tunnel.$SERVER_SAN"
REMOTE_ID_SPLIT="split-tunnel.$SERVER_SAN"

SERVER_DN="C=$C, O=$O, CN=$SERVER_SAN"
SERVER_KEY="/etc/ipsec.d/private/server_key.pem"
SERVER_CERT="/etc/ipsec.d/certs/server_cert.pem"

```

PKI generation. Note multiple `--san` arguments to support selectors.
``` bash
echo "Generating private key for CA"
ipsec pki --gen --outform pem > "$CA_KEY"

echo "Generating self-signed certificate for the CA"
ipsec pki --self \
    --in "$CA_KEY" \
    --dn "$CA_DN" \
    --ca --outform pem > "$CA_CERT"

echo "Generating private key for the VPN server"
ipsec pki --gen --outform pem > "$SERVER_KEY"

echo "Generating and signing x509 certificate for the server"
ipsec pki --issue \
    --in "$SERVER_KEY" --type priv \
    --cacert "$CA_CERT" --cakey "$CA_KEY" \
    --dn "$SERVER_DN" \
    --san="$SERVER_SAN" \
    --san="$REMOTE_ID_FULL" \
    --san="$REMOTE_ID_SPLIT" \
    --flag serverAuth --flag ikeIntermediate \
    --outform pem > "$SERVER_CERT"
```

And now generate client certificates. Pack them to p12 while at it for ease of deployment.

``` bash

function generate_client(){
    name="$1"
    keyname="${name}_key.pem"
    certname="${name}_cert.pem"
    p12name="${name}_cert.p12"
    CLIENT_CN="${name}@$DOMAIN"

    echo "Generting private key for the user $name"
    ipsec pki --gen \
        --outform pem > /etc/ipsec.d/private/"$keyname"

    echo "Generting and signing certificate for the user $name"
    ipsec pki --issue \
        --in /etc/ipsec.d/private/"$keyname" \
        --type priv \
        --cacert "$CA_CERT" --cakey "$CA_KEY" \
        --dn "C=$C, O=$O, CN=$CLIENT_CN" \
        --san="$CLIENT_CN" \
        --outform pem > /etc/ipsec.d/certs/"$certname"

    echo "Exporting p12 for the user $name"
    openssl pkcs12 -export \
        -inkey /etc/ipsec.d/private/"$keyname" \
        -in /etc/ipsec.d/certs/"$certname" \
        -name "$CLIENT_CN" \
        -certfile "$CA_CERT" \
        -caname "$CN" \
        -out /etc/ipsec.d/"$p12name"
}

echo Generating Clients
generate_client "greg"
generate_client "emili"

```

### Notes
1. Above we set `leftsendcert=always` so we don't need to distribute server certificate. We only need to deploy Root CA certificate.
2. During generation of client certificates you'll be prompted for encryption passphrase to protect users keys. Save them and provide to the users separately from the p12 files.
3. Retrieve Root CA certificate and client p12 files along with export passwords for Certificate based authentication or CHAP secrets for MSCHAPv2.

## Network infrastructure configuration
### DHCP
Setup your DHCP server to issue the same address to the VPN Server. How to do that depends on your DHCP server.
### DNS
If external IP is not static and DDNS has not been setup configure DDNS client to update `vpn.example.com` to your gateway
### Routing
On your gateway configure routing rules to send traffic destined to VPN subnet to the VM instance. This will allow you to access devices over VPN from your LAN

### Port forwarding
Forward IP security ports `udp/500` and `udp/4500` to VPN Server and allow `AH`, `ESP`, `IKE` traffic to VPN server 



## Configuring client devices

### MacOS

Setting up VPN IKEv2 network connection in System Preferences -> Network should be straightforward and it works great for Full tunnel case. 

For the split-tunnel case while the ip routing works correctly it is not clear how to make split-DNS work seamlessly enough, without manual client-side configuration. See [Closing Notes](#closing-notes) for details.

There are few ways I've tried to get DNS search suffix and resolver pushed / configured, including setting up dedicated dnsmasq server for virtual clients with `%dhcp` option; however this did not result in anything but longer connection setup time; ultimately dns server and search domain pushed that way would only affect scoped queries which is not very useful.

The alternative is to keep using ispec to virtual IP addresses (and get rid of the extra complexity associated with the additional DHCP server. I therefore commented out the dhcp plugin; alternatively one could tell charon what plugins to load without recompiling it) and attempt to make necessary changes to support split channel on the client. 

I did not yet find out how to force MacOS to first search resolver for the VPN network - i.e. for `ping chipmunk` to result in query for `chipmunk.home.example.com`; but I did find a way for at lest FDQN resolution to work:

Create  `/etc/resolver/` directory and place file names `home.example.com` inside with the content pointing to the nameserver: `nameserver 10.0.17.1`.

This however breaks resolution of home.example.com itself - so if that is FDQN of your server - you'll have to remove that configuration when VPN is down. 

It would be great to have an properly implemented DNS-aware client for IKEv2 for MacOS such as Viscosity or VPN Tracker that will properly handle this - if you know one let me know.  

### iOS
Configuring is also straightforward - import the p12 file to use key based authentication or use EAP secrets. This works very well, the tunnel is setup almost instantly and is farily quick and work flawlessly with full tunnel mode.

Split-tunnel also works just fine, however not split-DNS. I don't have a working solution from Split-DNS case yet.

## Debugging
To immediately see what's going on stop the service and run it with `--debug` and `--nofork` options. 
``` bash
ipsec stop
ipsec start --nofork --debug
```
The output is fairly verbose I found there is no need to [tweak logging](https://wiki.strongswan.org/projects/strongswan/wiki/LoggerConfiguration) level to resolve most of the connectivity/certificate/authentication issues.

## Closing notes
This seems to work very well for full tunnel scenarios. 
Split tunnels also work, however there is no clear path to make split-DNS to work in a friendly way (on a desktop) or at all (on mobiles).

There is a draft proposal called [Split DNS Configuration for IKEv2](https://datatracker.ietf.org/doc/draft-ietf-ipsecme-split-dns/) to add payload attribute types `INTERNAL_DNS_DOMAIN` and `INTERNAL_DNSSEC_TA` to address this. I guess we'll have to wait.

## References
- [alpine-strongswan-vpn](https://github.com/stanback/alpine-strongswan-vpn)
- [Alpine Linux Installation](https://wiki.alpinelinux.org/wiki/Installation)
- [Forwarding and split tunneling](https://wiki.strongswan.org/projects/strongswan/wiki/ForwardingAndSplitTunneling)
- [Windows 7 Certificate Requirements](https://wiki.strongswan.org/projects/strongswan/wiki/Win7CertReq)
- [ietf proposal for Split DNS Configuration for IKEv2](https://datatracker.ietf.org/doc/draft-ietf-ipsecme-split-dns/)

## History

|------|------|
|March 25, 2018 | initial publication|
|April 25, 2018 | Added Qemu guest agent configuration|
|March 14, 2019 | Clarified split-tunnel and split-DNS support|
