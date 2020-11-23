---
layout: post
title:  "Duplicacy Web on Synology Diskstation without Docker"
date:   2020-03-02 22:00:00 -0700
categories: ["Backup"]
tags: ["Backup", "Synology", "Duplicacy"]
excerpt: Duplicacy is a self-contained executable and as such it can be run natively on a Synology diskstation, without docker.
---


## Premise

[Acrosync's Duplicacy](https://duplicacy.com) is a powerful backup program that I'm using extensively on a variety of devices, including the Synology Diskstation in the [docker container](https://hub.docker.com/r/saspus/duplicacy-web). 

Docker on Synology however suffers from annoying issues, including but not limited to incorrect resource usage reporting and while the overhead of managing userIDs and configuration data is worthwhile for applications that benefit from dependencies isolation docker provides duplicacy does not require nor benefits from it: both Web UI and command line engine are written in Golang and are self-contained executables. 

Furthermore, some Synology devices do not run docker -- and yet duplicacy would work just fine on them.

## Purpose

In this article I describe the simple script to download and install duplicacy_web as a service on a Synology Diskstation natively, without the aid of docker. It can be used as-is, or  to be used as a starting point for your customizations and to illustrate various techniques.

Synology DSM uses [upstart](http://upstart.ubuntu.com) to manage services. The script below downloads the specified duplicacy executables and configures it to run when network and storage is up.

## Usage

1. Create the limited user `duplicacy` for the daemon to run under. Modify the script accordingly if different username is desired.
2. Give that user permissions to read the folders intended to be backed up.
3. Enable users home service. Duplicacy configuration will be stored in the home folder of the user defined in step 1. It is trivial to modify the script to store data elsewhere if homes service is undesirable.
4. Read through and run the script to install and start the daemon.


To upgrade or downgrade duplicacy version modify the DUPLICACY_WEB_VERSION environment variable in the beginning and run the script again. 

## Important notes

### Listening address

By default Duplicacy Web is listening on a loopback interface so that only local users can connect. It can be configured to listen on your LAN adapter instead but this is undesirable [due to this issue](https://forum.duplicacy.com/t/web-ui-security-https-sessions-and-logout-button/1757?u=saspus). 

The secure enough workaround until that is fixed is to keep it accessible on a loopback only and reach the UI via SSH port tunneling. By default port tunneling is disabled, so the script enables it and restarts sshd daemon in the very end. 

To login, you would start a tunnel like so in the background: 

```bash 
ssh -N -L 3875:127.0.0.1:3875 you@nas &
```

and then connect to http://localhost:3875.  

However, if you really want to avoid the tunneling you can change the listening port. Place the code below right before "Launching service": If the configuration file does not exist it will be created with the `listening_address` set to to listen on all interfaces; otherwise the change will be edited into the existing file.

```bash
CONFIGPATH=${HOMEDIR}/.duplicacy-web

if [ ! -f ${CONFIGPATH}/settings.json ]; then

echo "Configuration file does not exist."
echo "Creating default one enabling listening on all interfaces"

mkdir -p ${CONFIGPATH}

cat > ${CONFIGPATH}/settings.json << EOF
{
    "listening_address"     : "0.0.0.0:3875"
}
EOF

else 

echo "Setting listening_address to 0.0.0.0:3875"
sed -i "s/\"listening_address\"\s*:\s*\".*\"/\"listening_address\" : \"0\.0\.0\.0:3875\"/g" ${CONFIGPATH}/settings.json

fi

# Setting the correct owner to entire folder
chown -R ${USERNAME}:${GROUPNAME} ${CONFIGPATH} || exit 7
```

### Memory consumption

Duplicacy can be fairly memory hungry on large datasets. To [mitigate](https://forum.duplicacy.com/t/memory-usage/623/3) this somewhat we set `DUPLICACY_ATTRIBUTE_THRESHOLD=1` to prevent it from caching metadata in memory and we adjust `oom` tolerance for the service to reduce the chances for the child process to get killed.

### ARM devices

I haven't tested it on ARM devices due to lack of access to hardware.

## The script

```bash
#!/bin/bash

# Duplicacy version. Modify and re-run the script when new version is released
DUPLICACY_WEB_VERSION=1.2.1

# Username for the daemon to run on behalf of. Give this user permission to read stuff that needs to be backed up.
USERNAME=duplicacy
GROUPNAME=users

if [[ $(id -u) != 0 ]]; then
    sudo -p 'Restarting as root, password: ' bash $0 "$@"
    exit $?
fi

# Figuring out correct download suffix
MACHINE_ARCH=$(uname -m)

case ${MACHINE_ARCH} in
"x86_64")
    ARCH=x64
    ;;
"arm")
    ARCH=arm
    ;;
*)
    echo Unknown or unsupported architecture ${MACHINE_ARCH}
    exit 2
    ;;
esac

SERVICENAME=duplicacy_web

echo "Using duplicacy_web version ${DUPLICACY_WEB_VERSION} arch ${ARCH}"
echo "Service ${SERVICENAME} will run as a user ${USERNAME}:${GROUPNAME}"

# Target application filename.
APPFILE=duplicacy_web_linux_${ARCH}_${DUPLICACY_WEB_VERSION}

# Download URL
URL=https://acrosync.com/duplicacy-web/${APPFILE}

echo "Stopping the service ${SERVICENAME}"
stop ${SERVICENAME}

# Check if specified user exists
if [[ 0 != $(id -u ${USERNAME} > /dev/null 2>&1; echo $?) ]] ; then
    echo "User ${USERNAME} does not exist. Create the user and enable user home service (Control Panel, User, Advanced)"
    exit 3
fi

# Check if user has home folder
HOMEDIR="$(eval echo ~"${USERNAME}")"
if [ ! -d ${HOMEDIR} ] ; then
    echo "Home directory for the user ${USERNAME} does not exist. Make sure Homes service is running"
    exit 4
fi

# If application executable hasn't been downloaded yet -- do it now
APPFILEPATH=${HOMEDIR}/${APPFILE}

if [ ! -f ${APPFILEPATH} ]; then
    echo "Downloading executable from ${URL}"

    wget -O ${APPFILEPATH} ${URL}

    if [[ $? != 0 ]]; then
        echo "Download failed"
        rm -f ${APPFILEPATH}
        exit 5
    fi
    chmod +x ${APPFILEPATH}  || exit 6
fi

# Write out upstart daemon configuration
echo "Creating upstart daemon ${SERVICENAME} in /etc/init"
cat > /etc/init/${SERVICENAME}.conf << EOF
description "${SERVICENAME} daemon"
author "Arrogant Rabbit"
start on syno.network.ready and syno.share.ready
stop on runlevel [06]
env HOME=${HOMEDIR}
env DUPLICACY_ATTRIBUTE_THRESHOLD=1
setuid ${USERNAME}
setgid ${GROUPNAME}
respawn
respawn limit 5 10
oom score -999
console log
exec ${APPFILEPATH}
EOF


echo "Launching service ${SERVICENAME}"
start ${SERVICENAME} || exit 7

echo "Duplicacy has been installed and started successfully"
echo "By default duplicacy_web is listening on port 3875 on a loopback interface for security."
echo "To establish connection start TCP tunnel first: ssh -L 3875:127.0.0.1:3875 $(hostname)"
echo "Then navigate to http://localhost:3875"

# Enable SSH TcpForwarding
sed -i "s/.*AllowTcpForwarding.*/AllowTcpForwarding yes/g" /etc/ssh/sshd_config
restart sshd
```
