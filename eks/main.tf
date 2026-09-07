module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  # Security: Cluster API is private for nodes/internal traffic, public for CI/CD & admin access
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  vpc_id                   = var.vpc_id
  subnet_ids               = var.subnet_ids
  control_plane_subnet_ids = var.subnet_ids

  # Critical for IRSA (IAM Roles for Service Accounts)
  enable_irsa = true

  # Enterprise Node Group Configuration
  eks_managed_node_groups = {
    core_nodes = {
      name         = "${var.cluster_name}-core"
      instance_types = var.node_instance_types

      min_size     = var.min_size
      max_size     = var.max_size
      desired_size = var.desired_size

      # Subnets where worker nodes will run (Strictly Private)
      subnet_ids   = var.subnet_ids

      # Node security: attach basic policies
      iam_role_additional_policies = {
        AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }

      labels = {
        Environment = var.environment
      }
    }
  }

  # Cluster Access Management: Enable modern EKS Access Entries
  enable_cluster_creator_admin_permissions = true

  tags = {
    Environment = var.environment
    Project     = "NexoraPlatform"
    ManagedBy   = "Terraform"
  }
}