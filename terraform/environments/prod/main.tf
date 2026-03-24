# ─── Provider & Backend ───────────────────────────────────────────────────────
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.24"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
  }

  # State distant — S3 + verrouillage DynamoDB
  backend "s3" {
    bucket         = "shopflow-terraform-state"
    key            = "environments/prod/terraform.tfstate"
    region         = "eu-west-1"
    encrypt        = true
    dynamodb_table = "shopflow-terraform-locks"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "shopflow"
      ManagedBy   = "terraform"
      Environment = var.environment
      Owner       = "devops-team"
    }
  }
}

# ─── VPC ──────────────────────────────────────────────────────────────────────
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "shopflow-${var.environment}-vpc"
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs

  enable_nat_gateway     = true
  single_nat_gateway     = var.environment != "prod"
  enable_dns_hostnames   = true
  enable_dns_support     = true

  # Tags nécessaires pour EKS
  public_subnet_tags = {
    "kubernetes.io/cluster/shopflow-${var.environment}" = "shared"
    "kubernetes.io/role/elb"                            = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/shopflow-${var.environment}" = "shared"
    "kubernetes.io/role/internal-elb"                   = "1"
  }
}

# ─── EKS Cluster ──────────────────────────────────────────────────────────────
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "shopflow-${var.environment}"
  cluster_version = "1.29"

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  cluster_endpoint_public_access = true

  # Encryption des secrets K8s avec KMS
  cluster_encryption_config = {
    resources        = ["secrets"]
    provider_key_arn = aws_kms_key.eks.arn
  }

  # Add-ons EKS gérés
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }

  # Node groups managés
  eks_managed_node_groups = {
    main = {
      name           = "shopflow-nodes-${var.environment}"
      instance_types = var.node_instance_types

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      # Mise à jour des nodes sans interruption
      update_config = {
        max_unavailable_percentage = 25
      }

      labels = {
        Environment = var.environment
        NodeGroup   = "main"
      }

      taints = []
    }
  }

  # IRSA — IAM Roles for Service Accounts
  enable_irsa = true
}

# ─── KMS Key pour EKS ────────────────────────────────────────────────────────
resource "aws_kms_key" "eks" {
  description             = "KMS key pour le chiffrement des secrets EKS ShopFlow ${var.environment}"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

# ─── RDS PostgreSQL ───────────────────────────────────────────────────────────
module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.0"

  identifier = "shopflow-${var.environment}-db"

  engine            = "postgres"
  engine_version    = "15.4"
  instance_class    = var.db_instance_class
  allocated_storage = var.db_storage_gb

  db_name  = "shopflow"
  username = "shopflow_admin"

  # Mot de passe géré par Secrets Manager
  manage_master_user_password = true

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name

  # Haute disponibilité en production
  multi_az               = var.environment == "prod"
  publicly_accessible    = false
  deletion_protection    = var.environment == "prod"

  # Backups
  backup_retention_period = var.environment == "prod" ? 30 : 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "Mon:04:00-Mon:05:00"

  # Monitoring
  monitoring_interval    = 60
  monitoring_role_name   = "shopflow-rds-monitoring-${var.environment}"
  create_monitoring_role = true
}

# ─── Security Group RDS ───────────────────────────────────────────────────────
resource "aws_security_group" "rds" {
  name_prefix = "shopflow-rds-${var.environment}-"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
    description     = "PostgreSQL depuis les nodes EKS uniquement"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ─── DB Subnet Group ─────────────────────────────────────────────────────────
resource "aws_db_subnet_group" "main" {
  name       = "shopflow-${var.environment}"
  subnet_ids = module.vpc.private_subnets
}

# ─── Outputs ─────────────────────────────────────────────────────────────────
output "eks_cluster_endpoint" {
  description = "Endpoint du cluster EKS"
  value       = module.eks.cluster_endpoint
  sensitive   = true
}

output "eks_cluster_name" {
  description = "Nom du cluster EKS"
  value       = module.eks.cluster_name
}

output "rds_endpoint" {
  description = "Endpoint RDS PostgreSQL"
  value       = module.rds.db_instance_endpoint
  sensitive   = true
}
