---
layout: post
title:  "Migrating Jekyll blog comments from Disqus to Discourse"
date: 2021-01-17 10:00:00 -0700
categories: ["meta"]
tags: ["Blog"]
excerpt: Move to self-hosted discourse for blog comments to avoid user tracking by unrelated third parties. 
---

## Premise

On this blog I had commeting enabled though free tier of Disqus. It worked well, however I noticed that a bunch of trackers tagged along. Especially, facebook.net, among other things. I did not find a way to turn twitter Like and Share buttions either, and the paid subscription I briefly considered promised to provide ability to _hide_ them. _Hide_. Not _remove_. So, good bye disqus. 

What now? I like Discourse a lot. It's ridiculously feature reach [free and opensource](https://github.com/discourse/discourse) forum software, so installing it on some cloud instance was a no brainer. I have considered a few cloud options, and because I don't want this blog to cost me _more_ money I was mainly focused on low cost or free cloud hosting options -- such as Digital Ocean Droplets and GCP Free tier.

Comparing specs side by side it appears that Oracle's always-free tier provides sufficiently beefy virtual instance, so I went with that. In addition, I always wanted to play with Oracle Linux so that was a plus. 

## So why this blog?

It all seemed straightforward, with tons of documentation online; why write one more? Because as usual nothing worked out of the box and I had to do a few tweaks here an there. Consider these more or less notes for myself than anything with the side benefit of potentially helping someone else. 

* TOC
{:toc}

## Cloud VM Instance

### Create

