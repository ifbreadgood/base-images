terraform {
  required_version = ">= 1.16.0"
}

resource "terraform_data" "deployment_environment" {
  input = local.environment_identifier

  lifecycle {
    create_before_destroy = true
  }
}
