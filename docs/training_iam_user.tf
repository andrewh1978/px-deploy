# create a AWS iam user limited only to create px-deploy ec2 instances and access a defined S3 bucket
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
	description 	= "name of existing s3 bucket to be used by training users"
	type 		= string
	#default 	= "demo-bucket"
}

variable "training_user" {
  description = "name of limited AWS IAM user to be created for training account"
  type = string
  #default = "px-deploy-training"
}

resource "aws_iam_user" "aws-training-user" {
  name = var.training_user
  path = "/"
}

resource "aws_iam_user_policy" "training-user" {
  name = "px-deploy-training-policy"
  user = aws_iam_user.aws-training-user.name
  policy =  data.aws_iam_policy_document.training_user.json
}

data "aws_iam_policy_document" "training_user" {

    statement {
      effect = "Allow"
      actions = [
                "iam:CreateInstanceProfile",
                "iam:GetPolicyVersion",
                "iam:UntagRole",
                "iam:TagRole",
                "iam:RemoveRoleFromInstanceProfile",
                "iam:DeletePolicy",
                "iam:CreateRole",
                "iam:AttachRolePolicy",
                "iam:AddRoleToInstanceProfile",
                "iam:ListInstanceProfilesForRole",
                "iam:PassRole",
                "iam:DetachRolePolicy",
                "iam:ListAttachedRolePolicies",
                "iam:ListRolePolicies",
                "iam:ListAccessKeys",
                "iam:DeleteInstanceProfile",
                "iam:GetRole",
                "iam:GetInstanceProfile",
                "iam:GetPolicy",
                "iam:DeleteRole",
                "iam:TagPolicy",
                "iam:CreatePolicy",
                "iam:ListPolicyVersions",
                "iam:UntagPolicy",
                "iam:UntagInstanceProfile",
                "iam:TagInstanceProfile",
                "ec2:*",
                "elasticloadbalancing:*",
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

resource "aws_iam_access_key" "training-user" {
  user    = aws_iam_user.aws-training-user.name
}

output "aws_access_key_id" {
	value = aws_iam_access_key.training-user.id
}

output "aws_secret_access_key" {
	value = nonsensitive(aws_iam_access_key.training-user.secret)
}

