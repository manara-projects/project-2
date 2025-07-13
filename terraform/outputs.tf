output "function_name" {
  value = aws_lambda_function.resize_lambda_function.function_name
}

output "original_images_bucket_name" {
  value = aws_s3_bucket.original_images_bucket.bucket
}

output "resized_images_bucket_name" {
  value = aws_s3_bucket.resized_images_bucket.bucket
}

output "logs" {
  value = aws_cloudwatch_log_group.reszied_lambda_logs.name
}

output "api_gateway_id" {
  value = aws_api_gateway_rest_api.api_gateway.id
}