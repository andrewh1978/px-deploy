#!/bin/bash

DEP_PLATFORM=k8s
DEP_CLOUD=aws
DEP_CLUSTERS=1
DEP_NODES=3
DEP_K8S_VERSION=1.16.4
DEP_PX_VERSION=2.3.2

AWS_TYPE=t3.large
AWS_EBS="gp2:20"
GCP_KEYFILE=./gcp-key.json
GCP_TYPE=n1-standard-2
GCP_DISKS="pd-standard:20 pd-ssd:30"

options=$(getopt -o dnh --long platform:,cloud:,clusters:,nodes:,k8s_version:,px_version:,aws_type:,aws_ebs:,gcp_keyfile:,gcp_type:,gcp_disks:,template:,destroy -- "$@")
[ $? -eq 0 ] || { 
  echo "Incorrect options provided"
  exit 1
}
eval set -- "$options"
while true; do
  case "$1" in
  -h)
    DEP_HELP=1
    break
    ;;
  -d)
    DEP_DEBUG=1
    ;;
  -n)
    DEP_DRYRUN=1
    ;;
  --destroy)
    DEP_DESTROY=1
    ;;
  --platform)
    shift;
    DEP_PLATFORM=$1
    [[ ! $DEP_PLATFORM =~ ^k8s|openshift$ ]] && {
      echo "Bad platform"
      exit 1
    }
    ;;
  --cloud)
    shift;
    DEP_CLOUD=$1
    [[ ! $DEP_CLOUD =~ ^aws|gcp$ ]] && {
      echo "Bad cloud"
      exit 1
    }
    ;;
  --clusters)
    shift;
    DEP_CLUSTERS=$1
    [[ ! $DEP_CLUSTERS =~ ^[0-9]+$ ]] && {
      echo "Bad clusters"
      exit 1
    }
    ;;
  --nodes)
    shift;
    DEP_NODES=$1
    [[ ! $DEP_NODES =~ ^[0-9]+$ ]] && {
      echo "Bad nodes"
      exit 1
    }
    ;;
  --k8s_version)
    shift;
    DEP_K8S_VERSION=$1
    [[ ! $DEP_K8S_VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] && {
      echo "Bad Kubernetes version"
      exit 1
    }
    ;;
  --px_version)
    shift;
    DEP_PX_VERSION=$1
    [[ ! $DEP_PX_VERSION =~ ^[0-9\.]+$ ]] && {
      echo "Bad Portworx version"
      exit 1
    }
    ;;
  --aws_type)
    shift;
    AWS_TYPE=$1
    [[ ! $AWS_TYPE =~ ^[0-9a-z\.]+$ ]] && {
      echo "Bad AWS type"
      exit 1
    }
    ;;
  --aws_ebs)
    shift;
    AWS_EBS=$1
    [[ ! $AWS_EBS =~ ^[0-9a-z\ :]+$ ]] && {
      echo "Bad AWS EBS volumes"
      exit 1
    }
    ;;
  --gcp_keyfile)
    shift;
    GCP_KEYFILE=$1
    [ ! -f "$GCP_KEYFILE" ] && {
      echo "Bad GCP keyfile"
      exit 1
    }
    ;;
  --gcp_type)
    shift;
    GCP_TYPE=$1
    [[ ! $GCP_TYPE =~ ^[0-9a-z\-]+$ ]] && {
      echo "Bad GCP type"
      exit 1
    }
    ;;
  --gcp_disks)
    shift;
    GCP_DISKS=$1
    [[ ! $GCP_DISKS =~ ^[0-9a-z\ :\-]+$ ]] && {
      echo "Bad GCP disks"
      exit 1
    }
    ;;
  --template)
    shift;
    DEP_TEMPLATE=$1
    [[ ! -f "templates/$DEP_TEMPLATE" ]] && {
      echo "Bad template"
      exit 1
    }
    ;;
  --)
    shift
    break
    ;;
  esac
  shift
done

[[ "$DEP_HELP" ]] && {
  cat <<EOF
usage: $0 [ options ]
  -h				print this usage and exit
  -d				debug - dump environmemnt
  -n				dryrun - do not deploy or destroy
  --destroy			destroy VMs
  --platform=k8s|openshift	deploy Kubernetes or Openshift 3.11 (default $DEP_PLATFORM)
  --cloud=aws|gcp		deploy on AWS or Google Cloud (default $DEP_CLOUD)
  --clusters=num		number of clusters to deploy (default $DEP_CLUSTERS)
  --nodes=num			number of worker nodes in each cluster (default $DEP_NODES)
  --k8s_version=x.y.z		Kubernetes version to install (default $DEP_K8S_VERSION)
  --px_version=x.y.z		Portworx version to install (default $DEP_PX_VERSION)
  --aws_type=text		AWS instance type (default $AWS_TYPE)
  --aws_ebs="type:size ..."	AWS EBS volumes to be attached to each worker node (default "$AWS_EBS")
  --gcp_keyfile=file		path to JSON for GCP key (default $GCP_KEYFILE)
  --gcp_type=text		GCP instance type (default $GCP_TYPE)
  --gcp_disks="type: size..."	GCP disk volimes to be attached to each worker node (default "$GCP_DISKS")
  --template=name		name of template to deploy
Examples:
  Deploy a single K8s cluster on AWS:
    $0

  Deploy a single clusterpair on Openshift and GCP:
    $0 --template=clusterpair --cloud=gcp --platform=openshift

  Deploy 3 Portworx clusters of 5 nodes on AWS:
    $0 --template=px --clusters=3 --nodes=5
EOF
  exit
}

[[ $DEP_TEMPLATE ]] && . templates/$DEP_TEMPLATE

[[ "$DEP_DEBUG" ]] && set | grep -E '^(DEP|AWS|GCP)' | sort
[[ "$DEP_DRYRUN" ]] && exit

export $(set | grep -E '^(DEP|AWS|GCP)' | cut -f 1 -d = )

if [ "$DEP_DESTROY" ]; then
  vagrant destroy -fp
else
  vagrant up
fi
