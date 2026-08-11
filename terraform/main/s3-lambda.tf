# --- Event-Driven Extension: S3 -> Lambda image processor (exam 4.5) ------

resource "aws_s3_bucket" "assets" {
  bucket = "bedrock-assets-alt-soe-tin-o25-0324"
}

# Exam requires Block Public Access enabled — all four settings, not just one.
resource "aws_s3_bucket_public_access_block" "assets" {
  bucket                  = aws_s3_bucket.assets.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Packages the Lambda code into a zip Terraform can deploy. Requires the
# `archive` provider — if it's not already declared in your
# provider.tf/versions.tf, add:
#   archive = { source = "hashicorp/archive", version = "~> 2.4" }
data "archive_file" "asset_processor" {
  type        = "zip"
  source_file = "${path.module}/lambda/asset_processor.py"
  output_path = "${path.module}/lambda/asset_processor.zip"
}

resource "aws_iam_role" "asset_processor" {
  name = "project-bedrock-asset-processor-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Scoped exactly to what the exam asks: read the uploaded object, write
# logs — nothing broader. No s3:ListBucket, no account-wide log access.
resource "aws_iam_role_policy" "asset_processor" {
  name = "project-bedrock-asset-processor-policy"
  role = aws_iam_role.asset_processor.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.assets.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = "arn:aws:logs:us-east-1:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/bedrock-asset-processor:*"
      }
    ]
  })
}

resource "aws_lambda_function" "asset_processor" {
  function_name    = "bedrock-asset-processor"
  role             = aws_iam_role.asset_processor.arn
  handler          = "asset_processor.handler"
  runtime          = "python3.13"
  filename         = data.archive_file.asset_processor.output_path
  source_code_hash = data.archive_file.asset_processor.output_base64sha256
  timeout          = 10
}

# Explicit permission for S3 to invoke this specific function from this
# specific bucket only — without this, the notification silently no-ops.
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.asset_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.assets.arn
}

resource "aws_s3_bucket_notification" "assets" {
  bucket = aws_s3_bucket.assets.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.asset_processor.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_s3]
}

# Exam note (4.5): "bedrock-dev-view has been granted s3:PutObject on this
# bucket" — the grader uploads a test file using these credentials.
resource "aws_iam_user_policy" "bedrock_dev_view_s3_put" {
  name = "s3-put-assets-bucket-only"
  user = aws_iam_user.bedrock_dev_view.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "s3:PutObject"
      Resource = "${aws_s3_bucket.assets.arn}/*"
    }]
  })
}
