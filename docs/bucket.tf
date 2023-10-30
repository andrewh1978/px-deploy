# create a AWS iam user limited only to access the given (existing) S3 bucket
# name of bucket must be set in variable s3_bucket (comment out OR create .tfvars OR provide interactively on terraform runtime)
# you may also modify aws_region
#
# HOWTO:
#
# terraform init
# terraform plan
# terraform apply
#
# note the output!
# destroy after training:
# terraform destroy

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
}
}

provider "aws" {
	region 	= var.aws_region
}

variable "aws_region" {
	description 	= "AWS region e.g: eu-west-1"
	type		= string
	default 	= "eu-west-1"
}

variable "s3_bucket" {
	description 	= "name of existing s3 bucket"
	type 		= string
#	default 	= "trainig-bucket"
}

resource "aws_iam_user" "aws-s3-user" {
  name = format("px-s3-%s",var.s3_bucket)
  path = "/"
}

resource "aws_iam_user_policy" "s3-user" {
  name = "s3-pol"
  user = aws_iam_user.aws-s3-user.name
  policy =  data.aws_iam_policy_document.s3_user.json
}

data "aws_iam_policy_document" "s3_user" {
    statement { 
      effect = "Allow"
      actions = [ 
                 "s3:ListAllMyBuckets",
                 "s3:GetBucketLocation"
                 ]
      resources = ["*"]
    }

   statement {
        effect = "Allow"
        actions = ["s3:*"]
        resources = [
		format("arn:aws:s3:::%s",var.s3_bucket),
                format("arn:aws:s3:::%s/*",var.s3_bucket)
                ]
   }
}

resource "aws_iam_access_key" "s3-user" {
  user    = aws_iam_user.aws-s3-user.name
}

output "aws_access_key_id" {
	value = aws_iam_access_key.s3-user.id
}


output "aws_secret_access_key" {
	value = nonsensitive(aws_iam_access_key.s3-user.secret)

}

