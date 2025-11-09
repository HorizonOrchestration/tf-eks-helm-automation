# tf-eks-helm-automation

This repository provides automated, secure, and modular infrastructure for deploying applications on Amazon EKS (Elastic Kubernetes Service) using Terraform and Helm. It implements AWS best practices for security, environment separation, and automation.

## Overview

- **Infrastructure as Code:** Terraform modules for EKS, VPC, IAM, logging, and networking.
- **Kubernetes Management:** Helm charts for application deployment and lifecycle management.
- **CI/CD Automation:** GitHub Actions workflows for validation, security scanning, and deployment.
- **Security:** Least-privilege IAM, encrypted S3 state, VPC Flow Logs, and strict network controls.
- **Environment Separation:** Supports dev, staging, and prod via workspaces and variable files.

## AWS Architecture (High-Level)

- **VPC:** Custom VPC with public and private subnets across multiple AZs for high availability.
- **Subnets:** Public subnets for load balancers; private subnets for EKS nodes and internal workloads.
- **Internet Gateway (IGW):** Provides internet access for public subnets.
- **NAT Gateway:** Allows private subnets to access the internet securely.
- **Route Tables & NACLs:** Segregated routing and network ACLs for least-privilege access.
- **IAM:** Roles and policies for EKS, GitHub Actions, and logging, following least-privilege principles.
- **EKS Cluster:** Managed Kubernetes control plane and node groups.
- **S3:** Secure, encrypted bucket for Terraform state with state locking.
- **CloudWatch Logs:** Centralized logging for VPC Flow Logs and auditing.

## GitHub Actions Workflows

Workflows are defined in `.github/workflows/` and follow a modular, reusable pattern:

- **`aws-dev-terraform-test.yaml`:**
  - **Triggers:** On push and pull request to `feature/*` branches.
  - **Flow:**
    1. Calls reusable `terraform.yaml` workflow with parameters for stack, environment, region, IAM role, and state bucket
    2. Runs Terraform plan, linting, validation, and security scans
    3. Publishes test and scan results as workflow artifacts

- **`terraform.yaml`:** (Reusable Workflow)
  - **Parameters:** Action, stack, environment, AWS region, IAM role, state bucket prefix.
  - **Steps:**
    1. Checkout code
    2. Setup Terraform
    3. Configure AWS credentials (OIDC/GitHub Actions role)
    4. Initialize Terraform with S3 backend
    5. Select/create workspace
    6. Run `terraform fmt` and `terraform validate`
    7. Run `terraform plan` (outputs JSON plan)
    8. Run TFLint and Checkov for linting and security
    9. Publish results and upload plan artifact

- **`kubernetes-dev-helm-test.yaml`:**
  - **Triggers:** On push and pull request to `feature/*` branches.
  - **Flow:**
    1. Lint and validate helmfile setup.
    2. Output kubernetes planned manifests for review

- **`helm.yaml`:** (Reusable Workflow)
  - **Parameters:** Environment.
  - **Steps:**
    1. Checkout code
    2. Setup Helmfile
    3. Lint helmfile data and charts
    4. Generate and output kubernetes manifest files for review

- **Security:**
  - No hardcoded secrets; uses OIDC and IAM roles.
  - S3 state is encrypted and locked.
  - All workflows run security and compliance checks (TFLint, Checkov).

## Security Best Practices

- IAM roles and policies grant only required permissions (no wildcards).
- S3 state bucket is private, encrypted, and uses state locking.
- Sensitive data is stored in AWS Secrets Manager or SSM Parameter Store.
- Security groups and NACLs restrict access to required ports and protocols.
- VPC Flow Logs and CloudWatch for monitoring and auditing.
- Encryption is enabled for data at rest and in transit.

## EKS Cluster Security & Access

- **Secrets Encryption:** EKS secrets are encrypted at rest using a customer-managed KMS key (CMK), managed by Terraform and restricted to EKS and your AWS account.
- **Control Plane Logging:** EKS control plane logs (API, audit, authenticator, controllerManager, scheduler) are sent to a dedicated, encrypted CloudWatch Log Group.
- **Admin Access:** Cluster admin access is managed using EKS Access Policy Associations (AmazonEKSAdminPolicy) or via the `aws-auth` ConfigMap. The new EKS Access Entry/Policy Association resources are used for fine-grained access control.
- **Kubernetes Network Config:** The cluster uses a custom service CIDR and supports encryption and upgrade policies.

