resource "aws_ecr_repository" "app_repo" {
  name                 = var.ecr_repo_name
  image_tag_mutability = "MUTABLE"
  # force_delete allows terraform destroy to remove the repo even if it contains images
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}
