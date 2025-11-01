# EKS Cluster Required Resources

## EKS Encryption Key

data "aws_iam_policy_document" "eks_secrets_kms" {
  statement {
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = ["*"]
  }
}

resource "aws_kms_key" "eks_secrets" {
  description         = "KMS key for EKS secrets encryption - Managed by Terraform"
  enable_key_rotation = true
  policy              = data.aws_iam_policy_document.eks_secrets_kms.json

  tags = {
    Name = "${local.environment}-eks-secrets-kms"
  }
}

## EKS Cluster IAM Role

locals {
  cluster_policy_names = [ # Built-in AWS managed policies for EKS
    "AmazonEKSClusterPolicy",
    "AmazonEKSServicePolicy",
    "AmazonEKSWorkerNodePolicy",
    "AmazonEC2ContainerRegistryReadOnly",
    "AutoScalingFullAccess"
  ]
}

data "aws_iam_policy_document" "eks_assume_role_policy" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "eks_service_role" {
  name               = "${local.environment}-eks-service-role"
  description        = "IAM role for EKS cluster service - Managed by Terraform"
  assume_role_policy = data.aws_iam_policy_document.eks_assume_role_policy.json

  tags = {
    Name = "${local.environment}-eks-service-role"
  }
}

resource "aws_iam_role_policy_attachment" "eks_service_attachments" {
  for_each = {
    for policy in local.cluster_policy_names : policy => policy
  }

  role       = aws_iam_role.eks_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/${each.value}"
}

## EKS Node IAM Role

locals {
  node_policy_names = [ # Built-in AWS managed policies for EKS worker nodes
    "AmazonEKSWorkerNodePolicy",
    "AmazonEKS_CNI_Policy",
    "AmazonEC2ContainerRegistryReadOnly",
    "AmazonSSMManagedInstanceCore",
    "CloudWatchAgentServerPolicy"
  ]
}

data "aws_iam_policy_document" "eks_node_assume_role_policy" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "eks_node_role" {
  name               = "${local.environment}-eks-node-role"
  description        = "IAM role for EKS worker nodes - Managed by Terraform"
  assume_role_policy = data.aws_iam_policy_document.eks_node_assume_role_policy.json

  tags = {
    Name = "${local.environment}-eks-node-role"
  }
}

resource "aws_iam_role_policy_attachment" "eks_node_attachments" {
  for_each = {
    for policy in local.node_policy_names : policy => policy
  }

  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/${each.value}"
}

# EKS Cluster Configuration

resource "aws_eks_cluster" "cluster" {
  count                     = var.build_cluster_resources ? 1 : 0
  name                      = "eks-cluster-${local.environment}"
  role_arn                  = aws_iam_role.eks_service_role.arn
  enabled_cluster_log_types = var.enable_cloudwatch_logging ? var.control_plane_log_types : null
  version                   = var.kubernetes_version

  vpc_config {
    public_access_cidrs     = var.allowed_public_ingress_cidrs
    subnet_ids              = var.use_private_cidrs ? aws_subnet.eks_private[*].id : aws_subnet.eks_public[*].id
    endpoint_private_access = true
  }

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  encryption_config {
    resources = ["secrets"]
    provider {
      key_arn = aws_kms_key.eks_secrets.arn
    }
  }

  kubernetes_network_config {
    service_ipv4_cidr = var.eks_service_cidr
  }

  upgrade_policy {
    support_type = "STANDARD"
  }

  depends_on = [
    aws_cloudwatch_log_group.eks_control_plane
  ]
}

resource "aws_eks_access_policy_association" "admin_user_access" {
  count         = var.build_cluster_resources ? 1 : 0
  cluster_name  = aws_eks_cluster.cluster[0].name
  principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${var.admin_access_username}"
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

resource "aws_eks_node_group" "eks_nodes" {
  count           = var.build_cluster_resources ? 1 : 0
  cluster_name    = aws_eks_cluster.cluster[0].name
  node_group_name = "${local.environment}-eks-nodes"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = var.use_private_cidrs ? [aws_subnet.eks_private[var.node_group_pinned_subnet_index].id] : [aws_subnet.eks_public[var.node_group_pinned_subnet_index].id] # pinned subnet 
  capacity_type   = var.eks_capacity_type
  labels          = var.eks_labels
  instance_types  = var.node_group_instance_types
  ami_type        = var.node_group_ami_type

  scaling_config {
    desired_size = var.node_group_desired_size
    max_size     = var.node_group_max_size
    min_size     = var.node_group_min_size
  }

  remote_access {
    ec2_ssh_key = "troubleshooting"
  }

  dynamic "taint" {
    for_each = var.node_group_taints
    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  tags = {
    Name = "${local.environment}-eks-nodes"
  }
}

# EKS Cluster Outputs

output "eks_service_role_arn" {
  description = "ARN of the EKS service IAM role"
  value       = aws_iam_role.eks_service_role.arn
}

output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = var.build_cluster_resources ? aws_eks_cluster.cluster[0].name : "NaN"
}

output "eks_cluster_endpoint" {
  description = "Endpoint URL of the EKS cluster"
  value       = var.build_cluster_resources ? aws_eks_cluster.cluster[0].endpoint : "NaN"
}