## Project Setup Steps

## Getting Started

Follow these steps to provision and manage your EKS infrastructure:

### 0. Prerequisites

- **AWS CLI:** Installed and configured with a user that has sufficient IAM permissions (admin or equivalent).
- **kubectl:** Installed for interacting with your EKS cluster.
- **Terraform:** Installed (version >= 1.3 recommended).
- **helmfile:** Installed for deploying helmfile.

### 1. Clone the Repository

```sh
git clone https://github.com/<your-org>/tf-eks-helm-automation.git
cd tf-eks-helm-automation
```

### 2. Configure Prerequisite Variables

Edit `prereqs/terraform.tfvars` and set the following values to match your GitHub organization and repository:

```hcl
github_org  = "your-github-org"
github_repo = "tf-eks-helm-automation"
```

### 3. Deploy Prerequisite Resources

Initialize and apply the Terraform configuration for prerequisites (e.g., S3 backend, IAM roles):

```sh
cd prereqs
terraform init
terraform apply
```

> **Note:** Prerequisite resources are typically permanent. You may manage their state locally or migrate to remote S3 as needed.

### 4. Configure Environment Variables

Edit the relevant environment variable files in `aws/environments/*.tfvars` to customize settings for each environment (dev, staging, prod):

```hcl
# Example: aws/environments/dev.tfvars
# TODO: add examples here as project develops
```

### 5. Deploy AWS Infrastructure

Initialize and apply the main Terraform configuration for your chosen environment:

```sh
cd ../aws
terraform init
terraform workspace new dev # or select an existing workspace
terraform apply -var-file="environments/dev.tfvars"
```

### 6. Update kubectl Access

After deployment, update your kubeconfig to access the EKS cluster:

```sh
aws eks update-kubeconfig --name <cluster_name>
```

You can now interact with your cluster using `kubectl`.

### 7. Deploy Controllers

Deploy the controllers to your EKS cluster:

```sh
helmfile apply -f helm/helmfile-<environment>
```

## License

