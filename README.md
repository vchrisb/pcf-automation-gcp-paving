# pcf-automation-gcp-paving

This repo contains a concourse pipeline and tasks to automatically deploy Pivotal Application Services on GCP, including paving the environment using Terraform.
It is mostly meant to be used for testing, as credentials handling could be improved.
It is using [terraforming-gcp](https://github.com/pivotal-cf/terraforming-gcp) and [Platform Automation](http://docs-platform-automation.cfapps.io/platform-automation/v2.0/index.html) to do so.

# Features

* the pipeline can be deployed multiple times with different values for `env_name`
  * for each pipeline there will be a dedicated subdomain created in gcp: `env_name.dns_suffix`
* letsencrypt certificates are generated for PAS and Ops Manager

# Reqirements

* GCP account
* Pivotal Network account
* Private Git Repository
* three private GCS Buckets
* concourse
* a (sub-)domain hosted on GCP

# Credentials

To keep it simple and easy deployable on any concourse installation, the pipeline currently gets most of its credentials and customization fron a `credentials.yml` file.
Copy the `credentials-template.yml` file to `credentials.yml` and modify the appropriate items.

# Deploy Pipline

```
fly login -t env -c https://concourse.domain.com -n team
fly -t env set-pipeline -p pcf-platform-automation -c pipeline.yml -l credentials.yml --verbose
fly -t env unpause-pipeline -p pcf-platform-automation
```
