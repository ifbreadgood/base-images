variable "environment_type" {
  type    = string
  default = "production"

  validation {
    condition     = contains(["development", "staging", "production"], var.environment_type)
    error_message = "The environment_type variable must be one of: development, staging, production."
  }
}

variable "api_secret_token" {
  type      = string
  default   = "example-token-placeholder"
  sensitive = true
  ephemeral = true

  validation {
    condition     = length(var.api_secret_token) >= 8
    error_message = "The api_secret_token must be at least 8 characters in length."
  }
}
