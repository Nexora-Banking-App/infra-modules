# We use the official AWS VPC module to ensure enterprise best practices
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.5.1"

  name = "nexora-${var.environment}-vpc"
  cidr = var.vpc_cidr

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  # Enterprise Security: Private subnets must route to the internet via a NAT Gateway
  enable_nat_gateway     = true
  single_nat_gateway     = true # Set to true to save AWS costs for this demo. In prod, use false.
  one_nat_gateway_per_az = false

  # Required for EKS cluster DNS resolution
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Tags required by Kubernetes/AWS Load Balancer Controller to find subnets
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = {
    Environment = var.environment
    Project     = "NexoraPlatform"
    ManagedBy   = "Terraform"
  }
}