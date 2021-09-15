#!/bin/bash

# write a k8s secret with api server, token and ca for the current cluster
# this will always create the secret on master-1 regardless of which cluster this script is running

# the name of our cluster-admin service account
SERVICEACCOUNT=${SERVICEACCOUNT:="healthportal"}
# the namespace we will create our cluster-admin service-account
SERVICEACCOUNT_NAMESPACE=${SERVICEACCOUNT_NAMESPACE:="default"}
# the namespace we will run our app
APP_NAMESPACE=${APP_NAMESPACE:="healthportal"}
# the name of the secret we write our credentials to
CREDENTIALS_SECRET_NAME=${CREDENTIALS_SECRET_NAME:="clusters"}

# shortcut to run kubectl on master1
# this will work even if we are on master1 so we use it whenever we
# want to operate on the healthportal app itself (which always runs on cluster1)
function master1_kubectl() {
  ssh -oConnectTimeout=1 -oStrictHostKeyChecking=no master-1 kubectl $@
}

# kubectl command run inside the healthportal app namespace
function app_kubectl() {
  master1_kubectl -n $APP_NAMESPACE $@
}

# ensure the healthportal app namespace exists on master1
function ensure_app_namespace() {
  EXISTING_APP_NAMESPACE=$(master1_kubectl get ns | grep "$APP_NAMESPACE")
  if [ -z "$EXISTING_APP_NAMESPACE" ]; then
    >&2 echo "creating app namespace $APP_NAMESPACE"
    master1_kubectl create ns $APP_NAMESPACE
  fi
}

# ensure the healthportal app cluster secrets exists on master1
# we don't fill any values in, just ensure the secret exists
# so that each cluster script can patch it's own values into the secret
# the healthportal api will mount all values from the secret
# and then internally use the presense of `CLUSTER_CREDENTIALS_1` and `CLUSTER_CREDENTIALS_2`
# to decide how many clusters we are running
# the idea is that we can run the healthapp on a single cluster or multiple cluster
# and the api is driven by the presense of `CLUSTER_CREDENTIALS_${X}` in the one secret
function ensure_app_secrets() {
  EXISTING_SECRET=$(app_kubectl get secret | grep "$CREDENTIALS_SECRET_NAME")
  if [ -z "$EXISTING_SECRET" ]; then
    >&2 echo "creating app secret $CREDENTIALS_SECRET_NAME"
    app_kubectl create secret generic $CREDENTIALS_SECRET_NAME
  fi
}

function ensure_app() {
  ensure_app_namespace
  ensure_app_secrets
}

# patch the value of a cluster's credentials into the app secret
function write_cluster_secret() {
  local value="$1"
  app_kubectl patch secret $CREDENTIALS_SECRET_NAME -p="{\\\"data\\\":{\\\"CLUSTER_CREDENTIALS_${cluster}\\\":\\\"${value}\\\"}}"
}

function ensure_service_account() {
  # do we already have the service account namespace?
  EXISTING_SERVICE_ACCOUNT_NAMESPACE=$(kubectl get ns | grep "$SERVICEACCOUNT_NAMESPACE")

  if [ -z "$EXISTING_SERVICE_ACCOUNT_NAMESPACE" ]; then
    kubectl create ns $SERVICEACCOUNT_NAMESPACE
  fi

  # do we already have the service account?
  EXISTING_SERVICE_ACCOUNT=$(kubectl -n $SERVICEACCOUNT_NAMESPACE get serviceaccount | grep $SERVICEACCOUNT)

  if [ -z "$EXISTING_SERVICE_ACCOUNT" ]; then
    # create the service account:
    echo "creating serviceaccount: $SERVICEACCOUNT in namespace $SERVICEACCOUNT_NAMESPACE"
    kubectl create -n $SERVICEACCOUNT_NAMESPACE serviceaccount $SERVICEACCOUNT

    # get the RBAC api versions
    RBAC_API_VERSIONS=$(kubectl api-versions | grep rbac)

    # If RBAC is enabled - assign cluster-admin role to service account:
    if [ -n "$RBAC_API_VERSIONS" ]; then
      echo "creating clusterrolebinding: $SERVICEACCOUNT in namespace $NAMESPACE"
      kubectl create -n $SERVICEACCOUNT_NAMESPACE clusterrolebinding $SERVICEACCOUNT \
        --clusterrole=cluster-admin \
        --serviceaccount=$SERVICEACCOUNT_NAMESPACE:$SERVICEACCOUNT
    fi
  fi
}

