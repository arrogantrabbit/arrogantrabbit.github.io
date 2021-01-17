---
layout: post
title:  "Configuring duplicacy CLI on macOS with SIP enabled"
date: 2021-01-16 10:00:00 -0700
categories: ["Backup"]
tags: ["Duplicacy", "Backup", "macOS"]
excerpt: This post explains how to configure Duplicacy on macOS with SIP enabled to backup all users and limit CPU utilization. 
---

* TOC
{:toc}

This is a handy script to download and install duplicacy cli and configure it to run under launchd to backup all users, without the need to disable SIP.

## The problem

Duplicacy CLI on macOS cannot access sensitive user folders such as Documents and Pictures when ran standalone. It does not seem to be possible to grant full disk access to a naked executable that is not an app bundle. When launched via Duplicacy Web GUI that problem does not exist as the CLI engine inherits permissions granted to the parent app bundle.

Using Duplicacy GUI however is undesirable for several reasons:

- It's impossible to control CPU utilization of the CLI engine (without jumping through hoops)
- Running closed source app that fetches executables from the internet under account that needs access to all users data is sub-optimal.

## The solution

A script to accomplish the following tasks is provided in this post:

- Fetch the specified version of duplicacy from the web or local build directly. Support specific version number, specific local path, and "Latest" and "Stable" channels.
- Create aux script to launch and throttle duplicacy_cli depending on power status of your mac -- support separate limits on battery vs on wall power. (cpulimit)
- Wrap the scripts into macOS app bundle that can be granted Full Disk Access (platypus)
- Configure launchd daemon to run the backup and prune with configurable retention policy

### Prerequisities

We will assume that the following is true:
- Duplicacy is configured under `/Library/Duplicacy` to backup `/Users`. This boils down to doing something along these lines when initializing the repository:
    ```sh
    sudo mkdir -p /Library/Duplicacy
    cd /Library/Duplicacy
    sudo duplicacy init -repository /Users <snapshot id> <storage url>
    ```
- [homebrew](https://brew.sh) is installed. Depending on the configuration we would need one or few of the following utilities: `platypus`, `cpulimit`, `wget`, `jq`, `curl`. The script will prompt for the missing ones, which then could be installed with
    ```sh
    brew install platypus cpulimit wget jq curl
    ```

### To run

- Clone the repository [https://github.com/arrogantrabbit/duplicacy_cli_macos](https://github.com/arrogantrabbit/duplicacy_cli_macos)
- review the `install.sh` file
- make changes as needed to the schedule and/or duplicacy version and/or other options 
- make it executable `chmod +x install.sh` and run it

The script will generate wrapper executable and open Finder in the enclosed folder. Please drag the generated app bundle (`Duplicacy-Backup.app` by default) to `Full Disk Access` section in the System Preferences \| Security & Privacy \| Privacy \| Full Disk Access.

Note: Every time you re-generate the bunlde you woudl need to remove and re-add it to Full Disk Access.

Note: Logs that duplicacy outputs to stdout and stderr go to /Library/Logs/Duplicacy. However  Duplicacy still places cache under `.duplicacy/cache` and some of the logs still go under `.duplicacy/logs`. That is a hidden folder under `/Library/Duplicacy`. To see it in Finder press ⌘+⇧+. Until this is configurable nothing can be do short of symlinking the locations to the right places. This is left as an exercise for the reader. 

### The Script

The embedded version below is facilitated by https://emgithub.com. 
<script src="https://emgithub.com/embed.js?target=https%3A%2F%2Fgithub.com%2Farrogantrabbit%2Fduplicacy_cli_macos%2Fblob%2Fmain%2Finstall.sh&style=github"></script>

