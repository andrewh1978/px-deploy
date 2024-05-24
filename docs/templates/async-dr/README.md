# Async-DR

Deploys 2 clusters with Portworx, sets up and configures a cluster pairing, configures an async DR schedule with a loadbalancer in front of the setup.

# Supported Environments

* AWS

No other enviroments are currently supported.

# Requirements

## Create a bucket for use by DR

You will need to create an S3 bucket for use by the DR migrations. You will add the name of this bucket to defaults.yml (per the below instructions.)

## Update defaults.yml

Update your `defaults.yml` with the following:

```
env:
  operator: true
  licenses: "XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX"
  DR_BUCKET: "<YOUR BUCKET NAME>"
```

* `operator: true` ensures that Portworx is deployed as an operator.
* `licenses:` requires a valid license activation code that includes DR (the trial license does not include DR!!).
* `DR_BUCKET` is the name of the bucket created earlier.


## Deploy the template

It is a best practice to use your initials or name as part of the name of the deployment in order to make it easier for others to see the ownership of the deployment in the AWS console.

```
px-deploy create -C aws -t async-dr -n <my-deployment-name>
```

## Sample Demo Workflow

TBD