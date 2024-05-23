################################################################################
# ACM
################################################################################

module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "5.0.0"

  create_certificate = var.create_certificate && var.create_alb

  domain_name          = var.certificate_domain_name
  validate_certificate = var.validate_certificate
  validation_method    = "DNS"
  zone_id              = var.route53_zone_id

  tags = var.tags
}
