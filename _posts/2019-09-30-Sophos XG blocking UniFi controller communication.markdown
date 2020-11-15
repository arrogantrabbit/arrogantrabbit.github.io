---
layout: post
title:  "Bypassing Sophos XG stateful firewall"
date:   2019-09-30 0:30:05 -0700
categories: ["Firewalls"]
tags: ["Firewalls"]
excerpt: Sophos XG blocks UniFi communication by implicit rule 0. This post describes how to bypass stateful firewall for the specific hosts.  
---


## The problem

I have Sophos XG deployed in bridge mode between the UniFi USG at `10.0.17.1` and the rest of the LAN. The controller `10.0.17.2` and the gateway are therefore on the different sides of the firewall, so I have created the business rule to allow UniFi communication -- namely `8080/tcp` and `3478/udp` -- to pass through the firewall. 

This works most of the time except provisioning (for example, during boot following power loss or configuration change) would often stall, restart, and generally take over 30 min to complete. 

Looking at XG's logs I could see the following lines repeated over and over:

> `2019-09-29 23:50:42 Firewallmessageid="01001" log_type="Firewall" log_component="Invalid Traffic" log_subtype="Denied" status="Deny" con_duration="0" fw_rule_id="0" policy_type="0" user="" user_group="" web_policy_id="0" ips_policy_id="0" appfilter_policy_id="0" app_name="" app_risk="0" app_technology="" app_category="" in_interface="Port4" out_interface="" src_mac="" src_ip="10.0.17.1" src_country="" dst_ip="10.0.17.2" dst_country="" protocol="TCP" src_port="33949" dst_port="8080" packets_sent="0" packets_received="0" bytes_sent="0" bytes_received="0" src_trans_ip="" src_trans_port="0" dst_trans_ip="" dst_trans_port="0" src_zone_type="" src_zone="" dst_zone_type="" dst_zone="" con_direction="" con_id="" virt_con_id="" hb_status="No Heartbeat" message="Could not associate packet to any connection." appresolvedby="Signature" app_is_cloud="0"`

Whats important here is this: 

`log_component="Invalid Traffic" status="Deny" fw_rule_id="0" src_ip="10.0.17.1" dst_ip="10.0.17.2"  src_port="33949" dst_port="8080" message="Could not associate packet to any connection." `

In other words Firewall `Denied` connection attempt from USG to controller port `8080/tcp` as `Invalid Traffic` via the special rule number `0`. Reason -- `Could not associate packet to any connection`.

This would repeat on and on and result in provisioning timeouts. USG in the end somehow manages to establish the connection but it takes a very long time.

## The solution

The solution is obviously to exclude communication between USG and controller from stateful firewall analysis. 

To do login to the firewall (serial consoler or ssh):

```
Sophos Firmware Version SFOS 17.5.8 MR-8

Main Menu

    1.  Network  Configuration
    2.  System   Configuration
    3.  Route    Configuration
    4.  Device Console
    5.  Device Management
    6.  VPN Management
    7.  Shutdown/Reboot Device
    0.  Exit

    Select Menu Number [0-7]: 4
```

and select `Device Console`. Once there, type `show advanced-firewall`. You will see something like this:

```
Sophos Firmware Version SFOS 17.5.8 MR-8

console> show advanced-firewall
	Strict Policy				: on
	FtpBounce Prevention			: control
	Tcp Conn. Establishment Idle Timeout	: 10800
	UDP Timeout Stream			: 60
	Fragmented Traffic Policy		: allow
	Midstream Connection Pickup		: off
	TCP Seq Checking			: on
	TCP Window Scaling			: on
	TCP Appropriate Byte Count		: on
	TCP Selective Acknowledgements		: on
	TCP Forward RTO-Recovery[F-RTO]		: off
	TCP TIMESTAMPS				: off
	Strict ICMP Tracking			: off
	ICMP Error Message			: allow
	IPv6 Unknown Extension Header		: deny


	Bypass Stateful Firewall
	------------------------
         Source              Genmask             Destination         Genmask

	NAT policy for system originated traffic
	---------------------
	Destination Network     Destination Netmask     Interface       SNAT IP
```

Then type the following to add exclusions. Note, you don't have to type everythign out -- autocompletion does wonders:

```
console> set advanced-firewall bypass-stateful-firewall-config add source_host 10.0.17.1 dest_host 10.0.17.2
Set BypassFirewall Successfully Done.

console> set advanced-firewall bypass-stateful-firewall-config add source_host 10.0.17.2 dest_host 10.0.17.1
Set BypassFirewall Successfully Done.
```

To verify, check the configuration again: 

```
console> show advanced-firewall
	Strict Policy				: on
	FtpBounce Prevention			: control
	Tcp Conn. Establishment Idle Timeout	: 10800
	UDP Timeout Stream			: 60
	Fragmented Traffic Policy		: allow
	Midstream Connection Pickup		: off
	TCP Seq Checking			: on
	TCP Window Scaling			: on
	TCP Appropriate Byte Count		: on
	TCP Selective Acknowledgements		: on
	TCP Forward RTO-Recovery[F-RTO]		: off
	TCP TIMESTAMPS				: off
	Strict ICMP Tracking			: off
	ICMP Error Message			: allow
	IPv6 Unknown Extension Header		: deny


	Bypass Stateful Firewall
	------------------------
         Source              Genmask             Destination         Genmask
         10.0.17.1           255.255.255.255     10.0.17.2           255.255.255.255
         10.0.17.2           255.255.255.255     10.0.17.1           255.255.255.255


	NAT policy for system originated traffic
	---------------------
	Destination Network     Destination Netmask     Interface       SNAT IP
```

Now attempt to provision the USG again and monitor the log: there would be no rule 0 shenanigans and you will only see traffic matching the existing explicitly defined business rule.  