There is a [tutorial on oracle blogs](https://blogs.oracle.com/developers/install-run-discourse-for-free-in-the-oracle-cloud) but it seems the UI has changed somewhat and its hard to follow it.
- Create free account here: [https://www.oracle.com/cloud/free/](https://www.oracle.com/cloud/free/)
- at [https://cloud.oracle.com](https://cloud.oracle.com) select region. I picked US West (Phoenix)
- Click on a huge `Create a VM Instance` box in Quick Actions. Note `Always Free Eligible` badge
- Pick AMD `VM.Standard.E2.1.Micro` in Availability Domain `AD-1` shaped `VM.Standard.E2.1.Micro`. This provides always-free instance with 1 OCPU with 1 GB RAM and 0.48 Gbps network bandwidth. The names and domains might change but the key is to pick `Always-Free eligible` objects.
- Scroll down and set `Assign a public IPv4 address: Yes`
- Download pair of SSH keys. (Or create a custom pair and upload public key). Set permissions to your private key 600: `chmod 600 ssh-key.key`. 
- Create the machine and wait for it to become available. 
- Copy public IP address and add it to the A record on your DNS provider with appropriate subdomain name. I picked forum.arrogantrabbit.com. This will take some time to propagate, so it makes sense to do it early.
- From the instance details page click on subnet link; there click on `Default Security List` and click `Add Ingress Rules`. Add this: 
    - source type: `CIDR`
    - source CIDR: `0.0.0.0/0` (you may want to change that later if you want to only allow your proxy)
    - IP Protocol: `TCP`
    - Source Port Range: `All`
    - Destination Port Range: `80,443`
    
### Configure
- login to your newly created instance. Note the username is `opc`. If you forget, banner will remind you.
    ```bash
    ssh -i ssh-key.key opc@public.ip.add.ress
    ```
    
- Add firewall rules
    ```bash
    sudo firewall-cmd --permanent --zone=public --add-port=80/tcp
    sudo firewall-cmd --permanent --zone=public --add-port=443/tcp
    sudo firewall-cmd —reload
    ```
- Install prerequisites
    ```bash
    yum-config-manager --enable ol7_addons
    sudo yum install git nc docker-engine -y
    systemctl start docker
    systemctl enable docker
    ```
- There is a way to use Oracle's email gateway for outgoing emails (Hamburger \| Email Delivery \| Email Configuration), but I already had Amazon SES configured, so I was going to use that.

## Discourse

### Install
Download it first:
```bash
sudo -s
git clone https://github.com/discourse/discourse_docker.git /var/discourse
cd /var/discourse
```

Before you proceed you would need to apply a dirty hack to override hardware detection in the install script. For some reason CPU count and memory size detection returns 0 and instead of debugging the script it's much easier to just hardcode data we already know about our instance.  

```diff
diff --git a/discourse-setup b/discourse-setup
index b4472a6..f5dca47 100755
--- a/discourse-setup
+++ b/discourse-setup
@@ -221,6 +221,11 @@ scale_ram_and_cpu() {
     avail_gb=$(check_linux_memory)
     avail_cores=$((`awk '/cpu cores/ {print $4;exit}' /proc/cpuinfo`*`sort /proc/cpuinfo | uniq | grep -c "physical id"`))
   fi
+
+  # Dirty hack to workaround broken detection on Oracle Linux
+  avail_gb=1
+  avail_cores=1
+
   echo "Found ${avail_gb}GB of memory and $avail_cores physical CPU cores"

   # db_shared_buffers: 128MB for 1GB, 256MB for 2GB, or 256MB * GB, max 4096MB
```

Save this into e.g. `patch.diff` in `/var/discourse` folder and apply `patch -p1 < patch.diff`. 

Now proceed with the install as usual.
```bash
./discourse-setup
```
Follow the [official guide](https://github.com/discourse/discourse/blob/master/docs/INSTALL-cloud.md) for the rest of configuring the instance, including auto-updates, reporting, and backups.



### Migrate comments
Discourse includes a script to do that, however it seems to be broken as of today: disqus does not export email addresses for users and the migration script faceplants when email is empty. 

So, follow this [https://meta.discourse.org/t/migrating-to-discourse-from-another-forum-software/16616](https://meta.discourse.org/t/migrating-to-discourse-from-another-forum-software/16616) to setup development environment on your local machine, then export backup from your cloud instance and restore your local environment with it. 

This assumes you have working ruby environment on your machine. if not - [install](https://github.com/rbenv/rbenv) it throug homebrew: 

```bash
brew install rbenv ruby-build
rbenv init
```

Then set local environment to whatever you want: `rbenv local 2.7.1`.

[Export your comments history from disqus](https://help.disqus.com/en/articles/1717164-comments-export), but before running migration scrip to import the file apply the following patch: 

```diff
diff --git a/script/import_scripts/disqus.rb b/script/import_scripts/disqus.rb
index 5dbeb08775..5fd1621d1b 100644
--- a/script/import_scripts/disqus.rb
+++ b/script/import_scripts/disqus.rb
@@ -35,11 +35,15 @@ class ImportScripts::Disqus < ImportScripts::Base
     by_email = {}

     @parser.posts.each do |id, p|
+      p[:author_email] = "#{p[:author_username]}@disqus.invalid" unless p[:author_usrname]
       next if p[:is_spam] == 'true' || p[:is_deleted] == 'true'
+      puts "name: #{p[:author_name]}, username: #{p[:author_username]}, email: #{p[:author_email]} "
       by_email[p[:author_email]] = { name: p[:author_name], username: p[:author_username] }
     end

-    @parser.threads.each do |id, t|
+     @parser.threads.each do |id, t|
+      t[:author_username] = "#{t[:author_name]}" unless t[:author_username]
+      t[:author_email] = "#{t[:author_username]}@disqus.invalid" unless t[:author_email]
       by_email[t[:author_email]] = { name: t[:author_name], username: t[:author_username] }
     end
```

Then modify the information up top (path to xml file exported from disqus and category to apply to the posts) and run 

```bash
bundle exec ruby script/import_scripts/disqus.rb
```
 
 Now save the backup, download it, upload to your cloud instance and restore there. Great. 
 
## Embedding 
For embedding: go to https://your.forum.example.com/admin/customize/embedding -- substitute with your forum URL, and do the following (each step important)
- provide FQDN of allowed host and category where to create discussions
- Specify username for topic creation
- Disable Truncate the embedded posts
- Enable making topics unlisted until there is a reply.

Then follow the embedding instructions on that page: insert the snippet into `_layouts\post.html` of your jekyll blog source, right next to disqus piece, and disable disqus in your `_config.yml`.


## Summary
The resulting instance is not the fastest, especially when logging in as admin, but it's sufficient to host comments for low traffic site like this one and at least the goal of shielding my readers from third party trackers has been accomplished.