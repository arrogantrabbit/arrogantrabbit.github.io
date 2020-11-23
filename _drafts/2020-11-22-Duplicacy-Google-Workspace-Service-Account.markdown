---
layout: post
title:  "Duplicacy backup to Google Drive with Service Account"
date: 2020-11-22 22:00:00 -0700
categories: ["Backup"]
tags: ["Duplicacy", "Google Workspace"]
excerpt: How to backup with Duplicacy to Google Workspace with Service Account 
---

* TOC
{:toc}

## What is this about

Duplicacy supports Google Drive backend allowing to utilize storage at the Google Drive account including G-Suite/Google Workspace). 

The existing mechanism described in the [duplicacy documentation](https://forum.duplicacy.com/t/supported-storage-backends/1107?u=saspus) works, but suffers from several drawbacks: 

1. Duplicacy-owned Google project is used to create login credentials, shared by all users.
2. The OAUTH credentials needs to be renewed periodically requiring duplicacy.com being reachable and available. 
3. The duplicacy datastore sticks in user's Drive as a sore thumb, polluting recently changed files list with opaque chunk data.

We can avoid drawbacks 1-2 by providing duplicacy with credentials to a service account created in our own project with permissions to impersonate the specific user.

Drawback 3 can be avoided by using `drive.appdata` scope to store the duplicacy datastore thus limiting exposure of the user's Drive folder and avoiding polluting the former with the latter. However it is not yet possible to do so with Duplicacy, as it does not yet support `appDataFolder` so the walkthrough below will describe how to use service account without renewable tokens but it will be authorized to place data in user's drive folder. Like a sore thumb for now. Until [this thread](https://forum.duplicacy.com/t/google-drive-drive-appdata-scope-service-account-impersonate/4462?u=saspus) comes to fruition.

## TLDR

1. Create Project on [https://console.cloud.google.com](https://console.cloud.google.com).
2. Enable Google Drive API.
3. Configure Internal OAUTH with `https://www.googleapis.com/auth/drive` scope.
4. Create Service Account, enable Domain-Wide Delegation, and export JSON with credentials.
5. Add `subject` key pointing to the user to impersonate to the downloaded json.
6. On [https://admin.google.com](https://admin.google.com) under Security, API Controls, Domain-wide Delegation add created API client with `https://www.googleapis.com/auth/drive` scope.
7. Modify duplicacy code to honor `subject` filed in the token file, if it is not already done.


## Walkthrough

### Preparing Service Account 

1. Login to [https://console.cloud.google.com](https://console.cloud.google.com) and click the drop-down, between words "Google Cloud Platform" and "Search products and resources" up top. Select your organization in the dropdown list if it is not yet selected and click `NEW PROJECT`: 
![GCP Project Dropdown]({{ "/assets/gcp-project-dropdown.png" | absolute_url }}) 
2. Give the project a name. We'll call it `Duplicacy-InDrive`. Click `CREATE`:
![Create Project]({{ "/assets/gcp-new-project-in-drive.png" | absolute_url }}) 
3. If the newly created project is not selected in the drop down box up top -- select it. If needed - click Hamburger Menu, "API & Services", to end up on this screen:
![Project Created]({{ "/assets/gcp-project-created.png" | absolute_url }}) 
4. Click `ENABLE APIS AND SERVICES`:
![Welcome to API]({{ "/assets/gcp-welcome-to-api.png" | absolute_url }}) 
5. Search for "Google Drive" and click on "Google Drive API": 
![Search for Google Drive]({{ "/assets/gcp-api-search-google-drive.png" | absolute_url }}) 
6. Click `ENABLE`: 
![Enable API]({{ "/assets/gcp-api-enable-google-drive.png" | absolute_url }}) 
7. Once API is enabled you will end up back on the project page. On the left, click "Credentials" (If you are lost, this is located under Hamburger Menu, under "API & Services"), and then `CONFIGURE CONSENT SCREEN`.
![Api Enabled]({{ "/assets/gcp-api-library-credentials.png" | absolute_url }}) 
8. Select "Internal" and click `CREATE`:
![Consent Internal]({{ "/assets/gcp-api-consent-internal.png" | absolute_url }}) 
9. Choose app name and user support email: 
![App Name]({{ "/assets/gcp-api-app-information-1.png" | absolute_url }}) 
10. Scroll down, add developer contact info, and click `SAVE AND CONTINUE`: 
![App Name]({{ "/assets/gcp-api-app-information-2.png" | absolute_url }}) 
11. This part is very important: this will define application access scope. Click on `ADD OR REMOVE SCOPES`:
![App Name]({{ "/assets/gcp-api-scopes.png" | absolute_url }}) 
12. The available scopes are [described here](https://developers.google.com/identity/protocols/oauth2/scopes). We are interested in the scope that gives the application full access to the drive: `../auth/drive` or `https://www.googleapis.com/auth/drive` which is full permission scope. Once we have support for appdata directory in duplicacy we should be able to instead only grant `../auth/drive.appdata` scope. For now, either click the checkbox next to `../auth/drive` or paste the scope URL to "Manually add scopes" box. Then click `UPDATE`: 
![App Name]({{ "/assets/gcp-api-scopes-selected.png" | absolute_url }}) 
13. The scope would be added to the list of Sensitive scopes. (The appdata scope would have been added to the less restrictive non-sensitive scopes). Then click `SAVE AND CONTINUE`:
![App Name]({{ "/assets/gcp-api-scopes-added-sensitive.png" | absolute_url }}) 

14. Confirmation screen will be displayed in a little while. Go back to "API & Services", "Credentials", and click `+ CREATE CREDENTIALS`. In the popup menu select "Service Account":
![App Name]({{ "/assets/gcp-api-create-credentials.png" | absolute_url }}) 
15. Fill in service account details and click `CREATE`: 
![App Name]({{ "/assets/gcp-api-service-account-details.png" | absolute_url }}) 
16. On the next screen click `DONE`: 
![App Name]({{ "/assets/gcp-api-service-account-done.png" | absolute_url }}) 
17. Back on the "Credentials" page click on the pencil next to the service account we just created:
![App Name]({{ "/assets/gcp-api-manage-service-account.png" | absolute_url }}) 
18. Here we'll need to do a few things: 
    1. Take a note of Unique ID. Save it somewhere, we'll need it later.
    2. Expand `SHOW DOMAIN DELEGATION` and tick the checkbox there. This will grant the service account access to all users data on the domain.
    3. Click `ADD KEY`, "Create New Key": 
![App Name]({{ "/assets/gcp-api-service-account-keys.png" | absolute_url }}) 
19. Select JSON and click `CREATE`:
![App Name]({{ "/assets/gcp-api-service-account-keys-json.png" | absolute_url }}) 
20. The json file with access credentials including the private keys will be saved to your machine, something like `duplicacy-indrive-4bb13facf8fb.json`

### Granting service account access to domain
Now, change of scenery. Go to [https://admin.google.com](https://admin.google.com), there

1. Click `Security`, 
2. Scroll all the way down, click `API Controls`
3. Scroll all the way down, click  `Manage Domain Wide Delegation`:
![App Name]({{ "/assets/gcp-admin-domain-wide-delegation.png" | absolute_url }}) 
4. Click `Add New` and input the following information:
    - UniqueID we saved in step 18 above.
    - Scope from step 14: `https://www.googleapis.com/auth/drive`
![App Name]({{ "/assets/gcp-admin-domain-wide-delegation-add-id.png" | absolute_url }}) 
Then click `AUTHORIZE`. 

### Configuring duplicacy for impersonation

Open downloaded json file and add `"subject": "alex@arrogantrabbit.com"` to tell duplicacy which account to impersonate; don't forget the `,` (edited to save space).:

```json
{
  "type": "service_account",
  "project_id": "duplicacy-indrive",
  "private_key_id": "4b...1be12",
  "private_key": "-----BEGIN PRIVATE ... ---END PRIVATE KEY-----\n",
  "client_email": "duplicacy@duplicacy-indrive.iam.gserviceaccount.com",
  "client_id": "102629977222638015216",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/duplicacy%40duplicacy-indrive.iam.gserviceaccount.com",
  "subject": "alex@arrogantrabbit.com"
}
```

#### Patching in support for `subject` field unless already implemented

Note: As of today duplicacy does not honor `subject` field from the json file. More information can be found [here](https://forum.duplicacy.com/t/google-drive-drive-appdata-scope-service-account-impersonate/4462/5?u=saspus). There is however an easy fix: 
 
```diff
diff --git a/src/duplicacy_gcdstorage.go b/src/duplicacy_gcdstorage.go
index 85c4c93..25bd9b9 100644
--- a/src/duplicacy_gcdstorage.go
+++ b/src/duplicacy_gcdstorage.go
@@ -349,6 +349,9 @@ func CreateGCDStorage(tokenFile string, driveID string, storagePath string, thre
                if err != nil {
                        return nil, err
                }
+                if subject, ok := object["subject"]; ok {
+                        config.Subject = subject.(string)
+                }
                tokenSource = config.TokenSource(ctx)
        } else {
                gcdConfig := &GCDConfig{}
```

On a mac, the process is really simple: 
1. Install go: `brew install go`
2. Fetch duplicacy and all dependencies: `go get github.com/gilbertchen/duplicacy/duplicacy`. This may take a while. 
3. Edit the `~/go/src/github.com/gilbertchen/duplicacy/src/duplicacy_gcdstorage.go` and make the change above. For convenience, we host the patch file here download the [{{ "/assets/duplicacy_gcd_subject.patch" | absolute_url }}]({{ "/assets/duplicacy_gcd_subject.patch" | absolute_url }}) so you can directly do this:
```bash
cd ~/go/src/github.com/gilbertchen/duplicacy
curl {{ "/assets/duplicacy_gcd_subject.patch" | absolute_url }} | patch -p1
```
4. Build Duplicacy
```
go install github.com/gilbertchen/duplicacy/duplicacy
```

The executable will end up at `~/go/bin/duplicacy`. You may want to symlink it somewhere useful to avoid specifying the full path all over the place: 
```bash
ln -s ~/go/bin/duplicacy /usr/local/bin/duplicacy
```

## Configuring and testing

### Initialize repository
Lets configure duplicacy in the user's home folder. For convenience we'll store the downloaded json file right in the users' home folder. We'll have duplicacy use "duplicacy" subfolder at our google drive. We will not use RSA encryption for this example, but will use encryption password.

1. Create `.duplicacy` folder and copy the downloaded .json file there

	```bash
	cd
	mkdir -p .duplicacy
	cp ~/Downloads/duplicacy-indrive-4bb13facf8fb.json .duplicacy/ 
	```

2. Initialize repository with encryption (we'll use "obsidian" as a backup ID): 
	```
	% duplicacy init -e obsidian gcd://duplicacy
	Enter the path of the Google Drive token file (downloadable from https://duplicacy.com/gcd_start):.duplicacy/duplicacy-indrive-4bb13facf8fb.json
	Enter storage password for gcd://duplicacy:**************************************************
	Re-enter storage password:**************************************************
	/Users/me will be backed up to gcd://duplicacy with id obsidian
	```

	Login to [https://drive.google.com](https://drive.google.com) and confirm that the duplicacy folder is present in the root of My Drive.

3. Configure duplicacy to honor Time Machine exclusions: 
```
% duplicacy set -exclude-by-attribute=true
```
Note, on the first run duplicacy will prompt access to keychain and will store encryption password and path to the GCD token there. If use of keychain is undesirable, duplicacy can be instructed not to bother and instead store required data in the `.duplicacy/preferenfces` file like so:
```
% duplicacy set -key 'password' -value 'stroage-pa$$w0rd'
% duplicacy set -key 'gcd_token' -value '.duplicacy/duplicacy-indrive-4bb13facf8fb.json'
% duplicacy set -no-save-password=true
```

### Backup

To perform backup run the following from the users' home:
```
% duplicacy backup -vss
```

Few things to note here:

1. Duplicacy CLI executable will not have access to Documents, Photos, and other sensitive folders unless one of two things happen: 
	- SIP is disabled
	- Duplicacy is wrapped into an application bundle that is granted Full Disk Access in the System Preferences. Adding naked executable there is not enough. For example, use Duplicacy Web GUI or create wrapper in Automator. 
2. If you make a mistake and want to create repository from scratch -- delete folder on google drive and then nuke `.duplicacy/preferences` file. Or delete specific repository from it, if you have more than one.
3. It's useful to run first backup with `-dry-run` flag to ensure that everything is accessible and exclude unnecessary data.
4. If you have Google File Streams installed it might be a good idea to exclude the duplicacy datastore:
    ```
    tmutil addexclusion ~/Google\ Drive\ File\ Stream/My\ Drive/duplicacy
    ```
    Yep, GFS supports extended attributes. Is not that awesome!