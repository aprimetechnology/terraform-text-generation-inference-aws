provider "aws" {
  region = local.region
}

data "aws_availability_zones" "available" {}

locals {
  region = "us-east-2"
  name   = "text-generation-inference"

  domain                         = "aprime.click"
  text_generation_inference_port = 11434
  vpc_cidr                       = "10.0.0.0/16"
  azs                            = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    Name    = local.name
    Example = local.name
  }
}

##############################################################
# Text Generation Inference
##############################################################

module "text_generation_inference" {
  source = "../../"

  name = local.name

  text_generation_inference = {
    port          = local.text_generation_inference_port
    image_version = "2.0.3"
  }
  instance_type = "g4dn.2xlarge"
  quantize      = "bitsandbytes"
  create_ui     = false

  # ECS
  service = {
    health_check_grace_period_seconds = 600
  }

  # ALB
  alb = {
    enable_deletion_protection = false
  }

  alb_subnets        = module.vpc.public_subnets
  service_subnets    = module.vpc.private_subnets
  vpc_id             = module.vpc.vpc_id
  availability_zones = local.azs

  # ECS
  use_spot_instances = true

  # ACM
  certificate_domain_name = "${local.name}.${aws_route53_zone.this.name}"
  route53_zone_id         = aws_route53_zone.this.id

  # EFS
  enable_efs = true
  efs = {
    mount_targets = {
      for idx, az in local.azs : az => {
        subnet_id = module.vpc.private_subnets[idx]
      }
    }
  }

  tags = local.tags
}

################################################################################
# VPC
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 48)]

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = local.tags
}

##############################################################
# Route53
##############################################################

resource "aws_route53_zone" "this" {
  name = local.domain
}
