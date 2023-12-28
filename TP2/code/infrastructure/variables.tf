variable "AWS_ACCESS_KEY" {
  description = "Access key to AWS console"
}

variable "AWS_SECRET_ACCESS_KEY" {
  description = "Secret key to AWS console"
}

variable "AWS_SESSION_TOKEN" {
  description = "Session token to AWS console"
}

variable "key_pair_name" {
  description = "Key pair name for the orchestrator and worker instances"
  default     = "key_pair_Test"
}

