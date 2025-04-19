resource "aws_s3_bucket" "test_bucket" {
  bucket_prefix = "ai-terraform-qa-test-"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "test_bucket_versioning" {
  bucket = aws_s3_bucket.test_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

output "bucket_name" {
  value = aws_s3_bucket.test_bucket.id
  description = "Name of the created S3 bucket"
}