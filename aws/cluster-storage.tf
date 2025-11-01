# EBS setup for EKS pods

resource "aws_ebs_volume" "eks_ebs" {
  for_each = {
    for name in var.microservice_names : name => name
  }
  availability_zone = var.use_private_cidrs ? aws_subnet.eks_private[var.node_group_pinned_subnet_index].availability_zone : aws_subnet.eks_public[var.node_group_pinned_subnet_index].availability_zone
  size              = "5"
  type              = "gp3"
  encrypted         = false

  tags = {
    Name = "eks-${each.value}-config-${local.environment}"
  }
}

# EFS setup for EKS pods

resource "aws_efs_file_system" "eks_efs" {
  creation_token   = "eks-kustomize-efs-${local.environment}"
  performance_mode = "generalPurpose"
  throughput_mode  = var.efs_throughput_mode
  encrypted        = true

  lifecycle_policy {
    transition_to_ia      = var.efs_ia_policy
    transition_to_archive = var.efs_throughput_mode != "bursting" ? var.efs_archive_policy : null
  }

  tags = {
    Name = "eks-efs-${local.environment}"
  }
}

resource "aws_security_group" "efs" {
  name        = "eks-efs-sg-${local.environment}"
  description = "Security group to allow EKS nodes to mount EFS - Managed by Terraform."
  vpc_id      = aws_vpc.eks.id

  ingress {
    description = "Allow NFS access from EKS subnets - Managed by Terraform."
    protocol    = "tcp"
    to_port     = 2049
    from_port   = 2049
    cidr_blocks = [
      for subnet in(var.use_private_cidrs ? aws_subnet.eks_private : aws_subnet.eks_public) : subnet.cidr_block
    ]
  }

  tags = {
    Name = "eks-efs-sg-${local.environment}"
  }
}

resource "aws_efs_mount_target" "eks_efs" {
  count           = length(var.private_subnet_cidrs)
  file_system_id  = aws_efs_file_system.eks_efs.id
  subnet_id       = var.use_private_cidrs ? aws_subnet.eks_private[count.index].id : aws_subnet.eks_public[count.index].id
  security_groups = [aws_security_group.efs.id]
}

# EFS Outputs for reference

output "ebs_volume_ids" {
  value = { for name, vol in aws_ebs_volume.eks_ebs : name => vol.id }
}

output "efs_file_system_id" {
  value = aws_efs_file_system.eks_efs.id
}
