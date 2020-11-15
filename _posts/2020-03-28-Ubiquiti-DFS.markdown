---
layout: post
title:  "Handling of radar detection on DFS channels by Ubiquiti WiFi access points"
date: 2020-05-28 22:00:00 -0700
categories: ["Hardware"]
tags: ["Ubiquiti", "RF"]
excerpt: Ubiquiti APs stay off the channel for a strange amount of time but can be nudged back to DFS channel manually. 
---

TLDR: To nudge the AP to return back to the configured DFS channel run `syswrapper.sh dfs-reset` 30 minutes (or later) following radar detection event. 

## What is DFS all about?

Quoting from the NTS's document here: [Dynamic Frequency Selection (DFS) in 5GHz Unlicensed Bands. An Overview of Worldwide Regulatory Requirements](https://www.nts.com/resources/Dynamic%20Frequency%20Selection%20and%20the%205GHz%20Unlicensed%20Band.pdf):

> The advent of the 802.11a wireless market and the constant push to open up spectrum for unlicensed use required that a mechanism be implemented for spectrum sharing. Dynamic Frequency Selection (DFS) is the mechanism that was adopted to allow unlicensed devices to use the 5 GHz frequency bands already allocated to radar systems without causing interference to those radars. The concept of DFS is to have the unlicensed device detect the presence of a radar system on the channel they are using and, if the level of the radar is above a certain threshold, vacate that channel and select an alternate channel.


This makes additional channels (specifically 52-64 (UNII-2) and 100-144 (UNII-2 Ext) in the U.S.) available for use. Since most consumer access points don't support DFS channels in the crowded residential environment there is good chance the DFS channels would be unoccupied and available for the exclusive interference free use by the smug owner of Ubiquiti hardware.

## What's the problem?

When Ubiquiti access point configured to DFS channel (that would not be auto-selected; it needs to be manually selected) detects (or thinks it does: false positives do happen as it is far better than false negatives from the compliance perspective) radar interference and hops off the DFS channel as it should it then sits there. 

For _how long_? _Until 2AM_.  And _that_'s what I find frustrating. The question is about the duration and yet the answer seems to be a point in time. That alone is already wrong.

As of 4.3.13.11253 there is a cron job scheduled to nudge the radio to return back to the configured DFS channel at 2AM:

```console
uap01-BZ.v4.3.13# cat /etc/crontabs/username
0 2 * * * syswrapper.sh dfs-reset
```

## What do the regulations prescribe?

Looking at the aforementioned document we see that the USA's FCC's rules 03-287 are largely based on European standard EN 301 893:

> The timing and threshold requirements were almost identical to those in EN 301 893, but the signal parameters were different and the FCC included a frequency hopping radar. 

From the EN 301 893 the following is relevant: 

>      Non-occupancy period: 30 minutes (minimum)

It therefore follows that what Ubiquiti does right now is rather questionable: 
- if the interference was detected outside of the 30 min window immediately preceedint 2AM the AP will sit on a wrong channel for more than it has to. 
- Otherwise it will attempt to switch back too soon and likely fail. Cue another 24 hours sitting on a crowded channel. (I hope it won't succeed -- it be violating regulation otherwise)


### A tangential

> Note – Client devices do not need radar detection capabilities unless they have an output power (eirp) that exceeds 200mW.

In the [UAP AC Pro datasheet](https://dl.ubnt.com/datasheets/unifi/UniFi_AC_APs_DS.pdf) the max TX Power is 20dBm, which is 100mW. So if I understand that correctly -- why do we/they bother in the first place? 


## What can we do for now

Run that script 30 min following the event manually or through automation integrated with logging and reporting. 

Note: 

>     Minimum channel availability check time (CAC time)
>        60s outside 5600-5650 MHz
>        10 minutes for 5600-5650MHz sub-band

Which means once you run the script to reset it back to DFS mode it would need to listen for 1 or 10 minutes before transmitting. This may or may not be the factor here.