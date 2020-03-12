# Standup Firehoses for Redhook

# Entry Point
terraform {
  required_version = ">= 0.12.13"
  required_providers {
    aws = "2.44.0"
  }
}


# Provider
provider "aws" {
  profile = "default"
  region  = "us-east-1"
}


# In practice, these were all stored in SSM and fetched in terraform using the
# "data" facilities it provides. Because this is all privileged information, it's
# best to avoid stashing it in files unless you are quite confident in the security
# of your deploy machines.
locals {
  env               = "dev"
  redshift_dsn      = "redshift.com"
  redshift_username = "ew"
  redshift_password = "my-password"
  redshift_schema   = "redhook"
  json_table        = "json"
  basicauth_table   = "json_with_basic_auth"
  alarm_sns_arn     = "arn:aws:sns:us-east-1:<ACCOUNT ID>:houston-we-have-a-problem"
}


# Fake Deploy Bucket
resource "aws_s3_bucket" "deploys" {
  bucket = "${local.env}.deploys"
  acl    = "private"
}

resource "aws_ssm_parameter" "bucket_name" {
  name  = "/${local.env}/s3/deploys/bucket/name"
  value = aws_s3_bucket.deploys.id
  type  = "SecureString"
}

resource "aws_ssm_parameter" "bucket_arn" {
  name  = "/${local.env}/s3/deploys/bucket/arn"
  value = aws_s3_bucket.deploys.arn
  type  = "SecureString"
}


# Fake Alarms SNS Topic
resource "aws_sns_topic" "alarms" {
  name = "${local.env}-alarms"
}

resource "aws_ssm_parameter" "sns_topic_alarms_arn" {
  name  = "/${local.env}/sns/alarms/arn"
  type  = "SecureString"
  value = aws_sns_topic.alarms.arn
}

resource "aws_ssm_parameter" "sns_topic_alarms_name" {
  name  = "/${local.env}/sns/alarms/name"
  type  = "SecureString"
  value = aws_sns_topic.alarms.name
}


# Firehoses
module "redhook-json" {
  source            = "../modules/firehose-to-redshift"
  name              = "redhook-json"
  env               = local.env
  redshift_jdbcurl  = "jdbc:${local.redshift_dsn}"
  redshift_username = local.redshift_username
  redshift_password = local.redshift_password
  table_name        = local.json_table
  alarm_sns_arn     = aws_ssm_parameter.alarms.arn
}

module "redhook-json-with-basic-auth" {
  source            = "../modules/firehose-to-redshift"
  name              = "redhook-json-with-basic-auth"
  env               = local.env
  redshift_jdbcurl  = "jdbc:${local.redshift_dsn}"
  redshift_username = local.redshift_username
  redshift_password = local.redshift_password
  table_name        = local.json_with_basic_auth
  alarm_sns_arn     = aws_ssm_parameter.alarms.arn
}
