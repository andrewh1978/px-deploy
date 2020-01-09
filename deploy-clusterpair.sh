DEP_CLUSTERS=2
DEP_NODES=3
DEP_DISKSIZE=20
DEP_CLOUD=aws			# aws or gcp
DEP_PLATFORM=k8s		# k8s or openshift
DEP_K8S_VERSION=1.16.4
DEP_PX_VERSION=2.3.2
DEP_PX_CLUSTER_PREFIX=px-deploy
DEP_INSTALL="install-px clusterpair"

AWS_TYPE=t3.large
GCP_KEYFILE=./gcp-key.json
GCP_TYPE=n1-standard-2
GCP_DISKTYPE=pd-standard

export $(set | grep -E '^(DEP|AWS|GCP)' | cut -f 1 -d = )

if [ $1 == up ]; then
  vagrant up
elif [ $1 == down ]; then
  vagrant destroy -fp
else
  echo "Usage: $0 up | down"
fi
