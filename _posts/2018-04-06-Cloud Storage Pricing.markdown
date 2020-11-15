---
layout: post
title:  "Cloud Storage Pricing"
date:   2018-04-06 00:34:05 -0700
categories: ["Backup"]
tags: ["Cloud Storage", "Backup"]
excerpt: Looking for a CrashPlan alternative&#58; Comparing cost of cloud storage.
---


## Cost comparison

This is the costs of cloud storage as of the date of this posting

|**Provider**    |**Tier**|**Max, TB**|**Cost<br> $TB/mon**|**Minimum<br>$/mon**|**Cost<br>$/mon**|**Eggress<br>$/GB**|**Availability**|**0.5TB**|**1TB**|**2TB**|**4TB**|**6TB**|**8TB**|**10TB**|**12TB**
|:---------------|:-------|---------------:|-------------------:|-------------------:|----------------:|------------------:|:---------------|--------:|------:|------:|------:|------:|------:|------:|------:
|[Backblaze B2](https://www.backblaze.com/b2/cloud-storage-pricing.html)            |0-10GB     |0.01   |$0.00  |$0.00  |       |$0.00                      |Instant|$0.00  |       ||||||
|[Backblaze B2](https://www.backblaze.com/b2/cloud-storage-pricing.html)            |10GB+      |       |$5.00  |$0.00  |       |$0.01                      |instant|$2.50  |$5.00  |$10.00|$20.00|$30.00|$40.00|$50.00|$60.00
|[Amazon S3](https://aws.amazon.com/s3/pricing/)                                    |STD        |       |$23.00 |$0.00  |       |1GB/mon free, then $0.09   |Instant|$11.50 |$23.00 |$46.00|$92.00|$138.00|$184.00|$230.00|$276.00
|[Amazon S3](https://aws.amazon.com/s3/pricing/)                                    |STD-IAF    |       |$12.50 |$0.00  |       |1GB/mon free, then $0.09   |Instant|$6.25  |$12.50 |$25.00|$50.00|$75.00|$100.00|$125.00|$150.00
|[Amazon S3](https://aws.amazon.com/s3/pricing/)                                    |Glacier    |       |$4.00  |$0.00  |       |1GB/mon free, then $0.09, +$0.0025|5-12 hours|$2.00|$4.00|$8.00|$16.00|$24.00|$32.00|$40.00|$48.00
|[Dropbox Plus](https://www.dropbox.com/buy?_tk=plus_last_button)                   |1 TB       |1      |       |       |$8.25  |$0.00                      |Instant|$8.25  |$8.25  ||||||
|[Dropbox Standard](https://www.dropbox.com/plans?trigger=nr)                       |2 TB       |2      |       |       |$12.50 |$0.00                      |Instant|$12.50 |$12.50 |$12.50|||||
|[Dropbox Advanced](https://www.dropbox.com/plans?trigger=nr)                       |Unlimited  |       |       |       |$20.00 |$0.00                      |Instant|$20.00 |$20.00 |$20.00|$20.00|$20.00|$20.00|$20.00|$20.00
|[Office 365 Personal](https://products.office.com/en-us/office-365-personal)       |1 TB       |1      |       |       |$5.83  |$0.00                      |Instant|$5.83  |$5.83  ||||||
|[Office 365 Home](https://products.office.com/en-us/compare-all-microsoft-office-products?tab=1)|5 x 1 TB|5|   |       |$8.33  |$0.00                      |Instant|$8.33  |$8.33  |$8.33|$8.33||||
|[Google Drive](https://www.google.com/drive/pricing/)                              |1 TB       |       1|      |       |$9.99  |$0.00                      |Instant|$9.99  |$9.99  ||||||
|[Google Drive](https://www.google.com/drive/pricing/)                              |10 TB      |10     |       |       |$99.99 |$0.00                      |Instant|$99.99 |$99.99 |$99.99|$99.99|$99.99|$99.99|$99.99|
|[Microsoft Azure](https://azure.microsoft.com/en-us/pricing/details/storage/blobs/)|LRS, Cool  |       |$10.00 |$0.00  |       |$0.01                      |Instant|$5.00  |$10.00 |$20.00|$40.00|$60.00|$80.00|$100.00|$120.00
|[Microsoft Azure](https://azure.microsoft.com/en-us/pricing/details/storage/blobs/)|LRS, Arch  |       |$2.00  |$0.00  |       |$0.02                      |<15 hours|$1.00|$2.00  |$4.00|$8.00|$12.00|$16.00|$20.00|$24.00
|[Rackspace 1TB](https://www.rackspace.com/cloud/files)                             |Unlimted   |       |$10.00 |$0.00  |       |$0.12                      |Instant|$5.00  |$10.00 |$20.00|$40.00|$60.00|$80.00|$100.00|$120.00
|[Rackspace 1-49TB](https://www.rackspace.com/cloud/files)                          |Unlimited  |       |$9.00  |$0.00  |       |$0.10                      |Instant|$4.50  |$9.00  |$18.00|$36.00|$54.00|$72.00|$90.00|$108.00
|[Wasabi Legacy](https://wasabi.com/pricing/)                                       |Unlimited  |       |$3.90  |$3.90  |       |$0.04                      |Instant|$3.90  |$3.90  |$7.80|$15.60|$23.40|$31.20|$39.00|$46.80
|[Wasabi UE](https://wasabi.com/pricing/)                                           |Unlimited  |       |$4.99  |$4.99  |       |$0.00                      |Instant|$4.99	|$4.99	|$9.98|	$19.96|	$29.94|	$39.92|	$49.90|	$59.88
|[HubiC](https://hubic.com/en/)(France)                                             |10 TB      |10     |       |$0.00  |$5.00  |$0.00                      |Instant|$5.00  |$5.00  |$5.00|$5.00|$5.00|$5.00|$5.00|
|[Synology C2](https://c2.synology.com/en-us/backup#tab_plan)                       |Unlimited  |       |$5.83  |$0.00  |       |$0.00                      |Instant|$2.91  |$5.83  |$11.66|$23.32|$34.98|$46.64|$58.3|$69.96


## Notes

For the purposes of Backup keep in mind the following intricacies:

- Amazon Glacier and Azure Archive require blob level management and due to thawing/rehydration requirements will likely never be supported in Hyper Backup or similar automatic backup software; that said it is a perfect target for one-way sync of an encrypted backup containers with immutable objects -- such as Duplicacy. 
- Backblaze B2 is not supported by Synology’s Hyper Backup. Synology [promised B2 support in Hyper Backup in 2018](https://www.reddit.com/r/synology/comments/6r29m8/please_help_get_backblaze_b2_supported_as_a/)
- When storage needs approach 2 Tb Crashplan Pro again becomes an option,  however performance are a concern. 

## Conclusions

It seems as of today, Wasabi offers most compatible and cost effective backup target. It can be supplemented with Microsoft LRS Archive tier (some tinkering required) for immutable backup containers. Otherwise Wasabi remains a viable choise for long term storage as well, closely followed by BackBlaze B2.