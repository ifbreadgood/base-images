output "deployed_environment" {
  value = resource.terraform_data.deployment_environment.output
}

output "credential_token" {
  value     = var.api_secret_token
  sensitive = true
  ephemeral = true
}
