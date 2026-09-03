output "terraform_state_bucket_name" {
  description = "Nome do bucket S3 usado pelo backend do Terraform."
  value       = aws_s3_bucket.terraform_state.bucket
}
