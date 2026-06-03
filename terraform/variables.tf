variable "aws_region" {
  description = "AWS region where all resources will be created (e.g. us-east-1)"
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]{1}$", var.aws_region))
    error_message = "Please provide a valid AWS region name (e.g. us-east-1, eu-west-2)."
  }
}

variable "cluster_name" {
  description = "Name used for the EKS cluster and as a prefix for related resources (VPC, node groups)"
  type        = string
  default     = "bg-devops-cluster"

  validation {
    condition     = length(var.cluster_name) <= 40 && can(regex("^[a-zA-Z][a-zA-Z0-9-]*$", var.cluster_name))
    error_message = "Cluster name must start with a letter, contain only alphanumeric characters and hyphens, and be 40 characters or fewer."
  }
}

variable "ecr_repo_name" {
  description = "Name for the Elastic Container Registry (ECR) repository that stores your Docker images"
  type        = string
  default     = "bg-devops-demo-app"
}
