# What

This will deploy one or more clusters in the cloud, with optional post-install tasks defined by template.

# Supported platforms

## Container
 * Kubernetes
 * Openshift 3.11

## Cloud
 * AWS
 * GCP

1. Install the CLI for your choice of cloud provider and ensure it is configured:
 * AWS: https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html
 * GCP: https://cloud.google.com/sdk/docs/quickstarts

2. Install and enable Docker.

3. Clone this repo and cd to it.

4. Run the install script:
```
sh install.sh
```
This will:
 * build the Docker image
 * create and populate `$HOME/.px-deploy`
 * add an alias to `.bash_profile`, which will require sourcing

5. Deploy something
```
px-deploy --env=myDeployment --template=clusterpair
```
This will provision a VPC and some other objects, and deploy into it from the template.

6. Connect via SSH:
```
px-deploy --env=myDeployment --ssh
```

7. Tear down the environment:
```
px-deploy --env=myDeployment --destroy
```

# NOTES

The environments can be listed:
```
$ px-deploy --envs
Environment  Cloud  Region         Template  Clusters  Nodes  Created
foo          aws    eu-west-2      px        1         3      2020-02-04 09:52:10
bar          gcp    europe-north1  <none>    1         3      2020-02-04 09:50:11
```

The `defaults` file sets a number of environment variables:
 * `AWS_EBS` - a list of EBS volumes to be attached to each worker node. This is a space-separate list of type:size pairs, for example: `"gp2:30 standard:20"` will provision a gp2 volume of 30 GB and a standard volume of 20GB
 * `AWS_REGION` - AWS region
 * `AWS_TYPE` - the AWS machine type for each node
 * `DEP_CLOUD` - the cloud on which to deploy (aws or gcp)
 * `DEP_CLUSTERS` - the number of clusters to deploy
 * `DEP_K8S_VERSION` - the version of Kubernetes to deploy
 * `DEP_NODES` - the number of worker nodes on each cluster
 * `DEP_PLATFORM` - can be set to either k8s or ocp3
 * `DEP_PX_VERSION` - the version of Portworx to install
 * `GCP_DISKS` - similar to AWS_EBS, for example: `"pd-standard:20 pd-ssd:30"`
 * `GCP_REGION` - GCP region
 * `GCP_TYPE` - the GCP machine type for each node
 * `GCP_ZONE` - GCP zone

There are two ways to override these variables. The first is to specify a template with the `--template=...` parameter. For example:
```
$ cat templates/clusterpair
DEP_CLUSTERS=2
DEP_PX_CLUSTER_PREFIX=px-deploy
DEP_SCRIPTS="install-px clusterpair"
```

More on `DEP_SCRIPTS` below.

The second way to override the defaults is to specify on the command line. See `px-deploy -h` for a full list. For example, to deploy into the `foo` environment:
```
px-deploy --env=foo --clusters=5 --template=petclinic --nodes=6
```

This example is a mixture of both methods. The template is applied, then the command line parameters are applied, so not only is the template overriding the defaults, but also the parameters are overriding the template.

`DEP_SCRIPTS` is a list of scripts to be executed on each master node. For example:
```
$ cat ~/.px-deploy/scripts/clusterpair
exec &>/var/log/vagrant.$script
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
```

All of the variables above are passed to the script. In addition to these, there are some more variables available:
 * `$cluster` - cluster number
 * `$script` - filename of the script
