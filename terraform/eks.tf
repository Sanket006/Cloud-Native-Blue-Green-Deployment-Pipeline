module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name    = var.cluster_name
  cluster_version = "1.35"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Allow the EKS API server to be reached from the internet.
  # SECURITY: For production, restrict this to your office IP or a VPN CIDR.
  # Replace YOUR_IP/32 below and uncomment to restrict access:
  # cluster_endpoint_public_access_cidrs = ["YOUR_IP/32"]
  cluster_endpoint_public_access = true

  # Grants the identity running 'terraform apply' full admin access to the cluster
  enable_cluster_creator_admin_permissions = true

  # Enable control plane logging for security auditing and troubleshooting
  cluster_enabled_log_types = ["api", "audit", "authenticator"]

  eks_managed_node_group_defaults = {
    ami_type = "AL2_x86_64"
  }

  eks_managed_node_groups = {
    general = {
      name           = "node-group-1"
      instance_types = ["c7i-flex.large"] 

      min_size     = 1
      max_size     = 2
      desired_size = 2
    }
  }
}