This project is licensed under the Apache License 2.0. See the [LICENSE](LICENSE) file for details.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | >= 4.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.11.0 |
| <a name="provider_tls"></a> [tls](#provider\_tls) | 4.1.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.eks_control_plane](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.eks_vpc_flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_default_security_group.eks_default_block_all](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/default_security_group) | resource |
| [aws_ebs_volume.eks_ebs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ebs_volume) | resource |
| [aws_efs_file_system.eks_efs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_file_system) | resource |
| [aws_efs_mount_target.eks_efs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_mount_target) | resource |
| [aws_eip.eks_nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_eks_access_policy_association.admin_user_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_access_policy_association) | resource |
| [aws_eks_cluster.cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_cluster) | resource |
| [aws_eks_node_group.eks_nodes](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_node_group) | resource |
| [aws_flow_log.eks_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/flow_log) | resource |
| [aws_iam_openid_connect_provider.eks](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_openid_connect_provider) | resource |
| [aws_iam_policy.controller_policies](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.controller_roles](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.eks_node_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.eks_service_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.vpc_flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.vpc_flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.controller_role_attachments](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.eks_node_attachments](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.eks_service_attachments](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_internet_gateway.eks](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway) | resource |
| [aws_kms_key.cloudwatch_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_kms_key.eks_secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_nat_gateway.eks](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway) | resource |
| [aws_network_acl.eks_private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl) | resource |
| [aws_network_acl.eks_public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl) | resource |
| [aws_network_acl_rule.eks_private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule) | resource |
| [aws_network_acl_rule.eks_public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule) | resource |
| [aws_route.eks_private_nat_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.eks_public_internet_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route_table.eks_private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table.eks_public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table_association.eks_private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.eks_public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_security_group.efs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_subnet.eks_private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.eks_public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.eks](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.cloudwatch_logs_kms](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.controller_trust_policies](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.eks_assume_role_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.eks_node_assume_role_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.eks_secrets_kms](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.vpc_flow_logs_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.vpc_flow_logs_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [tls_certificate.oidc_thumbprint](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/data-sources/certificate) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_private_egress_rules"></a> [additional\_private\_egress\_rules](#input\_additional\_private\_egress\_rules) | Additional egress rules to add to the private NACLs. | <pre>list(object({<br/>    name        = string<br/>    rule_number = number<br/>    egress      = bool<br/>    protocol    = string<br/>    rule_action = string<br/>    cidr_block  = string<br/>    from_port   = number<br/>    to_port     = number<br/>  }))</pre> | `[]` | no |
| <a name="input_additional_public_egress_rules"></a> [additional\_public\_egress\_rules](#input\_additional\_public\_egress\_rules) | Additional egress rules to add to the public NACLs. | <pre>list(object({<br/>    name        = string<br/>    rule_number = number<br/>    egress      = bool<br/>    protocol    = string<br/>    rule_action = string<br/>    cidr_block  = string<br/>    from_port   = number<br/>    to_port     = number<br/>  }))</pre> | `[]` | no |
| <a name="input_admin_access_username"></a> [admin\_access\_username](#input\_admin\_access\_username) | Name of the IAM role for user access to the EKS cluster. | `string` | `"ckatraining"` | no |
| <a name="input_allowed_public_ingress_cidrs"></a> [allowed\_public\_ingress\_cidrs](#input\_allowed\_public\_ingress\_cidrs) | The public CIDRs allowed to access the public subnet on port 443. | `list(string)` | `[]` | no |
| <a name="input_azs"></a> [azs](#input\_azs) | List of availability zones to use for subnets. | `list(string)` | <pre>[<br/>  "eu-west-2a",<br/>  "eu-west-2b",<br/>  "eu-west-2c"<br/>]</pre> | no |
| <a name="input_build_cluster_resources"></a> [build\_cluster\_resources](#input\_build\_cluster\_resources) | Whether to build cluster resources. | `bool` | `true` | no |
| <a name="input_control_plane_log_types"></a> [control\_plane\_log\_types](#input\_control\_plane\_log\_types) | List of control plane log types to enable for the EKS cluster. Can include: api, audit, authenticator, controllerManager, scheduler. | `list(string)` | <pre>[<br/>  "api",<br/>  "audit",<br/>  "authenticator",<br/>  "controllerManager",<br/>  "scheduler"<br/>]</pre> | no |
| <a name="input_efs_archive_policy"></a> [efs\_archive\_policy](#input\_efs\_archive\_policy) | Archive policy for the EFS file system. | `string` | `"AFTER_90_DAYS"` | no |
| <a name="input_efs_ia_policy"></a> [efs\_ia\_policy](#input\_efs\_ia\_policy) | Infrequent Access (IA) policy for the EFS file system. | `string` | `"AFTER_7_DAYS"` | no |
| <a name="input_efs_throughput_mode"></a> [efs\_throughput\_mode](#input\_efs\_throughput\_mode) | Throughput mode for the EFS file system. | `string` | `"bursting"` | no |
| <a name="input_eks_capacity_type"></a> [eks\_capacity\_type](#input\_eks\_capacity\_type) | Capacity type for the EKS node group (e.g., ON\_DEMAND, SPOT). | `string` | `"ON_DEMAND"` | no |
| <a name="input_eks_labels"></a> [eks\_labels](#input\_eks\_labels) | Labels to apply to the EKS node group. | `map(string)` | `{}` | no |
| <a name="input_eks_service_cidr"></a> [eks\_service\_cidr](#input\_eks\_service\_cidr) | CIDR block for the EKS service network. | `string` | `"192.168.0.0/16"` | no |
| <a name="input_enable_cloudwatch_logging"></a> [enable\_cloudwatch\_logging](#input\_enable\_cloudwatch\_logging) | Enable CloudWatch logging for deployed resources. | `bool` | `true` | no |
| <a name="input_kubernetes_version"></a> [kubernetes\_version](#input\_kubernetes\_version) | Kubernetes version for the EKS cluster. | `string` | `null` | no |
| <a name="input_microservice_names"></a> [microservice\_names](#input\_microservice\_names) | List of microservice names to deploy. | `list(string)` | `[]` | no |
| <a name="input_node_group_ami_type"></a> [node\_group\_ami\_type](#input\_node\_group\_ami\_type) | AMI type for the EKS node group. | `string` | `"AL2023_ARM_64_STANDARD"` | no |
| <a name="input_node_group_desired_size"></a> [node\_group\_desired\_size](#input\_node\_group\_desired\_size) | Desired number of nodes in the EKS node group. | `number` | `1` | no |
| <a name="input_node_group_instance_types"></a> [node\_group\_instance\_types](#input\_node\_group\_instance\_types) | List of instance types for the EKS node group. | `list(string)` | <pre>[<br/>  "t4g.medium"<br/>]</pre> | no |
| <a name="input_node_group_max_size"></a> [node\_group\_max\_size](#input\_node\_group\_max\_size) | Maximum number of nodes in the EKS node group. | `number` | `1` | no |
| <a name="input_node_group_min_size"></a> [node\_group\_min\_size](#input\_node\_group\_min\_size) | Minimum number of nodes in the EKS node group. | `number` | `1` | no |
| <a name="input_node_group_pinned_subnet_index"></a> [node\_group\_pinned\_subnet\_index](#input\_node\_group\_pinned\_subnet\_index) | Index of the subnet to pin the EKS node group to. | `number` | `2` | no |
| <a name="input_node_group_taints"></a> [node\_group\_taints](#input\_node\_group\_taints) | List of taints to apply to the EKS node group. | <pre>list(object({<br/>    key    = string<br/>    value  = string<br/>    effect = string<br/>  }))</pre> | `[]` | no |
| <a name="input_private_subnet_cidrs"></a> [private\_subnet\_cidrs](#input\_private\_subnet\_cidrs) | List of CIDR blocks for private subnets. | `list(string)` | <pre>[<br/>  "10.0.11.0/24",<br/>  "10.0.12.0/24",<br/>  "10.0.13.0/24"<br/>]</pre> | no |
| <a name="input_public_subnet_cidrs"></a> [public\_subnet\_cidrs](#input\_public\_subnet\_cidrs) | List of CIDR blocks for public subnets. | `list(string)` | <pre>[<br/>  "10.0.1.0/24",<br/>  "10.0.2.0/24",<br/>  "10.0.3.0/24"<br/>]</pre> | no |
| <a name="input_use_private_cidrs"></a> [use\_private\_cidrs](#input\_use\_private\_cidrs) | Whether to build nodes in private subnets. | `bool` | `true` | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | CIDR block for the EKS VPC. | `string` | `"10.0.0.0/16"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_controller_policy_arns"></a> [controller\_policy\_arns](#output\_controller\_policy\_arns) | ARNs of the IAM Policies for the Kubernetes Controllers |
| <a name="output_controller_role_arns"></a> [controller\_role\_arns](#output\_controller\_role\_arns) | ARNs of the IAM Roles for the Kubernetes Controllers |
| <a name="output_ebs_volume_ids"></a> [ebs\_volume\_ids](#output\_ebs\_volume\_ids) | n/a |
| <a name="output_efs_file_system_id"></a> [efs\_file\_system\_id](#output\_efs\_file\_system\_id) | n/a |
| <a name="output_eks_cluster_endpoint"></a> [eks\_cluster\_endpoint](#output\_eks\_cluster\_endpoint) | Endpoint URL of the EKS cluster |
| <a name="output_eks_cluster_name"></a> [eks\_cluster\_name](#output\_eks\_cluster\_name) | Name of the EKS cluster |
| <a name="output_eks_private_subnet_ids"></a> [eks\_private\_subnet\_ids](#output\_eks\_private\_subnet\_ids) | Private subnet IDs for EKS cluster |
| <a name="output_eks_public_subnet_ids"></a> [eks\_public\_subnet\_ids](#output\_eks\_public\_subnet\_ids) | Public subnet IDs for EKS cluster |
| <a name="output_eks_service_role_arn"></a> [eks\_service\_role\_arn](#output\_eks\_service\_role\_arn) | ARN of the EKS service IAM role |
| <a name="output_eks_vpc_id"></a> [eks\_vpc\_id](#output\_eks\_vpc\_id) | VPC ID for EKS cluster |
| <a name="output_oidc_provider_arn"></a> [oidc\_provider\_arn](#output\_oidc\_provider\_arn) | ARN of the OIDC provider for EKS |
<!-- END_TF_DOCS -->