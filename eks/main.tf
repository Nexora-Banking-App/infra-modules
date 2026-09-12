module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  vpc_id                   = var.vpc_id
  subnet_ids               = var.subnet_ids
  control_plane_subnet_ids = var.subnet_ids

  enable_irsa = true

  cluster_addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni    = {}
  }

  # CRITICAL SECURITY RULE: Allow EKS Control Plane to reach Istio Webhook on port 15017!
  node_security_group_additional_rules = {
    ingress_cluster_istiod_webhook = {
      description                   = "Cluster control plane to node Istiod webhook port"
      protocol                      = "tcp"
      from_port                     = 15017
      to_port                       = 15017
      type                          = "ingress"
      source_cluster_security_group = true
    }

    # CRITICAL: Allow AWS Load Balancer to reach services on NodePorts!
    ingress_nodeports = {
      description = "Allow AWS Load Balancer ingress on NodePort range"
      protocol    = "tcp"
      from_port   = 30000
      to_port     = 32767
      type        = "ingress"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  eks_managed_node_groups = {
    core_nodes = {
      name           = "${var.cluster_name}-core"
      instance_types = var.node_instance_types
      ami_type       = "AL2023_x86_64_STANDARD"

      min_size     = var.min_size
      max_size     = var.max_size
      desired_size = var.desired_size

      subnet_ids = var.subnet_ids

      iam_role_additional_policies = {
        AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }

      labels = {
        Environment = var.environment
      }
    }
  }

  enable_cluster_creator_admin_permissions = true

  access_entries = {
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

  tags = {
    Environment = var.environment
    Project     = "NexoraPlatform"
    ManagedBy   = "Terraform"
  }
}