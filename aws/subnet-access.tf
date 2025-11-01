# Public NACL Resources

locals {
  eks_public_cidr_ingress_rules = [
    for cidr in var.allowed_public_ingress_cidrs : { # Allow inbound HTTPS (443) from a specific public CIDRs
      name        = "public_ingress_https_${replace(cidr, "/", "_")}"
      rule_number = 100 + index(var.allowed_public_ingress_cidrs, cidr)
      egress      = false
      protocol    = "tcp"
      rule_action = "allow"
      cidr_block  = cidr
      from_port   = 443
      to_port     = 443
    }
  ]
  eks_public_nacl_non_ingress_rules = [
    { # Allow all inbound traffic from within the VPC
      name        = "public_ingress_from_vpc"
      rule_number = 200
      egress      = false
      protocol    = "-1"
      rule_action = "allow"
      cidr_block  = var.vpc_cidr
      from_port   = null
      to_port     = null
    },
    { # Allow inbound ephemeral ports for return traffic from internet
      name        = "public_ingress_ephemeral"
      rule_number = 299
      egress      = false
      protocol    = "tcp"
      rule_action = "allow"
      cidr_block  = "0.0.0.0/0"
      from_port   = 1024
      to_port     = 65535
    },
    { # Default deny all other inbound traffic
      name        = "public_ingress_deny_all"
      rule_number = 300
      egress      = false
      protocol    = "-1"
      rule_action = "deny"
      cidr_block  = "0.0.0.0/0"
      from_port   = 0
      to_port     = 0
    },
    { # Allow all outbound traffic to within the VPC
      name        = "public_egress_to_vpc"
      rule_number = 100
      egress      = true
      protocol    = "-1"
      rule_action = "allow"
      cidr_block  = var.vpc_cidr
      from_port   = null
      to_port     = null
    },
    { # Allow outbound HTTPS (443) to the internet
      name        = "public_egress_https"
      rule_number = 101
      egress      = true
      protocol    = "tcp"
      rule_action = "allow"
      cidr_block  = "0.0.0.0/0"
      from_port   = 443
      to_port     = 443
    },
    { # Allow all established outbound traffic (ephemeral ports)
      name        = "public_egress_ephemeral"
      rule_number = 199
      egress      = true
      protocol    = "tcp"
      rule_action = "allow"
      cidr_block  = "0.0.0.0/0"
      from_port   = 1024
      to_port     = 65535
    },
    { # Default deny all other outbound traffic
      name        = "public_egress_deny_all"
      rule_number = 200
      egress      = true
      protocol    = "-1"
      rule_action = "deny"
      cidr_block  = "0.0.0.0/0"
      from_port   = 0
      to_port     = 0
    }
  ]
  eks_public_nacl_rules = concat(
    local.eks_public_cidr_ingress_rules,
    concat(
      local.eks_public_nacl_non_ingress_rules,
      var.additional_public_egress_rules
    )
  )
}

resource "aws_network_acl" "eks_public" {
  vpc_id     = aws_vpc.eks.id
  subnet_ids = aws_subnet.eks_public[*].id
  tags = {
    Name = "${local.environment}-eks-public-nacl"
  }
}

resource "aws_network_acl_rule" "eks_public" {
  for_each       = { for rule in local.eks_public_nacl_rules : rule.name => rule }
  network_acl_id = aws_network_acl.eks_public.id
  rule_number    = each.value.rule_number
  egress         = each.value.egress
  protocol       = each.value.protocol
  rule_action    = each.value.rule_action
  cidr_block     = each.value.cidr_block
  from_port      = each.value.from_port == null ? null : each.value.from_port
  to_port        = each.value.to_port == null ? null : each.value.to_port
}

# Private NACL Resources

locals {
  eks_private_cidr_ingress_rules = [
    { # Allow all inbound traffic from within the VPC
      name        = "private_ingress_from_vpc"
      rule_number = 100
      egress      = false
      protocol    = "-1"
      rule_action = "allow"
      cidr_block  = var.vpc_cidr
      from_port   = null
      to_port     = null
    },
    { # Allow inbound ephemeral ports for return traffic from NAT/internet
      name        = "private_ingress_ephemeral"
      rule_number = 110
      egress      = false
      protocol    = "tcp"
      rule_action = "allow"
      cidr_block  = "0.0.0.0/0"
      from_port   = 1024
      to_port     = 65535
    },
    { # Default deny all other inbound traffic
      name        = "private_ingress_deny_all"
      rule_number = 200
      egress      = false
      protocol    = "-1"
      rule_action = "deny"
      cidr_block  = "0.0.0.0/0"
      from_port   = 0
      to_port     = 0
    }
  ]
  eks_private_cidr_non_ingress_rules = [
    { # Allow all outbound traffic to the VPC
      name        = "private_egress_to_vpc"
      rule_number = 100
      egress      = true
      protocol    = "-1"
      rule_action = "allow"
      cidr_block  = var.vpc_cidr
      from_port   = null
      to_port     = null
    },
    { # Allow outbound HTTPS (443) to the internet
      name        = "private_egress_https"
      rule_number = 101
      egress      = true
      protocol    = "tcp"
      rule_action = "allow"
      cidr_block  = "0.0.0.0/0"
      from_port   = 443
      to_port     = 443
    },
    { # Allow all established outbound traffic (ephemeral ports)
      name        = "private_egress_ephemeral"
      rule_number = 199
      egress      = true
      protocol    = "tcp"
      rule_action = "allow"
      cidr_block  = "0.0.0.0/0"
      from_port   = 1024
      to_port     = 65535
    },
    { # Default deny all other outbound traffic
      name        = "private_egress_deny_all"
      rule_number = 200
      egress      = true
      protocol    = "-1"
      rule_action = "deny"
      cidr_block  = "0.0.0.0/0"
      from_port   = 0
      to_port     = 0
    }
  ]
  eks_private_nacl_rules = concat(
    local.eks_private_cidr_ingress_rules,
    concat(
      local.eks_private_cidr_non_ingress_rules,
      var.additional_private_egress_rules
    )
  )
}

resource "aws_network_acl" "eks_private" {
  vpc_id     = aws_vpc.eks.id
  subnet_ids = aws_subnet.eks_private[*].id

  tags = {
    Name = "${local.environment}-eks-private-nacl"
  }
}

resource "aws_network_acl_rule" "eks_private" {
  for_each       = { for rule in local.eks_private_nacl_rules : rule.name => rule }
  network_acl_id = aws_network_acl.eks_private.id
  rule_number    = each.value.rule_number
  egress         = each.value.egress
  protocol       = each.value.protocol
  rule_action    = each.value.rule_action
  cidr_block     = each.value.cidr_block
  from_port      = each.value.from_port == null ? null : each.value.from_port
  to_port        = each.value.to_port == null ? null : each.value.to_port
}
