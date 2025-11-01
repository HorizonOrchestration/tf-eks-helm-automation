# VPC Flow Logs resources

data "aws_iam_policy_document" "vpc_flow_logs_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "vpc_flow_logs" {
  count              = var.enable_cloudwatch_logging ? 1 : 0
  name               = "${local.environment}-eks-vpc-flow-logs-role"
  description        = "IAM role for VPC Flow Logs to publish to CloudWatch Logs - Managed by Terraform"
  assume_role_policy = data.aws_iam_policy_document.vpc_flow_logs_assume_role.json

  tags = {
    Name = "${local.environment}-eks-vpc-flow-logs-role"
  }
}

data "aws_iam_policy_document" "vpc_flow_logs_policy" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams"
    ]
    resources = var.enable_cloudwatch_logging ? [
      aws_cloudwatch_log_group.eks_vpc_flow_logs[0].arn,
      "${aws_cloudwatch_log_group.eks_vpc_flow_logs[0].arn}:*"
    ] : []
  }
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  count  = var.enable_cloudwatch_logging ? 1 : 0
  name   = "${local.environment}-eks-vpc-flow-logs-policy"
  role   = aws_iam_role.vpc_flow_logs[0].id
  policy = data.aws_iam_policy_document.vpc_flow_logs_policy.json
}

resource "aws_cloudwatch_log_group" "eks_vpc_flow_logs" {
  count             = var.enable_cloudwatch_logging ? 1 : 0
  name              = "/aws/vpc/${local.environment}-eks-flow-logs"
  retention_in_days = 14
  kms_key_id        = aws_kms_key.customer_managed_key[0].arn

  tags = {
    Name = "${local.environment}-eks-vpc-flow-logs"
  }
}

resource "aws_flow_log" "eks_vpc" {
  count                = var.enable_cloudwatch_logging ? 1 : 0
  vpc_id               = aws_vpc.eks.id
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.eks_vpc_flow_logs[0].arn
  iam_role_arn         = aws_iam_role.vpc_flow_logs[0].arn
  traffic_type         = "ALL"

  tags = {
    Name = "${local.environment}-eks-vpc-flow-logs"
  }
}

# Kubernetes API Logging

resource "aws_cloudwatch_log_group" "eks_control_plane" {
  count             = var.enable_cloudwatch_logging ? 1 : 0
  name              = "/aws/eks/eks-cluster-${local.environment}/cluster"
  retention_in_days = 14
  kms_key_id        = aws_kms_key.customer_managed_key[0].arn

  tags = {
    Name = "${local.environment}-eks-control-plane-logs"
  }
}
