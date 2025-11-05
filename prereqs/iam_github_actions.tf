resource "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"
  client_id_list = [
    "sts.amazonaws.com"
  ]
  thumbprint_list = [
    "d89e3bd43d5d909b47a18977aa9d5ce36cee184c" # GitHub's OIDC thumbprint
  ]
}

data "aws_iam_policy_document" "github_actions_assume_role_policy" {
  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values = [
        "sts.amazonaws.com"
      ]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_org}/${var.github_repo}:environment:*"
      ]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "github-actions-oidc-role"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role_policy.json

  tags = {
    Name = "github-actions-oidc-role"
  }
}

resource "aws_iam_role_policy_attachment" "github_actions_attach" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess" # Least privilege for GitHub Actions
}

data "aws_iam_policy_document" "github_actions_state" {
  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = ["${aws_s3_bucket.tf_state.arn}/*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "kms:Decrypt"
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "github_actions_helm" {
  statement {
    effect = "Allow"
    actions = [
      "eks:DescribeCluster",
      "eks:ListClusters"
    ]
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "sts:GetCallerIdentity"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "github_actions_state" {
  name        = "github-actions-state-policy"
  description = "Allow PutObject/DeleteObject on S3 state bucket, and KMS Decrypt - Managed by Terraform"
  policy      = data.aws_iam_policy_document.github_actions_state.json

  tags = {
    Name = "github-actions-state-policy"
  }
}

resource "aws_iam_role_policy_attachment" "github_actions_state_attach" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions_state.arn
}

resource "aws_iam_policy" "github_actions_helm" {
  name        = "github-actions-helm-policy"
  description = "Allow GitHub Actions to update kubeconfig and deploy with Helm - Managed by Terraform"
  policy      = data.aws_iam_policy_document.github_actions_helm.json

  tags = {
    Name = "github-actions-helm-policy"
  }
}

resource "aws_iam_role_policy_attachment" "github_actions_helm_attach" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions_helm.arn
}
