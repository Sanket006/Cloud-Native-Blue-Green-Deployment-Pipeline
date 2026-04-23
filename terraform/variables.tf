variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "bg-devops-cluster"
}

variable "ecr_repo_name" {
  description = "Name of the ECR repository"
  type        = string
  default     = "bg-devops-demo-app"
}
