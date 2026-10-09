output "artifacts_bucket_arn" {
  description = "ARN of the artifacts bucket."
  value       = module.artifacts.bucket_arn
}

output "artifacts_encryption" {
  description = "Effective encryption settings of the artifacts bucket."
  value       = module.artifacts.encryption
}
