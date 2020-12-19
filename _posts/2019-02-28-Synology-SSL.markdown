---
layout: post
title: "Provisioning custom SSL CA and Server Certificate to Synology Diskstation"
date: 2019-02-28 22:34:05 -0700
categories: [SSL]
tags: ["VPN", "SSL", "Certificates", "Synology",]
excerpt: How to add Self-Signed CA and Server SSL certificate to Synology DSM and configure it to be used with services. Two poorly documented pitfalls I stumbled upon.
---

* TOC
{:toc}


## Why

### Why bother to begin with?

Browsers don't' like self-signed certificates, and it's a pain to trust each certificate on each system. In addition, some browsers are stubborn enough to keep always asking for security exceptions. More in-depth pros and cons are described here: [Creating Self-Signed Certificate Authority to issue SSL certificates using Certificate Assistant on macOS]({% link _posts/2019-02-27-Root CA macOS.markdown %})

### Why not use commercial certificate?

Money.

### Why not use LetsEncrypt? 

Using LE requires one of the following to happen: 

* Hosting a webserver to the world to facilitate renewals: securing, monitoring and patching it is not something I'm looking forward to.
* Using Synology DDNS which performs DNS based validation for LE: I'd like to use my own domain instead.
* DNS-based validation: LE supports DNS validation for a number of providers that support API to manipulate TXT records. My DNS provider, Google Domains, is not one of them. At this time I'm not looking forward moving away from Google Domains for various reasons.
* LetsEncrypt can only work for FQDN that LE can verify. It will not work for LAN ip address, or hostname, or local DNS name, making it a complete no-go.

## Configuration

### Prerequisites

Follow the [guide]({% link _posts/2019-02-27-Root CA macOS.markdown %}) to create a CA and issue a new SSL Server certificate to be used on your Diskstation if you don't have one. Make sure to specify all possible FQDNs your Diskstation could be reached at: such as synobox.local, synobox.synology.me, synobox.yourdomain.com, etc

Export the following items from your keychain:

* Your CA Certificate: `ca.pem`
* SSL Server Certificate: `server.pem`
* SSL Server Private key: `server.p12`

If you exported certificates in `.cer` format, use `openssl` to convert those to plaintext `.pem`:
     
    openssl x509 -inform der -in certificate.cer -out certificate.pem

While at it, extract the private key into plaintext file as well:

    openssl pkcs12 -in server.p12 -nodes -out server.key -nocerts

### TLDR

These two points were not obvious to me:

* Specify your CA certificate in place of "Intermediate Certificate" when importing server SSL certificate. There is no (supported) way to import CA alone.
* After assigning new server certificate to VPN Server package you will need to provide your clients with updated certificates. Easiest way would be to export OpenVPN configuration again and merge your changes or just replace entire certificate chain in the existing .ovpn file with your CA certificate.

### Import certificates to DSM

* Go to `Control Panel`, `Security`, `Certificate`
* Click `Add` and select `Add a new certificate`
* Write a description in the box above. It's very handy and you cannot add it later; this is the only chance. 
* Select `Import certificate` and click `Next`
  * `server.key` goes to `Private Key` field
  * `server.pem` goes to `Certificate` field
  * `ca.pem` goes to `Intermediate Certificate` field

### Reconfigure services

Click `Configure` and select the new certificate for your services. 

If you change certificate for OpenVPN Server you also need to re-deploy the client `.ovpn` files. You can export new set and add your changes on top, or easer would be to just replace the certificates located in the `.ovpn` file with the single CA certificate enclosed in `<ca>/</ca>` tags.

You may also find useful this [Handy guide for OpenVPN configuration for Split Tunnel mode on Synology Diskstation]({% link _posts/2018-01-03-OpenVPN Split Tunnel on Synology.markdown %}).


