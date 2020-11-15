---
layout: post
title:  "Unattended Duplicacy setup on macOS"
date:   2017-12-01 23:34:05 -0700
updated: Apr 29, 2020
categories: [Backup]
Tags: Backup Duplicacy MacOS
excerpt: What do you do when your favourite backup provider decides to focus on corporate customers and discontinues home edition of its cloud backup software? You start testing replacements, and soon come with with an alternative that in retrospect happensn to be more robust, flexible and resilient. This post will provide a supplemental information for setting up unattended periodic Duplicacy backup on a MacOS. Main goal is to provide meaningful configuration files to save time re-inventing the wheel.
---

Last [Updated](#history) Apr 29, 2020

* TOC
{:toc}

## Purpose

To provide sample of working configurations on MacOS.

## Download and configure duplicacy

The easiest would be to build from source: 
1. [install go](https://golang.org/dl/)
2. setup `$GOBIN` and `$GOPATH` to point to your go installation
3. [Follow Duplicacy installation guide](https://github.com/gilbertchen/duplicacy/wiki/Installation) 

Eventually this boils down to 

``` bash
go get -u github.com/gilbertchen/duplicacy/...
sudo ln -s  $GOBIN/duplicacy /usr/sbin/duplicacy
```


## Setup repository

We'll be using `~` as a repository root. Alternatively one can configure `/Users` as a duplicacy root -- or both! targeting the same storage with different backup schedules. Some tweaks to filters file might be required. For other storage backends see the [documentation](https://github.com/gilbertchen/duplicacy/wiki/Storage-Backends).

We'll assume that the storage is on a network server `server.com` accessible via `sftp` with public key authentication. Too keep things tidy its easy to keep the private key along 

    cd ~
    duplicacy init -e my-repo sftp://user@server.com//Backups/Duplicacy/
    
Note `//` to indicate the path is absolute.  

You will be prompted for encryption password. If encryption is not desired - remote `-e`.

Then edit `~/.duplicacy/preferences` and add keys and other options:

{% raw %}
    [
        {
            "name": "default",
            "id": "my-repo",
            "storage": "sftp://user@server.com//Backups/Duplicacy/",
            "encrypted": true,
            "no_backup": false,
            "no_restore": false,
            "no_save_password": false,
            "keys": {
                "default_password": "<encryption password>",
                "ssh_key_file": ".duplicacy/id_rsa_privatekey"
            }
        }
    ]
{% endraw %}

Alternatively, encryption password can be placed to keychain but that would complicate the setup. Also, if the attacker has access to your home folder then there is not much sense in protecting the same files in backup.

## Configure exclusions
Sample `.duplicacy/filters` optimized for backing up irresplacable data of a typical MacOS user home. The goal is to only backup user generated content and avoid backing up system, temporary and derivative data. There is Time Machine for that. 

``` config

#### ----------------------- Generic Transients -----------------------  ####

# exclude any cache files/directories with cache in the name (case insensitive)
e:(?i).*cache.*

# Preferences and old-school shite we don't care about - e.g .dropbox
e:\.(Trash|SynologyDrive|ac6|oracle_jre_usage|pia_manager|stm\w*|eclipse|dropbox)/.*$

# Source cobtrol - .git/.svn/.hg
e:\.(svn|git|hg)/.*$


# SQLite index files
e:.sqlite-(shm|wal)$

# Exclude junk/spam and deleted Mailboxes
e:(Deleted Items|Junk( Email)?|Spam|Trash)\.mbox/.*$

# Exclude other well-known shite
-*$RECYCLE.BIN/
e:.*/Envelope Index(-wal|-shm)?$

``` 

Library folders: We'll specifically include certain items and exclude everythin else

``` config

#### ------------------------- Library Folder --------------------------  >>>
+Library/

# Everything under Messages, Mail and Calendar
+Library/Messages/*
+Library/Mail/*
+Library/Calendars/*

### -------------------- Library/Application Support -------------------- >>>
+Library/Application Support/

# Important apps that seem to keep user data there. Why!?
+Library/Application Support/1Password 4/*
+Library/Application Support/BBEdit/*
+Library/Application Support/Viscosity/*
+Library/Application Support/CampoSanto/*
+Library/Application Support/Transmit/*
+Library/Application Support/minecraft/
+Library/Application Support/minecraft/saves/*

# Nothing else from Application Support
-Library/Application Support/*

### -------------------- Library/Application Support -------------------- <<<

### --------------------------- iCloud Stuff ---------------------------- >>>
+Library/Mobile Documents/

# Entire CloudDocs folder  (iCloud Drive essentially, with Desktop and stuff)
+Library/Mobile Documents/com~apple~CloudDocs/*

# Other iCloud stuff. Documents subfolder only for all other apps, just in case
+Library/Mobile Documents/com~apple~*/
+Library/Mobile Documents/com~apple~*/Documents/*

# Nothing else from Mobile Documents
-Library/Mobile Documents/*

### --------------------------- iCloud Stuff ---------------------------  <<<

### ------------------------ Library/Containers ------------------------  >>>
+Library/Containers/

# Relevant app state
+Library/Containers/com.culturedcode.ThingsMac/*

# Nothing else from containers
-Library/Containers/*

### ------------------------ Library/Containers ------------------------  <<<

# Nothing else from Library:
-Library/*

#### ------------------------- Library Folder -------------------------  <<<<
```

We will exlude (what I think is) derivateive data and only backup Masters and Live Photo videos. Upon importing these back into fresh photos library it figures out that they are related and makes a live photo again. Therefore this is sufficeint to only backup those files.

``` config
#### ---------------------------- Pictures ----------------------------  >>>>
+Pictures/

# Only pictures from Photo Booth
+Pictures/Photo Booth Library/
+Pictures/Photo Booth Library/Originals/*
+Pictures/Photo Booth Library/Pictures/*
-Pictures/Photo Booth Library/*

# Only masters from Photos Library
+Pictures/Photos Library.photoslibrary/

# Catalina+
+Pictures/Photos Library.photoslibrary/originals/*
+Pictures/Photos Library.photoslibrary/database/*

# Pre-Catalina
+Pictures/Photos Library.photoslibrary/Masters/*
+Pictures/Photos Library.photoslibrary/resources/
+Pictures/Photos Library.photoslibrary/resources/media/
+Pictures/Photos Library.photoslibrary/resources/media/master/*

-Pictures/Photos Library.photoslibrary/*

# Everything else under Pictures will be included by default.

#### ---------------------------- Pictures ----------------------------  <<<<

#### ------------------------- Re-obtainable --------------------------  >>>>

# Explicitly Exclude other known folders
-Music/
-Movies/
-Downloads/*.dmg
-Downloads/*.pax
-Downloads/*.download
-Box/*

#### ------------------------- Re-obtainable --------------------------  <<<<

# If match is not found - item will be included as we have both + and - rules.

```

## Schedule periodic backup via launchd
It's useful to place actual calls to duplicacy into a shell script e.g. `.duplicacy/gobackup.sh` - for debugging, manual execution and for convenience. 

``` bash
#!/bin/bash

cd /Users/username
caffeinate -s nice duplicacy backup

# Retention
# After two weeks keep a version every day
# After 90 days keep a version every week
# After one year keep a version every month
caffeinate -s nice duplicacy prune -keep 31:360 -keep 7:90 -keep 1:14 -all
```

Note, `caffeinate` is not required if it is only launched iva launchd; it is however useful for initial backup and/or when launched manually. 
Note, the previous note also applies to `nice`

The launchd plist can also be placed into the same folder and then symlink created under `~/Library/LaunchAgents`. Start it with `laundhctl -w load <path to plist>`.

The same approach can be utilized for backing up entire `/Users` directory, in this case the plist shall be linked to under `/Library/LaunchDaemons`; For more details see `man launchd.plist`. Filters list will need to be adjusted to allow for a home folder name prefix.



Sample plist for backup [every start of the hour](https://developer.apple.com/library/content/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/ScheduledJobs.html).

``` xml

<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
	<dict>
		<key>Label</key>
		<string>com.somename.duplicacy</string>
		<key>ProgramArguments</key>
		<array>
			<string>/Users/username/.duplicacy/gobackup.sh</string>
		</array>
		<key>LowPriorityIO</key>
		<true/>
		<key>WorkingDirectory</key>
		<string>/Users/username</string>

                <key>StandardOutPath</key>
                <string>/tmp/duplicacy.stdout</string>
                <key>StandardErrorPath</key>
                <string>/tmp/duplicacy.stderr</string>

		<key>StartCalendarInterval</key>
		<dict>
			<key>Minute</key>
			<integer>0</integer>
		</dict>

		<key>Nice</key>
		<integer>-20</integer>
		<key>ProcessType</key>
		<string>Background</string>
	</dict>
</plist>
```

## References
- [Duplicacy Documentation](https://github.com/gilbertchen/duplicacy/wiki/)
- [Filters - Setting up Include-Exclude patterns](https://github.com/gilbertchen/duplicacy/wiki/Include-Exclude-Patterns)
- [Creating Launch Daemons and Agents](https://developer.apple.com/library/content/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingLaunchdJobs.html)

## History

|------|------|
|December 1, 2017 | Initial publication|
|April 29, 2020 | Updated Photo library locations for Catalina (added `originals` folder under the library bundle) |


