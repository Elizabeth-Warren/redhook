# Module to create firehose delivery streams

# Required
variable "name" { type = string }
variable "redshift_jdbcurl" { type = string }
variable "redshift_username" { type = string }
variable "redshift_password" { type = string }
variable "table_name" { type = string }
variable "alarm_sns_arn" { type = string }

# Optionals
variable "env" { default = "envunset" }
variable "buffer_size" { default = 1 }
variable "buffer_interval" { default = 60 }
variable "compression_format" { default = "GZIP" }
variable "copy_options" { default = "json 'auto' gzip" }
variable "tags" { default = {} }
variable "log_retention_days" { default = 30 }
variable "alarms_enabled" { default = true }
variable "s3_alarm_success_min" { default = 0.99 }
variable "s3_alarm_evaluation_periods" { default = 1 }
variable "redshift_alarm_success_min" { default = 0.99 }
variable "redshift_alarm_evaluation_periods" { default = 1 }
variable "redshift_retry_duration" { default = 3600 }

# Main
resource "aws_s3_bucket" "this" {
  bucket = "${var.env}.firehose.intermediate.${var.name}"
  acl    = "private"
  tags   = var.tags
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/${var.env}/kinesisfirehose/${var.name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

resource "aws_cloudwatch_log_stream" "s3" {
  name           = "S3Delivery"
  log_group_name = aws_cloudwatch_log_group.this.name
}

resource "aws_cloudwatch_log_stream" "s3_backup" {
  name           = "S3Backup"
  log_group_name = aws_cloudwatch_log_group.this.name
}

resource "aws_cloudwatch_log_stream" "redshift" {
  name           = "RedshiftDelivery"
  log_group_name = aws_cloudwatch_log_group.this.name
}

resource "aws_kinesis_firehose_delivery_stream" "this" {
  name        = "${var.env}-firehose-delivery-stream-${var.name}"
  destination = "redshift"
  tags        = var.tags

  s3_configuration {
    role_arn           = aws_iam_role.firehose.arn
    bucket_arn         = aws_s3_bucket.this.arn
    buffer_size        = var.buffer_size
    buffer_interval    = var.buffer_interval
    compression_format = var.compression_format

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = aws_cloudwatch_log_group.this.name
      log_stream_name = aws_cloudwatch_log_stream.s3.name
    }
  }

  redshift_configuration {
    role_arn        = aws_iam_role.firehose.arn
    cluster_jdbcurl = var.redshift_jdbcurl
    username        = var.redshift_username
    password        = var.redshift_password
    data_table_name = var.table_name
    copy_options    = var.copy_options
    retry_duration  = var.redshift_retry_duration
    s3_backup_mode  = "Enabled"

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = aws_cloudwatch_log_group.this.name
      log_stream_name = aws_cloudwatch_log_stream.redshift.name
    }

    s3_backup_configuration {
      role_arn           = aws_iam_role.firehose.arn
      bucket_arn         = aws_s3_bucket.this.arn
      buffer_size        = var.buffer_size
      buffer_interval    = var.buffer_interval
      compression_format = var.compression_format

      cloudwatch_logging_options {
        enabled         = true
        log_group_name  = aws_cloudwatch_log_group.this.name
        log_stream_name = aws_cloudwatch_log_stream.s3_backup.name
      }
    }
  }
}

# Alarms
# We can monitor successful delivery of records to S3 and Redshift. Cloudwatch
# alarms are, unfortunately, ill-suited to monitor incoming records for us since
# we won't generally get many (any?) overnight.
resource "aws_cloudwatch_metric_alarm" "s3_success" {
  count               = var.alarms_enabled ? 1 : 0
  alarm_name          = "${aws_kinesis_firehose_delivery_stream.this.name}-alarm-S3Success"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = var.s3_alarm_evaluation_periods
  metric_name         = "DeliveryToS3.Success"
  namespace           = "AWS/Firehose"
  period              = "60"
  statistic           = "Sum"
  threshold           = var.s3_alarm_success_min
  alarm_description   = "Firehose S3 Successful Delivery Alarm for ${aws_kinesis_firehose_delivery_stream.this.name} (<= ${var.s3_alarm_success_min * 100}% succeeded)"
  alarm_actions       = [var.alarm_sns_arn]
  #  ok_actions          = [var.alarm_sns_arn]
  tags = var.tags

  dimensions = {
    DeliveryStreamName = "${aws_kinesis_firehose_delivery_stream.this.name}"
  }
}

resource "aws_cloudwatch_metric_alarm" "redshift_success" {
  count               = var.alarms_enabled ? 1 : 0
  alarm_name          = "${aws_kinesis_firehose_delivery_stream.this.name}-alarm-RedshiftSuccess"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = var.redshift_alarm_evaluation_periods
  metric_name         = "DeliveryToRedshift.Success"
  namespace           = "AWS/Firehose"
  period              = "60"
  statistic           = "Sum"
  threshold           = var.redshift_alarm_success_min
  alarm_description   = "Firehose Redshift Successful Delivery Alarm for ${aws_kinesis_firehose_delivery_stream.this.name} (<= ${var.s3_alarm_success_min * 100}% succeeded)"
  alarm_actions       = [var.alarm_sns_arn]
  #  ok_actions          = [var.alarm_sns_arn]
  tags = var.tags

  dimensions = {
    DeliveryStreamName = aws_kinesis_firehose_delivery_stream.this.name
  }
}

# SSM Parameters
# We share configuration between Terraform and SLS using SSM parameters. If we need
# to add more please do, but the basic requirements here are to have
resource "aws_ssm_parameter" "firehose_name" {
  name  = "/${var.env}/kinesisfirehose/${var.name}/name"
  type  = "SecureString"
  value = aws_kinesis_firehose_delivery_stream.this.name
  tags  = var.tags
}

resource "aws_ssm_parameter" "firehose_arn" {
  name  = "/${var.env}/kinesisfirehose/${var.name}/arn"
  type  = "SecureString"
  value = aws_kinesis_firehose_delivery_stream.this.arn
  tags  = var.tags
}

resource "aws_ssm_parameter" "log_group" {
  name  = "/${var.env}/kinesisfirehose/${var.name}/log/group"
  type  = "SecureString"
  value = aws_cloudwatch_log_group.this.name
  tags  = var.tags
}

resource "aws_ssm_parameter" "s3_log_name" {
  name  = "/${var.env}/kinesisfirehose/${var.name}/log/s3/name"
  type  = "SecureString"
  value = aws_cloudwatch_log_stream.s3.name
  tags  = var.tags
}

resource "aws_ssm_parameter" "redshift_log_name" {
  name  = "/${var.env}/kinesisfirehose/${var.name}/log/redshift/name"
  type  = "SecureString"
  value = aws_cloudwatch_log_stream.redshift.name
  tags  = var.tags
}

# Outputs
# We can reference these in tf topologies that use this modules. Add more as required.
output "delivery_stream_name" {
  value = aws_kinesis_firehose_delivery_stream.this.name
}

output "delivery_stream_arn" {
  value = aws_kinesis_firehose_delivery_stream.this.arn
}

output "intermediary_bucket_arn" {
  value = aws_s3_bucket.this.arn
}

output "firehose_role_arn" {
  value = aws_iam_role.firehose.arn
}
