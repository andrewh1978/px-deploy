
# Notes for OCP4 on AWS

A "master" node will be provisioned for each cluster. This is not really a master node - it is just where `openshift-install` is run. The root user will have a kubeconfig, so it can be treated as a master node for the purposes of the scripts used in the templates.

## ocp4_domain setting

A subdomain must be delegated to Route53 on the same AWS account, so you will need to be able to create records for your own domain:

1. Login to the AWS console and go to Route53.

2. Click on "Hosted Zones". "Click on Created hosted zone".

3. Enter the subdomain, eg openshift.example.com and click "Created hosted zone". It will give you 4 authoritative nameservers for the subdomain. 

4. Login to your DNS provider.

5. Create an NS record for each of the nameservers for the subdomain, eg:
```
$ host -t ns openshift.example.com
openshift.example.com name server ns-1386.awsdns-45.org.
openshift.example.com name server ns-1845.awsdns-38.co.uk.
openshift.example.com name server ns-282.awsdns-35.com.
openshift.example.com name server ns-730.awsdns-27.net.
```

6. Wait a few minutes for the changes to be reflected. Then validate all is well in Route53:
```
$ host -t soa openshift.example.com
openshift.example.com has SOA record ns-730.awsdns-227.net. awsdns-hostmaster.amazon.com. 1 7200 900 1209600 86400
```

7. add the subdomain to `defaults.yml`  e.g. `ocp4_domain: openshift.example.com`

## ocp4_pull_secret 

You need to obtain an Openshift pull secret

1. login to https://console.redhat.com/openshift

2. select Clusters -> Create cluster -> Local -> Copy Pull Secret

3. copy content into value of `ocp4_pull_secret` in `defaults.yml` and ensure its enclosed by single quotation marks

```
ocp4_pull_secret: '{"auths":{"cloud.openshift.com":{"auth":"a4E.....lcUR==","email":"mail@mail.com"}}}'
```