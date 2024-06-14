##############################################################
# Open WebUI
##############################################################

locals {
  name = "${var.name}-open-webui"
}

locals {
  domain_name = "${local.name}.${var.route53_zone_name}"
}

module "open_webui" {
  source     = "./modules/terraform-open-webui-aws"
  count      = var.create_ui ? 1 : 0
  depends_on = [module.ecs_service]

  name = local.name

  open_webui_version = "v0.1.125"

  vpc_id              = var.vpc_id
  openai_api_base_url = "http://${var.text_generation_inference_discovery_name}.${var.text_generation_inference_discovery_namespace}/v1"
  openai_api_key      = "fake"

  # ECS
  create_cluster = false
  cluster_arn    = try(module.ecs_cluster.arn, var.cluster_arn)
  service = {
    deployment_minimum_healthy_percent = 0
    service_connect_configuration = {
      enabled   = true
      namespace = var.service.service_connect_configuration.namespace
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
  service_subnets = var.service_subnets

  # ALB
  create_alb             = true
  create_certificate     = var.use_ssl_ui ? true : false
  create_route53_records = var.use_ssl_ui ? true : false
  alb_use_https          = var.use_ssl_ui ? true : false
  alb_subnets            = var.alb_subnets
  alb = {
    enable_deletion_protection = false
  }

  # ACM
  certificate_domain_name = local.domain_name
  route53_zone_id         = var.route53_zone_id

  # EFS
  enable_efs = true
  efs = {
    mount_targets = {
      for idx, az in var.availability_zones : az => {
        subnet_id = var.service_subnets[idx]
      }
    }
  }

  tags = var.tags
}

resource "aws_security_group_rule" "allow_open_webui_to_text_generation_inference" {
  count                    = var.create_ui ? 1 : 0
  type                     = "ingress"
  from_port                = var.nginx.port
  to_port                  = var.nginx.port
  protocol                 = "tcp"
  source_security_group_id = module.open_webui[0].ecs_service_security_group_id
  security_group_id        = module.ecs_service.security_group_id
}
