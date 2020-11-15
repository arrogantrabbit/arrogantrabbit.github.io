---
layout: post
title: "Provisioning custom SSL keys to Ubiquiti CloudKey and UniFi Controller"
date: 2019-02-27 00:34:05 -0700
categories: [SSL]
tags: ["MacOS", "VPN", "SSL", "Certificates", "Ubiquiti", "UniFi"]
excerpt: Could not find the guide that worked. Had to figure stuff out on my own.
---

* TOC
{:toc}

## Why?

Because browsers frown upon self-signed certificates, and it's a pain to trust each certificate on each system. In addition, some browsers are stubborn enough to keep always asking for security exceptions.

## Well, lets do this 


### Prerequisities
We'll assume that you have generated your SSL certificate and have the following files handy:

* `unifi.p12` containing private key, encrypted with pass-phrase `passphrase`
* `unifi.cer` containing certificate 

For how to generate SSL certificate please see my previous post  [Creating Self-Signed Certificate Authority to issue SSL certificates using Certificate Assistant on macOS]({% link _posts/2019-02-27-Root CA macOS.markdown %}). Make sure to specify actual FQDNs for your UniFi Controller, including `unifi` and all other FQDNs it is expected to be reached by.


### Overview
I'll be using CloudKey G2 Plus. Certificates are located under `/etc/ssl/private/`. There you will find the following:

* `cloudkey.crt` -- ssl certificate,
* `cloudkey.key` -- private key, and  
* `unifi.keystore.jks` --  same keys for UniFi in java keystore format. 
* `cert.tar` -- this must contain the above three files, content of which is compared with the contents of the directory during boot.

We need to do the following: 
* Backup current certificates
* Delete old certificates
* Delete old tar 
* Decrypt new certificates
* Import them into Java Key Store with pre-defined passphrase
* Compress the resulting data into the tar.
* Restart services


### Action

Prepare the following bash script named `dothis.sh`. Read comments for details about what's going on.

```bash
#!/bin/bash

# Backup current certificate. Just in case. Can never be too careful
tar -zcvf /root/CloudKeySSL_`date +%Y-%m-%d_%H.%M.%S`.tgz /etc/ssl/private/*

# Delete current files
rm -f   /etc/ssl/private/cert.tar                           \
        /etc/ssl/private/unifi.keystore.jks                 \
        /etc/ssl/private/unifi.keystore.jks.md5             \
        /etc/ssl/private/cloudkey.crt                       \
        /etc/ssl/private/cloudkey.key


# Unpack certificates
openssl pkcs12 -in unifi.p12 -nodes     -out /etc/ssl/private/cloudkey.key -nocerts -password pass:passphrase
openssl x509 -inform der -in unifi.cer  -out /etc/ssl/private/cloudkey.crt

# Decrypt keys and convert certificates to plain text
# Note, aircontrolenterprise is not arbitrary. this is what UniFi is expecting
openssl pkcs12 -export -in /etc/ssl/private/cloudkey.crt    \
                    -inkey /etc/ssl/private/cloudkey.key    \
                      -out /etc/ssl/private/cloudkey.p12    \
                      -name unifi -password pass:aircontrolenterprise

# Import keys into Java Key Store
keytool -importkeystore -deststorepass aircontrolenterprise \
            -destkeypass aircontrolenterprise               \
            -destkeystore /usr/lib/unifi/data/keystore      \
            -srckeystore /etc/ssl/private/cloudkey.p12      \
            -srcstoretype PKCS12 -srcstorepass aircontrolenterprise -alias unifi


# Cleanup
rm -f /etc/ssl/private/cloudkey.p12

pushd /etc/ssl/private

# Create tar file cloudkey expects
tar -cvf cert.tar *

# set permissions
chown root:ssl-cert /etc/ssl/private/*
chmod 640           /etc/ssl/private/*

popd

# Test
/usr/sbin/nginx -t
 
echo "Press enter to restart nginx and unifi"
read

/etc/init.d/nginx restart
/etc/init.d/unifi restart
```

Copy this bash script along with `unifi.p12` and `unifi.cer` to the same directory to your cloudkey, ssh to the device and execute it:

```bash
scp dothis.sh unifi.p12 unifi.cer cloudkey:
ssh cloudkey

chmod +x dothis.sh
./dothis.sh
```

## Now what?

We are done. Refresh the page in the browser and enjoy green lock and lack of security warnings for all three services: CloudKey, UniFi and Protect.