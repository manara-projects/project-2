variable "env" {
  type        = string
  description = "The Environment type where the resources will be deployed"
}

variable "region" {
  type        = string
  description = "AWS Region where the provider will operate"
  default     = "us-east-1"
}

variable "bucket_1_name" {
  type        = string
  description = "The name of Bucket 1 (Stores Original Images)"
}

variable "bucket_2_name" {
  type        = string
  description = "The name of Bucket 2 (Stores Resized Images)"
}