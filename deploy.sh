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

options=$(getopt -o dn --long platform:,cloud:,clusters:,nodes:,k8s_version:,px_version:,aws_type:,aws_ebs:,gcp_keyfile:,gcp_type:,gcp_disks:,template:,destroy -- "$@")
[ $? -eq 0 ] || { 
  echo "Incorrect options provided"
  exit 1
}
eval set -- "$options"
while true; do
  case "$1" in
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
    [ ! -e "$GCP_KEYFILE" ] && {
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
    [[ ! -e "templates/$DEP_TEMPLATE" ]] && {
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

[[ "$DEP_DEBUG" ]] && set | grep -E '^(DEP|AWS|GCP)'
[[ "$DEP_DRYRUN" ]] && exit

export $(set | grep -E '^(DEP|AWS|GCP)' | cut -f 1 -d = )

if [ "$DEP_DESTROY" ]; then
  vagrant destroy -fp
elif [ "$1" == down ]; then
  vagrant up
fi
