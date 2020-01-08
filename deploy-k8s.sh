PX_CLUSTERS=1
PX_NODES=3
PX_DISKSIZE=20
PX_CLUSTERNAME=px-test-cluster
PX_CLOUD=aws				# aws or gcp
PX_PLATFORM=k8s				# k8s or openshift
PX_K8S_VERSION=1.16.4

AWS_TYPE=t3.large
GCP_KEYFILE=./gcp-key.json
GCP_TYPE=n1-standard-2
GCP_DISKTYPE=pd-standard

export $(set | grep -E '^(PX|AWS|GCP)' | cut -f 1 -d = )

if [ $1 == up ]; then
  vagrant up
elif [ $1 == down ]; then
  vagrant destroy -fp
else
  echo "Usage: $0 up | down"
fi
