---
layout: post
title:  "Duplicacy backup to Google Drive with Service Account"
date: 2020-11-23 10:00:00 -0700
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

Drawback 3 can be avoided by using `drive.appdata` instead of `drive` or `drive.file` scope to store the duplicacy datastore thus limiting exposure of the user's Drive folder and avoiding polluting the latter with the former. 


## TLDR

1. Create Project on [https://console.cloud.google.com](https://console.cloud.google.com).
2. Enable Google Drive API.
3. Configure Internal OAUTH with `https://www.googleapis.com/auth/drive.appdata` scope (or `drive` or `drive.file` to place the datastore into `My Drive` folder).
4. Create Service Account, enable Domain-Wide Delegation, and export JSON with credentials.
5. Add `subject` key pointing to the user to impersonate to the downloaded json.
6. Add `scope` key pointing to the chosen scope (can be omitted for `drive` scope)
7. On [https://admin.google.com](https://admin.google.com) under Security, API Controls, Domain-wide Delegation add created API client with same scope as in step 3 above.
8. Modify duplicacy code to honor `subject`  and `scope` fields in the token file, untile the change makes it to the release.


## Walkthrough

### Preparing Service Account 

1. Login to [https://console.cloud.google.com](https://console.cloud.google.com) and click the drop-down, between words "Google Cloud Platform" and "Search products and resources" up top. Select your organization in the dropdown list if it is not yet selected and click `NEW PROJECT`: 
![GCP Project Dropdown]({{ "/assets/gcp-project-dropdown.png" | absolute_url }}) 
2. Give the project a name. We'll call it `Duplicacy-App`. Click `CREATE`:
![Create Project]({{ "/assets/gcp-new-project-app.png" | absolute_url }}) 
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
12. The available scopes are [described here](https://developers.google.com/identity/protocols/oauth2/scopes). 
   - If you would like the datastore to be placed into the My Drive folder we need to grant access to `https://www.googleapis.com/auth/drive` scope, which is full permission scope. Alternatively, `drive.file` can be used. 
   - For placing the datastore to hidden app-data folder that only duplciacy can access, without giving it full access to entire drive use  `../auth/drive.appdata` scope. 
  Either click the checkbox next to the desired scope (`../auth/drive.appdata`) or paste the scope URL to "Manually add scopes" box. Then click `UPDATE`: 
![App Name]({{ "/assets/gcp-api-scopes-selected-appdata.png" | absolute_url }}) 
13. The scope would be added to the list of Non-Sensitive scope list. The `drive` scope would have been added to the more restrictive sensitive scopes. Then click `SAVE AND CONTINUE`:
![App Name]({{ "/assets/gcp-api-scopes-added-nonsensitive.png" | absolute_url }}) 
14. Confirmation screen will be displayed in a little while. Go back to "API & Services", "Credentials", and click `+ CREATE CREDENTIALS`. In the popup menu select "Service Account":
![App Name]({{ "/assets/gcp-api-create-credentials-appdata.png" | absolute_url }}) 
15. Fill in service account details and click `CREATE`: 
![App Name]({{ "/assets/gcp-api-service-account-details.png" | absolute_url }}) 
16. On the next screen click `DONE`: 
![App Name]({{ "/assets/gcp-api-service-account-done.png" | absolute_url }}) 
17. Back on the "Credentials" page click on the pencil next to the service account we just created:
![App Name]({{ "/assets/gcp-api-manage-service-account.png" | absolute_url }}) 
18. Here we'll need to do a few things: 
    1. Make a note of Unique ID for later.
    2. Expand `SHOW DOMAIN DELEGATION` and tick the checkbox there. This will grant the service account access to all users data on the domain.
    3. Click `ADD KEY`, "Create New Key": 
![App Name]({{ "/assets/gcp-api-service-account-keys.png" | absolute_url }}) 
19. Select JSON and click `CREATE`:
![App Name]({{ "/assets/gcp-api-service-account-keys-json.png" | absolute_url }}) 
20. The json file with access credentials including the private keys will be saved to your machine, something like `duplicacy-app-4e8ade810e46.json`

### Granting service account access to domain
Now, change of scenery. Go to [https://admin.google.com](https://admin.google.com), there

1. Click `Security`. 
2. Scroll all the way down, click `API Controls`.
3. Scroll all the way down, click  `Manage Domain Wide Delegation`, `Add New` and input the following information:
    - UniqueID we saved in step 18 above.
    - Scope from step 12: `https://www.googleapis.com/auth/drive.appdata`
![App Name]({{ "/assets/gcp-admin-domain-wide-delegation-add-id.png" | absolute_url }}) 
Then click `AUTHORIZE`. 

### Configuring duplicacy for impersonation

Open downloaded json file and add `"subject": "chipmunk@arrogantrabbit.com"` to tell duplicacy which account to impersonate; don't forget the `,`, and the correct scope; same as above:

```json
{
  "type": "service_account",
  "project_id": "duplicacy-app",
  "private_key_id": "4e8ade810e....ea0892f",
  "private_key": "--...--\n",
  "client_email": "duplicacy@duplicacy-app.iam.gserviceaccount.com",
  "client_id": "104387532945714391723",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/duplicacy%40duplicacy-app.iam.gserviceaccount.com",
  "subject": "chipmunk@arrogantrabbit.com",
  "scope": "https://www.googleapis.com/auth/drive.appdata"
}

```

#### Patching in support for `subject` and `scope` fields unless already implemented

As of today duplicacy does not honor `subject` and `scope` field from the json file. More information, along with the link to the pull request can be found [here](https://forum.duplicacy.com/t/google-drive-drive-appdata-scope-service-account-impersonate/4462/5?u=saspus). In the meantime this patch can be applied to the top of tree:  [{{ "/assets/duplicacy_gcd_subject_scope.patch" | absolute_url }}]({{ "/assets/duplicacy_gcd_subject_scope.patch" | absolute_url }})
 
On a mac, the process is really simple: 
1. Install go: `brew install go`.
2. Fetch duplicacy and all dependencies: `go get github.com/gilbertchen/duplicacy/duplicacy`. This may take a while. 
3. Patch: 
	```bash
	cd ~/go/src/github.com/gilbertchen/duplicacy
	curl {{ "/assets/duplicacy_gcd_subject_scope.patch" | absolute_url }} | patch -p1
	```
4. Build:
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
	cp ~/Downloads/duplicacy-app-4e8ade810e46.json .duplicacy/ 
	```

2. Initialize repository with encryption (we'll use "obsidian" as a backup ID): 
	```
	% duplicacy init -e obsidian gcd://duplicacy
	Enter the path of the Google Drive token file (downloadable from https://duplicacy.com/gcd_start):.duplicacy/duplicacy-app-4e8ade810e46.json
	Enter storage password for gcd://duplicacy:**************************************************
	Re-enter storage password:**************************************************
	/Users/me will be backed up to gcd://duplicacy with id obsidian
	```

	Login to [https://drive.google.com](https://drive.google.com) and confirm that the duplicacy folder is present in the root of My Drive if the `drive` or `drive.file` scope was selected. Otherwise click Gear - Settings - Manage Apps and confirm Duplicacy is in the list: 
	
    ![App Name]({{ "/assets/gcp-drive-app-in-the-list.png" | absolute_url }}) 

3. Configure duplicacy to honor Time Machine exclusions: 
```
% duplicacy set -exclude-by-attribute=true
```
Note, on the first run duplicacy will prompt access to keychain and will store encryption password and path to the GCD token there. If use of keychain is undesirable, duplicacy can be instructed not to bother and instead store required data in the `.duplicacy/preferenfces` file like so:
```
% duplicacy set -key 'password' -value 'stroage-pa$$w0rd'
% duplicacy set -key 'gcd_token' -value '.duplicacy/duplicacy-app-4e8ade810e46.json'
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
4. If you have Google File Streams installed and you want to back up contents of My Drive folder but you have selected `drive` or `drive.file` scope above thereby placing duplicacy datastore into `My Drive` folder exclude it from backup (yes, GFS supports extended attributes):
    ```
    tmutil addexclusion ~/Google\ Drive\ File\ Stream/My\ Drive/duplicacy
    ```
    It's also a good idea to exclude everything next to My Drive via `.duplicacy/filters` file:
    ```
    +Google Drive File Stream/
	+Google Drive File Stream/My Drive/*
	-Google Drive File Stream/* 
    ```
    Note, `Google Drive File Stream` is as symlink to `/Volumes/Google Drive`; however since we have initialized repo in the user home and duplicacy follows first level symlinks this happens to work really well.