# print a JSON object with everything the health-portal api server needs
# to connect to the k8s and ssh onto this cluster
function get_credentials() {
  # get the secret name for the service account:
  >&2 echo "getting the secret name for serviceaccount: $SERVICEACCOUNT in namespace $SERVICEACCOUNT_NAMESPACE"
  SECRETNAME=$(kubectl get -n $SERVICEACCOUNT_NAMESPACE serviceaccounts $SERVICEACCOUNT -o "jsonpath={..secrets[0].name}")

  # get the base64 bearer token:
  >&2 echo "getting the bearer token for serviceaccount: $SERVICEACCOUNT in namespace $SERVICEACCOUNT_NAMESPACE"
  BASE64_BEARER_TOKEN=$(kubectl get secret -n $SERVICEACCOUNT_NAMESPACE $SECRETNAME -o "jsonpath={..data.token}")

  # get the base64 CA:
  >&2 echo "getting the certificate authority for serviceaccount: $SERVICEACCOUNT in namespace $SERVICEACCOUNT_NAMESPACE"
  BASE64_CA_FILE=$(kubectl get secret -n $SERVICEACCOUNT_NAMESPACE $SECRETNAME -o "jsonpath={..data['ca\.crt']}")

  # get the api server address:
  >&2 echo "getting the api server address"
  APISERVER=$(kubectl config view --minify -o jsonpath='{..clusters[0].cluster.server}')

  PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
  PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
  PRIVATE_KEY=$(cat /root/.ssh/id_rsa | base64 -w 0)

  # now we have the values - we want to add them to the secret on master-1
  cat << EOF
  {
    "apiServer": "$APISERVER",
    "publicIp": "$PUBLIC_IP",
    "privateIp": "$PRIVATE_IP",
    "base64_token": "$BASE64_BEARER_TOKEN",
    "base64_ca": "$BASE64_CA_FILE",
    "base64_privateKey": "$PRIVATE_KEY"
  }
EOF
}

function install_cluster() {
  if [ -z "$cluster" ]; then
    >&2 echo "cluster variable not defined"
    exit 1
  fi
  ensure_app
  ensure_service_account
  credentials=$(get_credentials | base64 -w 0)
  write_cluster_secret "$credentials"
}

function install_health_portal() {
  echo "installing health portal"
  export scenarios=${scenarios:="all"}
  cat /assets/health-portal/deployment.yaml | envsubst | kubectl apply -f -
}

function install_autopilot() {
  echo "installing autopilot"
  kubectl apply -f /assets/monitoring/prometheus-operator.yaml
  kubectl wait --for=condition=ready pod -l app=prometheus-operator -n kube-system --timeout 5m
  while : ; do
    n=$(kubectl exec -n kube-system -it $(kubectl get pods -n kube-system -lname=portworx --field-selector=status.phase=Running | tail -1 | cut -f 1 -d " ") -- /opt/pwx/bin/pxctl status 2>/dev/null | grep "Yes.*Online.*Up" | wc -l)
    [ $n -eq $nodes ] && break
    sleep 1
  done
  sleep 5

  # Fix because we don't seem to support the latest prometheus operator!
  kubectl apply -f /assets/monitoring/prometheus-cluster.yaml
  kubectl apply -f /assets/monitoring/service-monitor.yaml
  sleep 10

  # Wait for AutoPilot to be available before we apply rules
  kubectl wait --for=condition=ready pod -l name=autopilot -n kube-system --timeout 10m
  kubectl apply -f /assets/monitoring/prometheus-rules.yaml
  kubectl patch svc grafana -n kube-system -p '{"spec": { "type": "NodePort", "ports": [ { "nodePort": 30112, "port": 3000, "protocol": "TCP", "targetPort": 3000 } ] } }'
}

function install_backups() {
  echo "installing backups"
  kubectl apply -f /assets/minio/minio-deployment.yml
  ip=`curl -s https://ipinfo.io/ip`
  sed -i -e 's/xxxx/'"$ip"'/g' /assets/backup-restore/backupLocation.yml
  kubectl wait --for=condition=ready pod -l app=minio -n minio --timeout 30m
  docker run --rm -v /etc/hosts:/etc/hosts -e AWS_ACCESS_KEY_ID=minio -e AWS_SECRET_ACCESS_KEY=minio123 amazon/aws-cli --endpoint-url http://node-$cluster-1:30221 s3 mb s3://portworx
}

function url_summary() {
  echo ""
  echo "-------------------------------------------------------"
  echo ""
  echo "Health portal stack can be viewed at the following urls:"
  echo ""
  echo "-------------------------------------------------------"
  echo ""
  EC2_AVAIL_ZONE=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone`
  EC2_REGION="`echo \"$EC2_AVAIL_ZONE\" | sed 's/[a-z]$//'`"
  instance_id=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
  ip=$(aws ec2 describe-instances --region $EC2_REGION --instance-id $instance_id --query Reservations[].Instances[].PublicIpAddress --output text)  
  echo "Health Portal:"
  echo "http://$ip:32384"
  echo ""
  echo "-------------------------------------------------------"
}

function install_app() {
  if [ -z "$cluster" ]; then
    >&2 echo "cluster variable not defined"
    exit 1
  fi
  if [[ "$cluster" != "1" ]]; then
    exit 0
  fi
  install_health_portal
  url_summary
}

eval "$@"