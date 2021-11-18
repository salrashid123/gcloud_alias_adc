# gcloud alias for Application Default Credentials

Shell alias script that will print the active in-use account for GCP [application default credentials (ADC)](https://cloud.google.com/sdk/gcloud/reference/auth/application-default).

For example, if you run either

* `gcloud config list`
* `gcloud auth list`

this script will print the gcloud cli credentials as well as the application default credentials that are in use. This script will also transparently pass and apply parameters to the actual gcloud cli  (meaning the alisas it acts as if its gcloud)

>> This script is not supported by Google

As background, users can configure gcloud to use two different credential sets: one for the gcloud cli and one for any google cloud SDK library. Sometimes it's difficult to know which identity is used for ADC since there isn't an easy way to show that. For example, the following commands shows how two identities in use but only one is shown in `gcloud config list`:

```bash
$ gcloud config list

[core]
account = alice@domain.com   <<<<<<<<<<<<<<<
project = your-project-id
```


Now print the identity used in gcloud cli operations...notice its `alice@domain.com`

```bash
$ curl https://www.googleapis.com/oauth2/v3/tokeninfo?access_token=$(gcloud auth print-access-token)
{
  "azp": "32555940559.apps.googleusercontent.com",
  "aud": "32555940559.apps.googleusercontent.com",
  "sub": "111461344714442243111",
  "scope": "https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/cloud-platform https://www.googleapis.com/auth/appengine.admin https://www.googleapis.com/auth/compute https://www.googleapis.com/auth/accounts.reauth https://www.googleapis.com/auth/plus.me",
  "exp": "1550093476",
  "expires_in": "3600",
  "email": "alice@domain.com",    <<<<<<<<<<<<<<<
  "email_verified": "true",
  "access_type": "offline"
}
```

However, any cloud SDK operation could use a different identity at the same time for ADC...in this case its `bob@domain.com`:

```bash
$ curl https://www.googleapis.com/oauth2/v3/tokeninfo?access_token=$(gcloud auth application-default print-access-token)
{
  "azp": "764086051850-6qr4p6gpi6hn506pt8ejuq83di341hur.apps.googleusercontent.com",
  "aud": "764086051850-6qr4p6gpi6hn506pt8ejuq83di341hur.apps.googleusercontent.com",
  "sub": "108157913093274845548",
  "scope": "https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/cloud-platform https://www.googleapis.com/auth/plus.me",
  "exp": "1550093492",
  "expires_in": "3599",
  "email": "bob@domain.com",      <<<<<<<<<<<<<<<
  "email_verified": "true",
  "access_type": "offline"
}
```


However, if you use this alias, a `gcloud config list` will now show both credentials:

```bash
$ gcloud config list

[adc]
account = bob@domain.com
source = /home/bob/.config/gcloud/application_default_credentials.json


[core]
account = alice@domain.com
project = your-project-id
```


### Usage/Install

To use, install jq and yq to parse json and yaml:

```bash
apt-get install jq
pip3 install yq
```

then just create a file called [galias.sh](galias.sh), make it executable, then alias it:

```bash
chmod u+x /path/to/galias.sh
alias gcloud='/path/to/galias.sh'
```

add the alias to your `.profile` to make it permanent

---

You can apply json and yaml display parsing gcloud supports:

* `json`

```json
$ gcloud config list --format json
{
  "core": {
    "account": "alice@domain.com",
    "project": "your-project-id"
  },
  "adc": {
    "account": "bob@domain.com"
  }
}
```

* `yaml`

```yaml
$ gcloud config list --format yaml
core:
  account: alice@domain.com
  project: your-project-id
adc:
  account: bob@domain.com
```

The rendering of json and yaml with the additional `adc.account=` value is done _after_ gcloud finishes applying any formatting. What that means is this script does *NOT* support advanced formatting (eg you cannot use `gcloud config list --format="value(ac.account)"`. Instead use `jq,yq` on the whole command:

```bash
$ gcloud config list --format=json  | jq -r '.adc.account'
  bob@domain.com

$ gcloud config list --format=yaml  | yq -r '.adc.account'
  bob@domain.com
```

### Test Cases

Note, the home directory is always for alice since she is the logged in user to the OS

A) No ADC

```bash
$ gcloud auth application-default revoke
  You are about to revoke the credentials stored in: 
  [/home/alice/.config/gcloud/application_default_credentials.json]

  Credentials revoked.

$ unset GOOGLE_APPLICATION_CREDENTIALS
$ gcloud config list
  [adc]
  account = 
  source = 

  [core]
  account = alice@domain.com

  project = your-project-id
  ```

B) gcloud CLI with key file

