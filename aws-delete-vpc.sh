. aws-env.sh

aws ec2 --region=$AWS_region delete-security-group --group-id $AWS_sg &&
aws ec2 --region=$AWS_region delete-subnet --subnet-id $AWS_subnet &&
aws ec2 --region=$AWS_region detach-internet-gateway --internet-gateway-id $AWS_gw --vpc-id $AWS_vpc &&
aws ec2 --region=$AWS_region delete-internet-gateway --internet-gateway-id $AWS_gw &&
aws ec2 --region=$AWS_region delete-route-table --route-table-id $AWS_routetable &&
aws ec2 --region=$AWS_region delete-vpc --vpc-id $AWS_vpc &&
rm aws-env.sh
