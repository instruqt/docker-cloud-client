# Instruqt Cloud Client Container

This is the `cloud-client` container, that can be used on the Instruqt platform to interact with the different supported cloud accounts.

Test localy with: 

```
make
docker run --env-file .env pablopez/cloud-client:latest
```

## What this does

The Cloud Client container can be used to get access to the cloud resources defined in an Instruqt track.

It runs nginx on port 80 to display links to the GCP and AWS Consoles for all of the cloud resources configured the track, and shows the credentials required to login.

The container also includes the `gcloud` and `aws` cli tools, pre-configured with the required credentials.

It uses the env vars ([GCP](https://docs.instruqt.com/#using-gcp-projects)/[AWS](https://docs.instruqt.com/#using-aws-accounts)) injected by Instruqt to configure nginx and the cli tools.


## Usage

See https://docs.instruqt.com/#cloud-client-container