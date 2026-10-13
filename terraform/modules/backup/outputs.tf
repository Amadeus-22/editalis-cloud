output "backup_bucket" {
  value = aws_s3_bucket.backup.id
}

output "backup_bucket_arn" {
  value = aws_s3_bucket.backup.arn
}

output "logs_bucket" {
  value = aws_s3_bucket.logs.id
}

output "logs_bucket_arn" {
  value = aws_s3_bucket.logs.arn
}
