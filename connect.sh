[[ $DEP_CLOUD = "aws" ]] && ip=$(aws ec2 describe-instances --region eu-west-1 --filters "Name=network-interface.vpc-id,Values=$AWS_vpc" "Name=tag:Name,Values=master-1" "Name=instance-state-name,Values=running" --query Reservations[*].Instances[*].PublicIpAddress --output text)
[[ $DEP_CLOUD = "gcp" ]] && ip=$(gcloud compute instances list --project $GCP_PROJECT --filter="name=('master-1')" --format 'flattened(networkInterfaces[0].accessConfigs[0].natIP)' | tail -1 | cut -f 2 -d " ")
if [ "$ip" ]; then
  ssh -oStrictHostKeyChecking=no -i id_rsa root@$ip
else
  echo Cannot get IP >&2
fi
