module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  # Security: API access configuration
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  vpc_id                   = var.vpc_id
  subnet_ids               = var.subnet_ids
  control_plane_subnet_ids = var.subnet_ids

  enable_irsa = true

  # CRITICAL: Install required networking add-ons so nodes become 'Ready' immediately!
  cluster_addons = {
    coredns = {}
    kube-proxy = {}
    vpc-cni = {}
  }

  # Node Group Configuration (Amazon Linux 2023 on EKS 1.31)
  eks_managed_node_groups = {
    core_nodes = {
      name           = "${var.cluster_name}-core"
      instance_types = var.node_instance_types
      ami_type       = "AL2023_x86_64_STANDARD"

      min_size     = var.min_size
      max_size     = var.max_size
      desired_size = var.desired_size

      subnet_ids   = var.subnet_ids

      iam_role_additional_policies = {
        AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }

      labels = {
        Environment = var.environment
      }
    }
  }

  enable_cluster_creator_admin_permissions = true

  # Grants specific users full admin access to the Kubernetes cluster
# Grants specific users full admin access to the Kubernetes cluster
  access_entries = {
    
    # Console Admin (Root Account Access)
    console_admin = {
      principal_arn = "arn:aws:iam::800770414458:root"
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }

    # Laptop/CLI Admin (Your IAM User)
    cli_admin = {
      principal_arn = "arn:aws:iam::800770414458:user/ahmeddhussain"
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }

  }

  
}