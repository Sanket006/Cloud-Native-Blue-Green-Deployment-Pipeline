module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.30"  # See https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html for latest supported versions

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets

  cluster_endpoint_public_access = true

  # SECURITY: Restrict API server access to your IP address only.
  # Replace YOUR_IP with your actual public IP (find it at https://checkip.amazonaws.com).
  # Remove or comment this out if you need access from multiple locations.
  # cluster_endpoint_public_access_cidrs = ["YOUR_IP/32"]

  enable_cluster_creator_admin_permissions = true

  eks_managed_node_group_defaults = {
    ami_type = "AL2_x86_64"
  }

  eks_managed_node_groups = {
    general = {
      name = "node-group-1"
      instance_types = ["c7i-flex.large"]

      min_size     = 1
      max_size     = 2
      desired_size = 2
    }
  }
}
