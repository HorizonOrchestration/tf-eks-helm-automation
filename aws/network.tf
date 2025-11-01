# EKS Network Resources

resource "aws_vpc" "eks" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.environment}-eks-vpc"
  }
}

resource "aws_default_security_group" "eks_default_block_all" {
  vpc_id                 = aws_vpc.eks.id
  revoke_rules_on_delete = true

  ingress = []
  egress  = []

  tags = {
    Name = "${local.environment}-eks-default-block-all"
  }
}

## Public Subnets

resource "aws_subnet" "eks_public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.eks.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  map_public_ip_on_launch = var.use_private_cidrs ? false : true
  availability_zone       = element(var.azs, count.index)

  tags = {
    Name                                                     = "${local.environment}-eks-public-${element(var.azs, count.index)}"
    Type                                                     = "public"
    "kubernetes.io/role/elb"                                 = "1"
    "kubernetes.io/cluster/eks-cluster-${local.environment}" = "shared"
  }
}

resource "aws_internet_gateway" "eks" {
  vpc_id = aws_vpc.eks.id

  tags = {
    Name = "${local.environment}-eks-igw"
  }
}

resource "aws_route_table" "eks_public" {
  vpc_id = aws_vpc.eks.id

  tags = {
    Name = "${local.environment}-eks-public-rt"
    Type = "public"
  }
}

resource "aws_route" "eks_public_internet_access" {
  route_table_id         = aws_route_table.eks_public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.eks.id
}

resource "aws_route_table_association" "eks_public" {
  count          = length(aws_subnet.eks_public)
  subnet_id      = aws_subnet.eks_public[count.index].id
  route_table_id = aws_route_table.eks_public.id
}

## Private Subnets

resource "aws_subnet" "eks_private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.eks.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = element(var.azs, count.index)

  tags = {
    Name                                                     = "${local.environment}-eks-private-${element(var.azs, count.index)}"
    Type                                                     = "private"
    "kubernetes.io/role/internal-elb"                        = "1"
    "kubernetes.io/cluster/eks-cluster-${local.environment}" = "shared"
  }
}

resource "aws_nat_gateway" "eks" {
  count         = var.use_private_cidrs ? 1 : 0
  allocation_id = aws_eip.eks_nat.id
  subnet_id     = aws_subnet.eks_public[0].id

  tags = {
    Name = "${local.environment}-eks-nat"
  }
}

resource "aws_eip" "eks_nat" {
  tags = {
    Name = "${local.environment}-eks-nat-eip"
  }
}

resource "aws_route_table" "eks_private" {
  vpc_id = aws_vpc.eks.id

  tags = {
    Name = "${local.environment}-eks-private-rt"
    Type = "private"
  }
}

resource "aws_route" "eks_private_nat_access" {
  count                  = var.use_private_cidrs ? 1 : 0
  route_table_id         = aws_route_table.eks_private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.eks[0].id
}

resource "aws_route_table_association" "eks_private" {
  count          = length(aws_subnet.eks_private)
  subnet_id      = aws_subnet.eks_private[count.index].id
  route_table_id = aws_route_table.eks_private.id
}

# Network outputs

output "eks_vpc_id" {
  description = "VPC ID for EKS cluster"
  value       = aws_vpc.eks.id
}

output "eks_public_subnet_ids" {
  description = "Public subnet IDs for EKS cluster"
  value       = aws_subnet.eks_public[*].id
}

output "eks_private_subnet_ids" {
  description = "Private subnet IDs for EKS cluster"
  value       = aws_subnet.eks_private[*].id
}
