################################################################################
# ALB
################################################################################

locals {
  route53_records = {
    A = {
      name    = try(coalesce(var.route53_record_name, var.name), "")
      type    = "A"
      zone_id = var.route53_zone_id
    }
    AAAA = {
      name    = try(coalesce(var.route53_record_name, var.name), "")
      type    = "AAAA"
      zone_id = var.route53_zone_id
    }
  }
}

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "9.1.0"

  create = var.create_alb

  # Load balancer
  access_logs                                 = lookup(var.alb, "access_logs", {})
  customer_owned_ipv4_pool                    = try(var.alb.customer_owned_ipv4_pool, null)
  desync_mitigation_mode                      = try(var.alb.desync_mitigation_mode, null)
  dns_record_client_routing_policy            = try(var.alb.dns_record_client_routing_policy, null)
  drop_invalid_header_fields                  = try(var.alb.drop_invalid_header_fields, true)
  enable_cross_zone_load_balancing            = try(var.alb.enable_cross_zone_load_balancing, true)
  enable_deletion_protection                  = try(var.alb.enable_deletion_protection, true)
  enable_http2                                = try(var.alb.enable_http2, null)
  enable_tls_version_and_cipher_suite_headers = try(var.alb.enable_tls_version_and_cipher_suite_headers, null)
  enable_waf_fail_open                        = try(var.alb.enable_waf_fail_open, null)
  enable_xff_client_port                      = try(var.alb.enable_xff_client_port, null)
  idle_timeout                                = try(var.alb.idle_timeout, null)
  internal                                    = try(var.alb.internal, false)
  ip_address_type                             = try(var.alb.ip_address_type, null)
  load_balancer_type                          = try(var.alb.load_balancer_type, "application")
  name                                        = try(var.alb.name, var.name)
  preserve_host_header                        = try(var.alb.preserve_host_header, null)
  security_groups                             = try(var.alb.security_groups, [])
  subnets                                     = try(var.alb.subnets, var.alb_subnets)
  xff_header_processing_mode                  = try(var.alb.xff_header_processing_mode, null)
  timeouts                                    = try(var.alb.timeouts, {})

  # Listener(s)
  default_port     = try(var.alb.default_port, 80)
  default_protocol = try(var.alb.default_protocol, "HTTP")
  listeners = merge(
    {
      http-https-redirect = {
        port     = 80
        protocol = "HTTP"

        redirect = {
          port        = "443"
          protocol    = "HTTPS"
          status_code = "HTTP_301"
        }
      }

      https = merge(
        {
          port            = 443
          protocol        = "HTTPS"
          ssl_policy      = try(var.alb.https_listener_ssl_policy, "ELBSecurityPolicy-TLS13-1-2-Res-2021-06")
          certificate_arn = var.create_certificate ? module.acm.acm_certificate_arn : var.certificate_arn
        },
        var.alb_https_default_action,
        lookup(var.alb, "https_listener", {})
      )
    },
    lookup(var.alb, "listeners", {})
  )

  # Target group(s)
  target_groups = merge(
    {
      text_generation_inference = {
        name                              = var.name
        protocol                          = "HTTP"
        port                              = local.text_generation_inference_port
        create_attachment                 = false
        target_type                       = "ip"
        deregistration_delay              = 10
        load_balancing_cross_zone_enabled = true

        health_check = {
          enabled             = true
          healthy_threshold   = 5
          interval            = 30
          matcher             = "200"
          path                = "/health"
          port                = "traffic-port"
          protocol            = "HTTP"
          timeout             = 5
          unhealthy_threshold = 2
        }
      }
    },
    lookup(var.alb, "target_groups", {})
  )

  # Security group
  create_security_group          = try(var.alb.create_security_group, true)
  security_group_name            = try(var.alb.security_group_name, var.name)
  security_group_use_name_prefix = try(var.alb.security_group_use_name_prefix, true)
  security_group_description     = try(var.alb.security_group_description, null)
  vpc_id                         = var.vpc_id
  security_group_ingress_rules = lookup(var.alb, "security_group_ingress_rules",
    {
      http = {
        from_port   = 80
        to_port     = 80
        ip_protocol = "tcp"
        cidr_ipv4   = "0.0.0.0/0"
      }
      https = {
        from_port   = 443
        to_port     = 443
        ip_protocol = "tcp"
        cidr_ipv4   = "0.0.0.0/0"
      }
    }
  )
  security_group_egress_rules = lookup(var.alb, "security_group_egress_rules",
    {
      all = {
        ip_protocol = "-1"
        cidr_ipv4   = "0.0.0.0/0"
      }
    }
  )
  security_group_tags = try(var.alb.security_group_tags, {})

  # Route53 record(s)
  route53_records = merge(
    { for k, v in local.route53_records : k => v if var.create_route53_records },
    lookup(var.alb, "route53_records", {})
  )

  # WAF
  associate_web_acl = try(var.alb.associate_web_acl, false)
  web_acl_arn       = try(var.alb.web_acl_arn, null)

  tags = var.tags
}
