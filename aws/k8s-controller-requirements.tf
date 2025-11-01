# Kubernetes Required Resources

data "tls_certificate" "oidc_thumbprint" {
  count = var.build_cluster_resources ? 1 : 0
  url   = aws_eks_cluster.cluster[0].identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  count           = var.build_cluster_resources ? 1 : 0
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.oidc_thumbprint[0].certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.cluster[0].identity[0].oidc[0].issuer
}

## Driver IAM Policies

locals {
  controllers = {
    for controller in ["ebs-csi", "efs-csi", "alb", "eso", "cert-manager"] : controller => controller
  }
}

data "aws_iam_policy_document" "controller_trust_policies" {
  for_each = var.build_cluster_resources ? local.controllers : {}
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks[0].arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_eks_cluster.cluster[0].identity[0].oidc[0].issuer, "https://", "")}:sub"
      values   = ["system:serviceaccount:controllers:${each.value}-controller-sa"]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_eks_cluster.cluster[0].identity[0].oidc[0].issuer, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "controller_roles" {
  for_each           = var.build_cluster_resources ? local.controllers : {}
  name               = "${each.value}-controller-role"
  assume_role_policy = data.aws_iam_policy_document.controller_trust_policies[each.key].json
}

resource "aws_iam_policy" "controller_policies" {
  for_each    = var.build_cluster_resources ? local.controllers : {}
  name        = "${each.value}-controller-policy"
  description = "IAM policy for ${each.value} Controller"
  policy      = file("${path.module}/resources/${each.value}-iam-policy.json")
}

resource "aws_iam_role_policy_attachment" "controller_role_attachments" {
  for_each   = var.build_cluster_resources ? local.controllers : {}
  role       = aws_iam_role.controller_roles[each.key].name
  policy_arn = aws_iam_policy.controller_policies[each.key].arn
}

# Ingress Resource outputs

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider for EKS"
  value       = var.build_cluster_resources ? aws_iam_openid_connect_provider.eks[0].arn : "NaN"
}

output "controller_policy_arns" {
  description = "ARNs of the IAM Policies for the Kubernetes Controllers"
  value       = var.build_cluster_resources ? { for key, policy in aws_iam_policy.controller_policies : key => policy.arn } : { "controller" : "NaN" }
}

output "controller_role_arns" {
  description = "ARNs of the IAM Roles for the Kubernetes Controllers"
  value       = var.build_cluster_resources ? { for key, role in aws_iam_role.controller_roles : key => role.arn } : { "controller" : "NaN" }
}
