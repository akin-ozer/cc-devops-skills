# Output value declarations

output "project_name" {
  description = "The name of the project"
  value       = var.project_name
}

output "environment" {
  description = "The environment this infrastructure is deployed to"
  value       = var.environment
}
