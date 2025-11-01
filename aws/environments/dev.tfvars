eks_capacity_type       = "SPOT"
node_group_desired_size = 2
node_group_max_size     = 2
efs_ia_policy           = "AFTER_1_DAY"
enable_efs_cmk_encryption = false
use_private_cidrs       = false
node_group_ami_type     = "AL2023_x86_64_STANDARD"
node_group_instance_types = [
  "t3.medium",
  "t2.medium"
]