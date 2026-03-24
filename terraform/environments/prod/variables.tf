variable "aws_region" {
  description = "Région AWS"
  type        = string
  default     = "eu-west-1"
}

variable "environment" {
  description = "Environnement de déploiement"
  type        = string
  validation {
    condition     = contains(["staging", "prod"], var.environment)
    error_message = "L'environnement doit être 'staging' ou 'prod'."
  }
}

variable "vpc_cidr" {
  description = "CIDR du VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Zones de disponibilité"
  type        = list(string)
  default     = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
}

variable "private_subnet_cidrs" {
  description = "CIDRs des sous-réseaux privés"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnet_cidrs" {
  description = "CIDRs des sous-réseaux publics"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "node_instance_types" {
  description = "Types d'instances EC2 pour les nodes EKS"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_min_size" {
  description = "Nombre minimum de nodes"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Nombre maximum de nodes"
  type        = number
  default     = 6
}

variable "node_desired_size" {
  description = "Nombre désiré de nodes"
  type        = number
  default     = 3
}

variable "db_instance_class" {
  description = "Classe d'instance RDS"
  type        = string
  default     = "db.t3.medium"
}

variable "db_storage_gb" {
  description = "Stockage RDS en GB"
  type        = number
  default     = 20
}
