# Set the AWS region
AWS_region=eu-west-1
AWS_keypair=ah
AWS_sshkey_path=$HOME/.ssh/id_rsa

# Do not change below this line
AWS_vpc=$(aws --region=$AWS_region --output text ec2 create-vpc --cidr-block 192.168.0.0/16 --query Vpc.VpcId)
AWS_subnet=$(aws --region=$AWS_region --output text ec2 create-subnet --vpc-id $AWS_vpc --cidr-block 192.168.0.0/16 --query Subnet.SubnetId)
AWS_gw=$(aws --region=$AWS_region --output text ec2 create-internet-gateway --query InternetGateway.InternetGatewayId)
aws --region=$AWS_region ec2 attach-internet-gateway --vpc-id $AWS_vpc --internet-gateway-id $AWS_gw
AWS_routetable=$(aws --region=$AWS_region --output text ec2 create-route-table --vpc-id $AWS_vpc --query RouteTable.RouteTableId)
aws --region=$AWS_region ec2 create-route --route-table-id $AWS_routetable --destination-cidr-block 0.0.0.0/0 --gateway-id $AWS_gw >/dev/null
aws --region=$AWS_region ec2 associate-route-table  --subnet-id $AWS_subnet --route-table-id $AWS_routetable >/dev/null
AWS_sg=$(aws --region=$AWS_region --output text ec2 create-security-group --group-name px-cloud --description "Security group for px-cloud" --vpc-id $AWS_vpc --query GroupId)
aws --region=$AWS_region ec2 authorize-security-group-ingress --group-id $AWS_sg --protocol tcp --port 22 --cidr 0.0.0.0/0
aws --region=$AWS_region ec2 authorize-security-group-ingress --group-id $AWS_sg --protocol tcp --port 443 --cidr 0.0.0.0/0
aws --region=$AWS_region ec2 authorize-security-group-ingress --group-id $AWS_sg --protocol tcp --port 8080 --cidr 0.0.0.0/0
aws --region=$AWS_region ec2 authorize-security-group-ingress --group-id $AWS_sg --protocol tcp --port 30000-32767 --cidr 0.0.0.0/0
aws --region=$AWS_region ec2 authorize-security-group-ingress --group-id $AWS_sg --protocol all --cidr 192.168.0.0/16

AWS_ami=$(aws --region=$AWS_region --output text ec2 describe-images --owners 679593333241 --filters Name=name,Values='CentOS Linux 7 x86_64 HVM EBS*' Name=architecture,Values=x86_64 Name=root-device-type,Values=ebs --query 'sort_by(Images, &Name)[-1].ImageId')

cat <<EOF >aws-env.sh
AWS_keypair=$AWS_keypair
AWS_vpc=$AWS_vpc
AWS_subnet=$AWS_subnet
AWS_gw=$AWS_gw
AWS_routetable=$AWS_routetable
AWS_sg=$AWS_sg
AWS_ami=$AWS_ami
AWS_region=$AWS_region
AWS_sshkey_path=$AWS_sshkey_path
export \$(set | grep ^AWS | cut -f 1 -d = )
EOF
