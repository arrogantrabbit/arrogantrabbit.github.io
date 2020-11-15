---
layout: post
title: "Optimizing Code42 CrashPlan performance"
date: 2019-03-01 22:34:05 -0700
updated: 2020-02-28 
categories: [Backup]
tags: ["Crashplan", "Backup", "Synology"]
excerpt: Optimizing performance of Code42 CrashPlan engine for resource constrained hosts. (Does not apply to client version 7.7.0 and likely newer)
---

Last [Updated](#history) Feb 28, 2020

* TOC
{:toc}

### Update for version 7.7.0 

The advice in this article **does not apply** anymore: Sneakily and without any mention in the [release notes of version 7.7.0](https://support.code42.com/Release_Notes/Code42_app_version_7.7_release_notes) Code 42 abolished the `my.service.xml` file. Including for existing users -- the file is gone now. Yes, you read that right, **_the data backup company_ silently _deleted file_ that contained user modified configuration**. Not even saved a .bak. Just deleted. Silently. Sigh.

To put it into perspective this is a list of mischiefs: 

- Code42 [failed](#final-words) to optimize performance of their backup engine _for years_ forcing users to make unsupported changed in the config file, at the risk of losing support. 
- They took away this possibility (understandable) and **broke existing users configuration** (unacceptable). Any respectable company would make the change going forward but not retroactively -- if that is not obvious)
- They did not announce this in advance. (You always let your users know that you are about to break their stuff!)
- They did not mention it in the release notes. (Seriously guys? You put a turd in a corner and keep quiet about it in case we don't notice. My cat is trained better!)
- They deleted the existing my.service.xml file with user customizations. (User data is sacred. **you cannot delete user data ever**. What's wrong with you, code42? And no, "users should not have modified it" is not an excuse)


This [Reddit post](https://www.reddit.com/r/Crashplan/comments/fav33a/psa_starting_from_770_for_small_business_youre_no/) quotes response from the support team (emphasis mine):

> "In the latest version of CrashPlan for Small Business the Service xml is now part of the app itself and cannot be modified by the user. This is pursuant with our policy as we do not support changing many of those settings on CrashPlan for Small Business. Altering those settings can cause problems for the software. We do not test or QA on those sorts of configurations and do not develop with the intention that users will modify them.
>
> **As such, there is no way to change the settings as you desire**."

Pardon my French, but _screw that shit_. Without the ability to "change those settings" to workaround "problems for the software" it is no longer possible to use it. 

Seriously, Code42, no one gets second chances. You did. And blew it again. I guess this is it. Thank you for great service for the past almost a decade up until version 7.7.0. Goodbye. 


## Background

[Code42 CrashPlan](https://www.crashplan.com/en-us/) is a backup service that promises unlimited backup for a fixed monthly fee. I have been using them since 2010 I think. It works, but performance has always been  an issue -- CPU usage was high, memory consumption was high, and upload speed was fairly abysmal. Support was referring me to [this article](https://support.code42.com/Administrator/Small_Business/Troubleshooting/Backup_speed_does_not_match_available_bandwidth) and the following quote specifically: 

> Code42 app users can expect to back up about 10 GB of information per day on average if the user's computer is powered on and not in standby mode. 

I was getting my upload rate consistently capped at 132kB/sec which coincidentally translates to 10GB/day. At that point I concluded that perhaps they are throttling me, unsurprisingly, since nothing unlimited can  be expected to be offered at a flat rate, there have to be limitations, and having that support article in front of me was convincing enough for me to conclude that this was by design. 

This of course was unacceptable for my use cases so I have since migrated to another solution -- duplicacy backup software coupled with third party cloud block storage provider as a destination and was fairly happy with the performance. 

Recently however it was pointed to me that my upload issues with CrashPlan could have likely been caused not by Code42 bandwidth management on the server side but rather by local backup engine chocking when trying to deduplicate massive amount of data. Massive in this case was still under 1TB, but apparently that was sufficient for the java based backup engine to peg Atom C3000 processor. 


## Solution

I have attempted to do the following unsuccessfully: 

* Disable compression on each backup set.
* Set an upper limit on the file size that is subject to deduplication
* Set deduplication mode to AUTOMATIC or MINIMAL

I eventually found that the only way to drop CPU usage and fix the upload rate was to disable deduplication altogether: 

```bash
sed -i "s/<dataDeDupAutoMaxFileSizeForWan>[0-9]*<\/dataDeDupAutoMaxFileSizeForWan>/<dataDeDupAutoMaxFileSizeForWan>1<\/dataDeDupAutoMaxFileSizeForWan>/g" my.service.xml
```
The `dataDeDupAutoMaxFileSizeForWan` filters files subject to deduplication when backing up to WAN destinations by maximum size. The default value of 0 means "no limit". Changing this value to the smallest positive size (1 byte) effectively disables deduplication.

You would need to stop CrashPlan engine, update the xml config file, and then start the engine; otherwise your changes won't persist as CrashPlan writes out the configuration on shutdown.

## Caveats

Code42 warns about potential implication of disabling deduplication in [this article here](https://support.code42.com/CrashPlan/4/Configuring/Unsupported_changes_to_CrashPlan_de-duplication_settings). Depending on the type of data it may be counterproductive to do so -- for example, for large files only portions of which change frequently, such as VM images, the savings of time due to reduced upload size _could_ more than offset performance loss due to deduplication. The impact and benefits of this change should be evaluated and measured for specific backup set before committing.

For most home users however (who mostly backup photos. videos, and other media; in other words data that due to its nature is unique and incompressible) deduplication provides no benefits and can be safely disabled yielding net gain in backup performance. These users may also benefit from disabling compression selectively (or even altogether) for some or all backup sets, however I haven't noticed any significant impact of this change on my own dataset. 

```bash
sed -i "s/<compression>ON<\/compression>/<compression>AUTOMATIC<\/compression>/g" my.service.xml
```

## Final words 

Code42 should seriously consider substantially overhauling their backup client software as this sort of performance is not acceptable. The impact of this will only become worse as the backup set grows over time. It does however provide them with a "natural" throttling mechanism, so I can see why they would be hesitant to optimize the performance. I'm just speculating here, but apparently the cost of additional bandwidth consumed by the few users that bother to disable deduplication is more than offset by savings on storage utilization due to effective rate limiting all other customers, punishing the users proportionally to the amount of data they have. It's pretty slick if you think about it.

## History

|------|------|
|March 1, 2019 | Initial publication|
|February 28, 2020 | Added update for version Crashplan Pro client version 7.7.0 that makes this entire article inapplicable |