```bash
$ gcloud config list
  [adc]
  account = bob@domain.com
  source = /home/alice/.config/gcloud/application_default_credentials.json

  [core]
  account = alice@domain.com
  project = your-project-id

$ gcloud auth activate-service-account --key-file=/path/to/svc-account.json

$ gcloud config list
  [adc]
  account = bob@domain.com
  source = /home/alice/.config/gcloud/application_default_credentials.json

  [core]
  account = svc-account@your-project-id.iam.gserviceaccount.com
  project = your-project-id
```

This is intended since gcloud auth activate-service-account configures gcloud cli and does not impact ADC

C) ADC with with `GOOGLE_APPLICATION_CREDENTIALS`

```bash
$ gcloud config list
  [adc]
  account = bob@domain.com
  source = /home/alice/.config/gcloud/application_default_credentials.json

  [core]
  account = alice@domain.com
  project = your-project-id

$ export GOOGLE_APPLICATION_CREDENTIALS=/path/to/svc-account.json

$ gcloud config list
  [adc]
  account = svc-account@your-project-id.iam.gserviceaccount.com
  source = /path/to/svc-account.json

  [core]
  account = alice@domain.com

  project = your-project-id
```

D) With Metadata Server

```bash
$ gcloud config list
  [adc]
  account = gce-svc-account@your-project-id.iam.gserviceaccount.com
  source = metadata

  [core]
  account = gce-svc-account@your-project-id.iam.gserviceaccount.com
  project = your-project-id
```

E) Metadata Server without Service Account

```bash
$ gcloud config list
  [adc]
  account = 
  source = 

  [core]
  project = your-project-id
```

F) `GOOGLE_APPLICATION_CREDENTIALS` with external_account

For use with federation:

- [OIDC Federation](https://github.com/salrashid123/gcpcompat-oidc#automatic)
- [AWS Federation](https://github.com/salrashid123/gcpcompat-aws#test-automatic)

```bash
# Federated with impersonation enabled
cat `pwd`/sts-creds.json
  {
    "type": "external_account",
    "audience": "//iam.googleapis.com/projects/1071284184436/locations/global/workloadIdentityPools/aws-pool-2/providers/aws-provider-2",
    "subject_token_type": "urn:ietf:params:aws:token-type:aws4_request",
    "token_url": "https://sts.googleapis.com/v1/token",
    "credential_source": {
      "environment_id": "aws1",
      "region_url": "http://169.254.169.254/latest/meta-data/placement/availability-zone",
      "url": "http://169.254.169.254/latest/meta-data/iam/security-credentials",
      "regional_cred_verification_url": "https://sts.{region}.amazonaws.com?Action=GetCallerIdentity&Version=2011-06-15"
    },
    "service_account_impersonation_url": "https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/aws-federated@your-project-id.iam.gserviceaccount.com:generateAccessToken"
  }

export GOOGLE_APPLICATION_CREDENTIALS=`pwd`/sts-creds.json

$ gcloud auth list
  [adc]
  account = https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/aws-federated@your-project-id.iam.gserviceaccount.com:generateAccessToken
  source = /path/to/sts-creds.json

  [core]
  account = user@domain.com
```

```bash
# Federated with without impersonation enabled
cat `pwd`/sts-creds.json
  {
    "type": "external_account",
    "audience": "//iam.googleapis.com/projects/1071284184436/locations/global/workloadIdentityPools/aws-pool-2/providers/aws-provider-2",
    "subject_token_type": "urn:ietf:params:aws:token-type:aws4_request",
    "token_url": "https://sts.googleapis.com/v1/token",
    "credential_source": {
      "environment_id": "aws1",
      "region_url": "http://169.254.169.254/latest/meta-data/placement/availability-zone",
      "url": "http://169.254.169.254/latest/meta-data/iam/security-credentials",
      "regional_cred_verification_url": "https://sts.{region}.amazonaws.com?Action=GetCallerIdentity&Version=2011-06-15"
    },
  }

export GOOGLE_APPLICATION_CREDENTIALS=`pwd`/sts-creds.json

$ gcloud auth list
  [adc]
  account = urn:ietf:params:oauth:token-type:jwt
  source = /path/to/sts-creds.json

  [core]
  account = user@domain.com
```

Note, the `account` value will either show which service account federation will use or if no impersonated credentials are even involved (which is rare)


