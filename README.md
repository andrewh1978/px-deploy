# What

This will deploy one or more clusters in the cloud, with optional post-install tasks defined by template.

# Supported platforms

## Container
 * Kubernetes
 * Openshift 3.11

## Cloud
 * AWS
 * GCP

1. Install the CLI for your choice of cloud provider:
 * AWS: https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html
 * GCP: https://cloud.google.com/sdk/docs/quickstarts

2. Install [Vagrant](https://www.vagrantup.com/downloads.html).

3. Install the Vagrant plugin for your choice of cloud provider:
 * AWS: `vagrant plugin install vagrant-aws`
 * GCP: `vagrant plugin install vagrant-google`

Note: For AWS, also need to install a dummy box:
```
vagrant box add dummy https://github.com/mitchellh/vagrant-aws/raw/master/dummy.box
```

4. Clone this repo and cd to it.

5. Configure cloud-specific environment and project/VPC:
 * AWS: Edit aws-create-vpc.sh and change AWS_region as required (you need to ensure this matches the region set in `$HOME/.aws/config` until https://github.com/mitchellh/vagrant-aws/pull/564 is merged).
 * GCP: Edit gcp-create-project.sh and change GCP_PROJECT and GCP_REGION as required.

6. Create cloud-specific VPC/project:
 * AWS: `sh aws-create-vpc.sh`
 * GCP: `sh gcp-create-project.sh`

Notes for GCP:
 * Billing needs to be enabled:
```
gcloud alpha billing projects link $PROJECT --billing-account $(gcloud alpha billing accounts list | tail -1 | cut -f 1 -d " ")
```
 * Create JSON service account key: On GCP console, select the Project, click APIs and Services, Credentials, Create Credentials, Service account key, Create. Save the file.

7. If running on macOS, install GNU Getopt:
```
brew install gnu-getopt
echo 'export PATH="/usr/local/opt/gnu-getopt/bin:$PATH"' >> ~/.bash_profile
```

8. Source the cloud-specific environment:
 * AWS: `. aws-env.sh`
 * GCP: `. gcp-env.sh`

9. Deploy some clusters:
```
./deploy.sh --template=px
```

10. Tear down the clusters:
```
./deploy.sh --destroy
```

# DESIGN

The `deploy.sh` script sets a number of environment variables:
 * `AWS_EBS` - a list of EBS volumes to be attached to each worker node. This is a space-separate list of type:size pairs, for example: `"gp2:30 standard:20"` will provision a gp2 volume of 30 GB and a standard volume of 20GB
 * `AWS_TYPE` - the AWS machine type for each node
 * `DEP_CLOUD` - the cloud on which to deploy (aws or gcp)
 * `DEP_CLUSTERS` - the number of clusters to deploy
 * `DEP_K8S_VERSION` - the version of Kubernetes to deploy
 * `DEP_NODES` - the number of worker nodes on each cluster
 * `DEP_PLATFORM` - can be set to either k8s or ocp3
 * `DEP_PX_VERSION` - the version of Portworx to install
 * `GCP_DISKS` - similar to AWS_EBS, for example: `"pd-standard:20 pd-ssd:30"`
 * `GCP_KEYFILE` - path to the GCP JSON keyfile
 * `GCP_TYPE` - the GCP machine type for each node

The defaults are defined in the script.

There are two ways to override these variables. The first is to specify a template with the `--template=...` parameter. For example:
```
$ cat templates/clusterpair
DEP_CLUSTERS=2
DEP_PX_VERSION=2.3.2
DEP_PX_CLUSTER_PREFIX=px-deploy
DEP_SCRIPTS="install-px clusterpair"
```

More on DEP_SCRIPTS below.

The second way to override the defaults is to specify on the command line. See `./deploy -h` for a full list. For example:
```
./deploy --clusters=5 --template=petclinic --nodes=6
```

This example is a mixture of both methods. The template is applied, then the command line parameters are applied, so not only is the template overriding the defaults, but also the parameters are overriding the template.

`DEP_SCRIPTS` is a list of scripts to be executed on each master node. For example:
```
$ cat scripts/clusterpair
(
if [ $cluster != 1 ]; then
  while : ; do
    token=$(ssh -oConnectTimeout=1 -oStrictHostKeyChecking=no node-$cluster-1 pxctl cluster token show 2>/dev/null | cut -f 3 -d " ")
    echo $token | grep -Eq '\w{128}'
    [ $? -eq 0 ] && break
    sleep 5
    echo waiting for portworx
  done
  storkctl generate clusterpair -n default remotecluster-$cluster | sed "/insert_storage_options_here/c\    ip: node-$cluster-1\n    token: $token" >/var/tmp/cp.yaml
  while : ; do
    cat /var/tmp/cp.yaml | ssh -oConnectTimeout=1 -oStrictHostKeyChecking=no master-1 kubectl apply -f -
    [ $? -eq 0 ] && break
    sleep 5
  done
fi
) >&/var/log/vagrant-clusterpair
```

All of the variables above are passed to the script. In addition to these, there are some more variables available:
 * `$cluster` - cluster number
 * `$script` - filename of the script

# NOTES

 * The `status.sh` script will output a list of master nodes and IP addresses:
```
$ sh status.sh
master-1 34.245.47.251 ec2-34-245-47-251.eu-west-1.compute.amazonaws.com
master-2 34.252.74.216 ec2-34-252-74-216.eu-west-1.compute.amazonaws.com
master-3 34.245.11.144 ec2-34-245-11-144.eu-west-1.compute.amazonaws.com
...
```

 * The `connect.sh` script will look up the first master node and SSH to it using the generated RSA ke:
```
$ sh connect.sh
Warning: Permanently added '54.194.101.251' (ECDSA) to the list of known hosts.
Last login: Tue Jan 14 14:35:49 2020 from cpc1-lea23-2-0-cust245.6-3.cable.virginm.net
[root@master-1 ~]#
```

# BUGS
 * When destroying the clusters as above, it uses the default number of clusters and nodes, so will only destroy master-1, node-1-1, node-1-2 and node-1-3, unless --clusters and --nodes are specified.

# TODO
 * Maintain state - ability to list currently deployed deployments and login to each via CLI
 * Initialise environment from deploy script rather than hacky aws/gcp scripts
