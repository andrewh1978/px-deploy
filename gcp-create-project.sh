# Set the GCP region and project name
GCP_REGION=europe-west1
GCP_PROJECT=pxtest-1231234
GCP_owner_tag=CHANGEME

# Do not change below this line
gcloud projects create $GCP_PROJECT
account=$(gcloud alpha billing accounts list | tail -1 | cut -f 1 -d " ")
gcloud alpha billing projects link $GCP_PROJECT --billing-account $account
gcloud services enable compute.googleapis.com --project $GCP_PROJECT
gcloud compute networks create px-net --project $GCP_PROJECT
gcloud compute networks subnets create --range 192.168.0.0/16 --network px-net px-subnet --region $GCP_REGION --project $GCP_PROJECT
gcloud compute firewall-rules create allow-tcp --allow=tcp --source-ranges=192.168.0.0/16 --network px-net --project $GCP_PROJECT
gcloud compute firewall-rules create allow-udp --allow=udp --source-ranges=192.168.0.0/16 --network px-net --project $GCP_PROJECT
gcloud compute firewall-rules create allow-icmp --allow=icmp --source-ranges=192.168.0.0/16 --network px-net --project $GCP_PROJECT
gcloud compute firewall-rules create allow-ssh --allow=tcp:22 --network px-net --project $GCP_PROJECT
gcloud compute firewall-rules create allow-https --allow=tcp:443 --network px-net --project $GCP_PROJECT
gcloud compute firewall-rules create allow-k8s --allow=tcp:6443 --network px-net --project $GCP_PROJECT
gcloud compute project-info add-metadata --metadata "ssh-keys=$USER:$(cat $HOME/.ssh/id_rsa.pub)" --project $GCP_PROJECT

cat <<EOF >gcp-env.sh
GCP_PROJECT=$GCP_PROJECT
GCP_REGION=$GCP_REGION
GCP_owner_tag=$GCP_owner_tag
export GCP_PROJECT GCP_REGION GCP_owner_tag
EOF
