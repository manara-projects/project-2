provider "aws" {
  region = var.region
}

locals {
  common_tags = {
    Terraform   = "true"
    Managed_by  = "terraform"
    Environment = var.env
  }
}

data "aws_iam_policy_document" "resize_lambda_permission" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_policy" "resize_lambda_policy" {
  name = "resizedLambdaPolicy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
        ]
        Effect   = "Allow"
        Resource = "${aws_s3_bucket.original_images_bucket.arn}/*"
      },
      {
        Action = [
          "s3:PutObject"
        ]
        Effect   = "Allow"
        Resource = "${aws_s3_bucket.resized_images_bucket.arn}/*"
      }
    ]
  })
}

resource "aws_iam_role" "resize_lambda_role" {
  name               = "resizeLambdaRole"
  assume_role_policy = data.aws_iam_policy_document.resize_lambda_permission.json
}

resource "aws_iam_role_policy_attachment" "resize_lambda_allow_s3_attachment" {
  role       = aws_iam_role.resize_lambda_role.name
  policy_arn = aws_iam_policy.resize_lambda_policy.arn
}

resource "aws_iam_role_policy_attachment" "resize_lambda_allow_cloudwatch_attachment" {
  role       = aws_iam_role.resize_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "archive_file" "lambda_src" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/function.zip"
}

resource "null_resource" "install_pillow" {
  provisioner "local-exec" {
    working_dir = "${path.module}/python/"
    interpreter = ["/bin/bash", "-c"]
    command     = <<EOF
      mkdir -p python
      pip install pillow -t python
    EOF
  }
}

data "archive_file" "lambda_layer" {
  type        = "zip"
  source_dir  = "${path.module}/python"
  output_path = "${path.module}/layer.zip"

  depends_on = [
    null_resource.install_pillow
  ]
}

resource "aws_lambda_layer_version" "lambda_pillow_layer" {
  filename   = data.archive_file.lambda_layer.output_path
  layer_name = "lambdaPillowLayer"

  compatible_runtimes = ["python3.10"]
}

resource "aws_lambda_function" "resize_lambda_function" {
  filename         = data.archive_file.lambda_src.output_path
  function_name    = "resizeLambdaFunction"
  role             = aws_iam_role.resize_lambda_role.arn
  handler          = "index.lambda_handler"
  source_code_hash = data.archive_file.lambda_src.output_base64sha256

  runtime = "python3.10"

  layers = [
    aws_lambda_layer_version.lambda_pillow_layer.arn
  ]

  tags = merge(local.common_tags, {
    Name    = "ResizeLambdaFunction"
    Runtime = "Python"
  })
}

resource "aws_s3_bucket" "original_images_bucket" {
  bucket = var.bucket_1_name

  tags = merge(local.common_tags, {
    Name = "OriginalImageBucket"
  })
}

resource "aws_s3_bucket" "resized_images_bucket" {
  bucket = var.bucket_2_name

  tags = merge(local.common_tags, {
    Name = "ResizedImageBucket"
  })
}

resource "aws_lambda_permission" "resize_lambda_permission" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.resize_lambda_function.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.original_images_bucket.arn
}

resource "aws_s3_bucket_notification" "resize_lambda_notification" {
  bucket = aws_s3_bucket.original_images_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.resize_lambda_function.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.resize_lambda_permission]
}

resource "aws_cloudwatch_log_group" "reszied_lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.resize_lambda_function.function_name}"
  retention_in_days = 30

  tags = local.common_tags
}
