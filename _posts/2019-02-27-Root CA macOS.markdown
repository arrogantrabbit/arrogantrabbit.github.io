---
layout: post
title:  "Creating Self-Signed Certificate Authority to issue SSL certificates using Certificate Assistant on macOS"
date:   2019-02-26 23:34:05 -0700
updated: Jul 06, 2020
categories: ["SSL"]
tags: ["MacOS", "VPN", "SSL", "Certificates"]
excerpt: This is somewhat tutorial-ish guide about creating self-signed Certificate Authority suitable for issuing of SSL certificates to be used for various servers, services, and devices to ensure "green lock" in the browsers and happy users using macOS GUI tools.
---
Last [Updated](#history) July 06, 2020


* TOC
{:toc}

## Purpose

Often devices that we use daily, such as raspberry pi hosted projects, UniFi controller, Firewall, NAS, etc, use SSL to secure communication but use self-signed certificates. While there is nothing wrong with the use of self-signed certificates per se, it is a bit annoying that you have to create security exceptions for each one on each of your user devices and in spite of that some vigilante browsers such as Chrome and Firefox still won't be happy and would be displaying crossed-out the lock and claiming that the web site is not secure. 

This is highly annoying to say the least. There are two solutions to this inconvenience:

One - pay for commercial SSL DV (possibly wildcard) certificates and install them to all devices. 
  * Pros: browsers will be happy, nothing to configure on user devices. 
  * Cons: this costs money and wildcard certificates are even more expensive. 

However if only you and a bunch of other people are the only ones who use these devices services then there is no need to pay for commercial certificate; Instead, you can create your own Certificate Authority, import it once to each device you use; set it to be trusted as as Root CA and then keep issuing certificates from it to secure your devices. 
  * Pros: It's completely Free, and provides the same security and visuals. 
  * Cons: Because devices certificates are going to be issued from the CA that your systems knows nothing about you would need to import CA certificate and mark it as trusted explicitly on each device. 

Now browsers will see that the certificates your devices and services use are non self-signed anymore but use Certificate Authority that is trusted on your system and will happily show green lock. Voila.

## Why Certificate Assistant and not easy-rsa or other PKI tools

Well, because it's already there, it's free, it is user friendly, it stores certificates in your own keychain by default and just works. I think these are the reasons enough. 


## Why this blogpost, it was covered a million times on the Internet

Yes, it was, and yet every single tutorial and blogpost I found was missing some crucial details or was blatantly wrong. This blogpost is an approach that worked for me and I successfully secured a bunch of appliances -- such as UniFi controller and Synology DiskStation.

## Creating Certificate Authority

### TLDR

Follow the wizard with a few exceptions. Parts that are important to change or important to leave as is are in **bold**: 
* Choose to Override Details, 
* Disable extended key usage

### Walk-through

* Start Keychain Access.app. 
* Select Keychain Access -> Certificate Assistant -> *Create Certificate Authority* 

#### Create Your Certificate Authority

* `Name`: Choose a friendly name for your CA
* `Identity type`: select  `Self Signed Root CA`
* `User certificate`: Does not matter, we'll delete it later. `SSL Server` for now.
* `Let me Override Defaults`: **Check**. Very important, you'll see later why. 
* `Email from`: Select email
* `Make this CA as default`: Up to you.


#### Certificate Information 
* `Serial Number`: Choose any number you like. I left it at 1.
* `Validity Period (days)`: No longer than [825 days](https://support.apple.com/en-us/HT210176)
* `Create a CA web site`: Unchecked.
* `Sign your invitation`: **Uncheck**

Press `Continue`

* `Email address`: Up to you
* `Name (Common Name)`: Select something telling, such as "My Home CA"
* `Organization`, `Unit`, `City`, `State`, `Country`: Optional


#### Key Pair Information for This CA
* `Specify Key Pair Information For This CA`: 2048/RSA [or longer](https://support.apple.com/en-us/HT210176)

Press `Continue`

* `Specify Key Pair Information For Users of This CA`: 2048/RSA [or longer](https://support.apple.com/en-us/HT210176)

Press `Continue`

#### Key Usage Extension For This CA: 
* `Include Key Usage Extensions`: Checked
* `This extension is critical`: Unchecked
* `Capabilities`: 
    * `Signature`: Checked
    * `Certificate Signing`: Checked

#### Key Usage Extension For Users of This CA: 
*  `Include Key Usage Extension`: Checked
    * `This Extension is Critical`: Checked
    * Capabilities
        * `Signature`: Checked
        * `Key Encipherment`: Checked


#### Extended Key Usage Extension For This CA
* `Include Extended Key Usage Extension`: **Uncheck**. In Catalina this seems to be already unchecked by default.

This is to make Firefox happy. See more details here: [https://bugzilla.mozilla.org/show_bug.cgi?id=1049176](https://bugzilla.mozilla.org/show_bug.cgi?id=1049176).


#### Basic Constraints Extension For This CA
* `Include Basic Constraints Extension`: Checked
    * `Use this certificate as a certificate authority`: Checked
    * `Path Length Constraint Present`: Unchecked


#### Basic Constraints Extension For Users fo This CA
* `Include Basic Constraints Extension`: Unchecked


#### Subject Alternate Name Extension for This CA
* `Include Subject Alternate Name Extension`: Unchecked, Unless you have good reason to provide alternate names


#### `Select Alternate Name for Users of This CA`
* `Include Subject Alternate Name Extensions`: Unchecked, unless you have a good reason otherwise


#### Specify a Location for the certificate
You can decide to save your certificate authority to Login or System keychain. If you select System then before finalizing the certificate creation you would need to go back to Keychain Access app, right click on the System keychain and **Unlock** it. Otherwise the certificate assistant will fail with incomprehensible error message.

* `Keychain`: System
* `Trust certificates signed by this CA on this machine`: **Check**

Now press `Create` and provide your password a bunch of time - to import into system keychain and to mark is as trusted. 

Now we have the Certificate Authority. We can now issue certificates from it. 


## Distributing Root CA to clients

Export the CA certificate and distribute it to clients. 

### On a macOS

Double click the certificate to import it into Keychain. Find it there and mark as Trusted.

### On Windows 

See this post: [https://stackoverflow.com/questions/23869177/import-certificate-to-trusted-root-but-not-to-personal-command-line](https://stackoverflow.com/questions/23869177/import-certificate-to-trusted-root-but-not-to-personal-command-line)

### On iOS

AirDrop or mail yourself the certificate. Open it to install it. Then go to `Settings` -> `General` -> `About` -> `Certificate Trust Settings` and turn on `Enable trust for that Root CA`



## Creating certificate issued from this authority

As an example we will create and verify a certificate for a web-server running in a docker container on the local machine. To facilitate this please add the following few hostname to your `/etc/hosts` file:

```
    127.0.0.1       localtestserver
    127.0.0.1       localtestserver.local
    127.0.0.1       localtestserver.example.com
```

We will create a certificate that will be valid for these hostnames.


### Walk-through

* Start Keychain Access
* Optionally, highlight the private key or certificate of the CA we created on the previews step
* Select Keychain Access -> Certificate Assistant -> Create a certificate 

#### Create your certificate
* `Name`: Choose a name for your certificate
* `Identity Type`: change it to **Leaf**
* `Certificate Type`: **SSL Server**
* `Let me override defaults`: **Check**

#### Certificate information 
* `Select Serial Number`: 1
* `Validity Period`: 825 days or shorter

Note, for the certificates issued after June 2019 new requirements are in effect: [https://support.apple.com/en-us/HT210176](https://support.apple.com/en-us/HT210176). This limits maximum validity to 825 days, amount other things.

Press `Continue`

* `Email`: up to you
* `Common name`: up to you


#### Choose an Issuer

* `Identity`: **Select** Certificate authority we have created on step one. Likely this will be the only one offered.


#### Key Pair Information
Leave at Defaults

#### Key Usage Extension 
Leave at Defaults

#### Extended Key Usage
* `Extension is Critical`: Checked
* `SSL Server Authentication`: Checked

#### Basic Constraints
Leave at Defautls

#### Subject ALternate Name Extension
* `Include Subject ALternate Name Extension`: Checked
  * `This extension is critical`: Unchecked.
  * Extension Values
    * `rfc822Name`: **Empty**
    * `URI`: Empty
    * `DNSName`: **Specify** space-separated list of hostnames: `localtestserver localtestserver.local localtestserver.example.com`
    * `IPAddress`: **127.0.0.1**

#### Specify the keychain

Does not really matter. Complete the wizard. 

### Testing the certificate in a local webserver

#### Export keys

Open Keychain, search for newly crated certificate by host name. You will see three entries: Certificate, Public key and Private key. 

* Select Certificate and export it to `certificate.cer` file.
* Select Private Key and export it to `certificate.p12` file, with some pass-phrase.

#### Conver to plain-text

```bash
openssl x509 -inform der -in certificate.cer -out server.crt
openssl pkcs12 -in certificate.p12 -out server.key -nodes
```

You will be prompted for the private key pass-phrase (that you specified during export on the previous step) by the second openssl invocation. If you don't want to type it in, you can specify it on a command line like so

```bash
openssl pkcs12 -in certificate.p12 -out server.key -nodes -password pass:Pa$$w0Rd
```

#### Starting apache in the docker

Install Docker, obviously. Then create `Dockerfile` in the same directory where you have your keys with the following content:

```Dockerfile
FROM httpd:2.4

RUN sed -i \
        -e 's/^#\(Include .*httpd-ssl.conf\)/\1/'           \
        -e 's/^#\(LoadModule .*mod_ssl.so\)/\1/'            \
        -e 's/^#\(LoadModule .*mod_socache_shmcb.so\)/\1/'  \
        conf/httpd.conf

RUN mkdir -p /usr/local/apache2/htdocs/public-html/      && \
    echo "<html><body>It Works!</body></html>" >                \
        /usr/local/apache2/htdocs/public-html/index.html

COPY ./server.crt /usr/local/apache2/conf/server.crt    
COPY ./server.key /usr/local/apache2/conf/server.key

```

This configures httpd container, turns on SSL extensions and uploads our certificates into the right places. It also creates a simple HTML file that prints "It Works!".

Now build and run your container: 

```bash
docker build -t my-test-webserver-image .
docker run -itd                 \
        -p 8080:80              \
        -p 443:443              \
        my-test-webserver-container
```

Then fire up Safari and and visit [https://localtestmachine](https://localtestmachine) or [https://localtestserver.local](https://localtestserver.local) or [https://localtestserver.example.com](https://localtestserver.example.com). You should be greeted with "It Works". Click on the lock and confirm that the certificate is trusted and issued from your CA.

Note, you would need to import CA certificate into trusted root list in Firefox separately, since it keeps separate trust chain: Firefox -> Preferences -> Privacy and Security -> Certificates -> View Certificates -> Import....


## History

|------|------|
|February 26, 2019 | Initial publication|
|November 27, 2019 | Updated to reflect [new certificate requirements](https://support.apple.com/en-us/HT210176)|
|July 06, 2020 | Added advice to unlock System keychain prior to importing the certificate. Fixed typos. Formatted hyperlinks.|








