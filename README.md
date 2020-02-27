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

3. Install bash-completion (optional), eg:
```
$ brew install bash-completion
```
You will need to restart your shell.

4. Run the install script:
```
curl https://raw.githubusercontent.com/andrewh1978/px-deploy/master/install.sh | bash
```
This will:
 * build the Docker image
 * create and populate `$HOME/.px-deploy`
 * provide instructions to configure `.bash_profile`/`.zshrc`

5. Deploy something:
```
px-deploy create --name=myDeployment --template=clusterpair
```
This will provision a VPC and some other objects, and deploy into it from the template.

6. Connect via SSH:
```
px-deploy connect --name myDeployment
```

7. Tear down the deployment:
```
px-deploy destroy --name myDeployment
```

# NOTES

The deployments can be listed:
```
$ px-deploy list
Deployment Cloud Region        Platform Template Clusters Nodes Created
foo        aws   eu-west-1     k8s      px       1        3     2020-02-11T16:14:06Z
bar        gcp   europe-north1 gcp      <none>   1        3     2020-02-04T09:50:11Z
```

The templates can be listed:
```
$ px-deploy templates
Name                           Description
templates/clusterpair-apps.yml 2 clusters with Portworx, pair them and deploy some apps on cluster-1
templates/clusterpair.yml      2 clusters with Portworx and pair them
templates/metro.yml            2 clusters in AWS with a stretched Portworx cluster, configure Metro, a GUI and Petclinic, ready for a failover demo
templates/px-with-gui.yml      Cluster with Portworx, wait for it to be up, run a GUI with a Lighthouse Firefox tab
templates/px.yml               Cluster with Portworx
templates/training.yml         Deploy training clusters
```

Generate a list of IP address, suitable for training:
```
$ px-deploy status --name trainingDeployment
master-1 34.247.219.101 ec2-34-247-219-101.eu-west-1.compute.amazonaws.com
master-2 34.254.155.6 ec2-34-254-155-6.eu-west-1.compute.amazonaws.com
```

The `defaults.yml` file sets a number of deployment variables:
 * `aws_ebs` - a list of EBS volumes to be attached to each worker node. This is a space-separate list of type:size pairs, for example: `"gp2:30 standard:20"` will provision a gp2 volume of 30 GB and a standard volume of 20GB
 * `aws_region` - AWS region
 * `aws_type` - the AWS machine type for each node
 * `cloud` - the cloud on which to deploy (aws or gcp)
 * `clusters` - the number of clusters to deploy
 * `k8s_version` - the version of Kubernetes to deploy
 * `nodes` - the number of worker nodes on each cluster
 * `platform` - can be set to either k8s or ocp3
 * `px_version` - the version of Portworx to install
 * `gcp_disks` - similar to AWS_EBS, for example: `"pd-standard:20 pd-ssd:30"`
 * `gcp_region` - GCP region
 * `gcp_type` - the GCP machine type for each node
 * `gcp_zone` - GCP zone

There are two ways to override these variables. The first is to specify a template with the `--template=...` parameter. For example:
```
$ cat templates/clusterpair.yml
clusters: 2
scripts: ["install-px", "clusterpair"]
```

More on `scripts` below.

The second way to override the defaults is to specify on the command line. See `px-deploy create -h` for a full list. For example, to deploy petclinic into the `foo` deployment:
```
px-deploy create --name=foo --clusters=5 --template=petclinic --nodes=6
```

This example is a mixture of both methods. The template is applied, then the command line parameters are applied, so not only is the template overriding the defaults, but also the parameters are overriding the template.

`scripts` is a list of scripts to be executed on each master node. For example:
```
$ cat ~/.px-deploy/scripts/petclinic
# Install petclinic on each cluster
kubectl apply -f /assets/petclinic.yml
```

These variables are passed to the script:
 * `$nodes`
 * `$clusters`
 * `$px_version`
 * `$k8s_version`

All files in `~/.px-deploy/assets` will be copied to `/assets` on the master nodes. They are then available to be used by the script, as above.

In addition to these, there are some more variables available:
 * `$cluster` - cluster number

Last, environment variables can be define in templates, and these are also available to scripts:
```
$ cat templates/metro.yml
...
env:
  licenses: "XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX"
```
