data "aws_availability_zones" "available" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.21"

  name = "${var.cluster_name}-vpc"
  cidr = "10.0.0.0/16"

  # Spread resources across 2 availability zones for high-availability
  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  # NAT gateway allows private subnet nodes to download images from the internet
  enable_nat_gateway = true
  # Use a single NAT gateway to reduce cost for demo environments
  single_nat_gateway = true
  enable_dns_hostnames = true

  # These tags are required so Kubernetes can discover and use the correct subnets
  # when provisioning external Load Balancers for your services
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}

