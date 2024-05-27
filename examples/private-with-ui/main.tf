provider "aws" {
  region = local.region
}

data "aws_availability_zones" "available" {}

locals {
  region = "us-east-2"
  name   = "inference"

  domain = "aprime.click"

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  text_generation_inference_discovery_name = "text-generation-inference"
  text_generation_inference_port           = 11434
  nginx_port                               = 80

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

  name = "${local.name}-tgi"

  text_generation_inference = {
    port          = local.text_generation_inference_port
    image_version = "2.0.3"
  }
  nginx = {
    port = local.nginx_port
  }
  instance_type = "g4dn.2xlarge"
  quantize      = "bitsandbytes"

  vpc_id = module.vpc.vpc_id

  # ECS
  service = {
    deployment_minimum_healthy_percent = 0
    service_connect_configuration = {
      enabled   = true
      namespace = aws_service_discovery_http_namespace.this.arn
      service = {
        client_alias = {
          # We proxy through the nginx container so Open WebUI can access the
          # mocked /v1/models endpoint which is required for its operation.
          port = local.nginx_port
        }
        port_name      = "http-proxy"
        discovery_name = local.text_generation_inference_discovery_name
      }
    }
  }
  service_subnets    = module.vpc.private_subnets
  use_spot_instances = true

  # ALB
  create_alb = false

  # ACM
  create_certificate = false

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

##############################################################
# Open WebUI
##############################################################

module "open_webui" {
  source = "../../modules/terraform-open-webui-aws"

  name = "${local.name}-open-webui"

  open_webui_version = "v0.1.125"

  vpc_id              = module.vpc.vpc_id
  openai_api_base_url = "http://${local.text_generation_inference_discovery_name}.${aws_service_discovery_http_namespace.this.name}/v1"
  openai_api_key      = "fake"

  # ECS
  create_cluster = false
  cluster_arn    = module.text_generation_inference.cluster_arn
  service = {
    service_connect_configuration = {
      enabled   = true
      namespace = aws_service_discovery_http_namespace.this.arn
    }
  }
  open_webui = {
    # Note this is a workaround for the Open WebUI image not building with
    # non-root user support by default, see:
    # https://github.com/open-webui/open-webui/pull/2322
    image = "ghcr.io/pfacheris/open-webui:git-e6cb207"
    environment = [
      {
        name  = "ENABLE_LITELLM"
        value = "False"
      }
    ]
  }
  open_webui_uid  = 100
  open_webui_gid  = 1000
  service_subnets = module.vpc.private_subnets

  # ALB
  create_alb  = true
  alb_subnets = module.vpc.public_subnets
  alb = {
    enable_deletion_protection = false
  }

  # ACM
  certificate_domain_name = "${local.name}-open-webui.${data.aws_route53_zone.this.name}"
  route53_zone_id         = data.aws_route53_zone.this.zone_id

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

data "aws_route53_zone" "this" {
  name = local.domain
}

##############################################################
# Service Discovery
##############################################################

resource "aws_service_discovery_http_namespace" "this" {
  name        = local.name
  description = "CloudMap namespace for ${local.name}"
  tags        = local.tags
}

##############################################################
# Additional Security Group Rules
##############################################################

resource "aws_security_group_rule" "allow_open_webui_to_text_generation_inference" {
  type                     = "ingress"
  from_port                = local.nginx_port
  to_port                  = local.nginx_port
  protocol                 = "tcp"
  source_security_group_id = module.open_webui.ecs_service_security_group_id
  security_group_id        = module.text_generation_inference.ecs_service_security_group_id
}
