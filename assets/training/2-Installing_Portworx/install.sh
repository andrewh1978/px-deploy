VERSION=2.8
CLUSTER_NAME=px-demo

kubectl apply -f "https://install.portworx.com/$VERSION?comp=pxoperator"
kubectl wait --for=condition=ready pod -lname=portworx-operator -n kube-system
kubectl apply -f "https://install.portworx.com/$VERSION?operator=true&mc=false&kbver=&b=true&c=$CLUSTER_NAME&stork=true&csi=true&mon=true&st=k8s&promop=true"
