# IAM Setup for Firehose

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "main" {
  statement {
    effect = "Allow"
    actions = [
      "glue:GetTable",
      "glue:GetTableVersion",
      "glue:GetTableVersions"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:AbortMultipartUpload",
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
      "s3:PutObject"
    ]
    resources = [
      aws_s3_bucket.this.arn,
      "${aws_s3_bucket.this.arn}/*",
      "arn:aws:s3:::%FIREHOSE_BUCKET_NAME%",
      "arn:aws:s3:::%FIREHOSE_BUCKET_NAME%/*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "lambda:InvokeFunction",
      "lambda:GetFunctionConfiguration"
    ]
    resources = [
      for arn in [var.processing_fn_qualified_arn, "arn:aws:lambda:us-east-1:${data.aws_caller_identity.current.account_id}:function:%FIREHOSE_DEFAULT_FUNCTION%:%FIREHOSE_DEFAULT_VERSION%"] :
      arn
      if arn != "DISABLED"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:AbortMultipartUpload",
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
      "s3:PutObject"
    ]
    resources = [
      aws_s3_bucket.this.arn,
      "${aws_s3_bucket.this.arn}/*",
      "arn:aws:s3:::%FIREHOSE_BUCKET_NAME%",
      "arn:aws:s3:::%FIREHOSE_BUCKET_NAME%/*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "kinesis:DescribeStream",
      "kinesis:GetShardIterator",
      "kinesis:GetRecords"
    ]
    resources = [
      "arn:aws:kinesis:us-east-1:${data.aws_caller_identity.current.account_id}:stream/%FIREHOSE_STREAM_NAME%"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:us-east-1:${data.aws_caller_identity.current.account_id}:log-group:${aws_cloudwatch_log_group.this.name}:log-stream:*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "kms:Decrypt"
    ]
    resources = [
      "arn:aws:kms:us-east-1:${data.aws_caller_identity.current.account_id}:key/%SSE_KEY_ID%"
    ]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values = [
        "kinesis.%REGION_NAME%.amazonaws.com"
      ]
    }

    condition {
      test     = "StringLike"
      variable = "kms:EncryptionContext:aws:kinesis:arn"
      values = [
        "arn:aws:kinesis:%REGION_NAME%:${data.aws_caller_identity.current.account_id}:stream/%FIREHOSE_STREAM_NAME%"
      ]
    }
  }
}

data "aws_iam_policy_document" "assumptions" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["firehose.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "firehose" {
  name               = "${var.env}-firehose-role-${var.name}"
  assume_role_policy = data.aws_iam_policy_document.assumptions.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "main" {
  name   = "${var.env}-firehose-role-policy-${var.name}"
  role   = aws_iam_role.firehose.name
  policy = data.aws_iam_policy_document.main.json
}
