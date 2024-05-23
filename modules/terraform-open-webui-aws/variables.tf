################################################################################
# General
################################################################################

variable "name" {
  type        = string
  description = "Common name to use on all resources"
  default     = "open-web-ui"
}

variable "tags" {
  type        = map(string)
  description = "A map of tags to add to all resources"
  default     = {}
}

variable "vpc_id" {
  type        = string
  description = "ID of the VPC in which the resources will be created"
}

variable "open_webui" {
  description = "Map of values passed to OpenWebUI container definition. See the [ECS container definition module](https://github.com/terraform-aws-modules/terraform-aws-ecs/tree/master/modules/container-definition) for full list of arguments supported"
  type        = any
  default     = {}
}

variable "open_webui_version" {
  description = "Version of the OpenWebUI container to deploy"
  type        = string
  default     = "main"
}

variable "open_webui_gid" {
  description = "GID of the open_webui user"
  type        = number
  default     = 1000
}

variable "open_webui_uid" {
  description = "UID of the open_webui user"
  type        = number
  default     = 100
}

variable "openai_api_base_url" {
  description = "OpenAI API base URL"
  type        = string
  default     = null
}

variable "openai_api_key" {
  description = "OpenAI API key"
  type        = string
  sensitive   = true
  default     = ""
}

################################################################################
# Load Balancer
################################################################################

variable "create_alb" {
  type        = bool
  description = "Determines whether to create an Application Load Balancer for the ECS service"
  default     = true
}

variable "alb" {
  type        = any
  description = "Map of values passed to ALB module definition. See the [ALB module](https://github.com/terraform-aws-modules/terraform-aws-alb) for full list of supported arguments"
  default     = {}
}

variable "alb_https_default_action" {
  type        = any
  description = "Default action for ALB HTTPS listener"
  default = {
    forward = {
      target_group_key = "open_webui"
    }
  }
}

variable "alb_security_group_id" {
  type        = string
  description = "ID of an existing security group to attach to the ALB. Required if `create_alb` is `false`"
  default     = ""
}

variable "alb_subnets" {
  type        = list(string)
  description = "A list of subnets in which the ALB will be deployed. Required if `create_alb` is `true`"
  default     = []
}

variable "alb_target_group_arn" {
  type        = string
  description = "ARN of an existing ALB target group that will be used to route traffic to the OpenWebUi service. Required if `create_alb` is `false`"
  default     = ""
}

variable "create_route53_records" {
  type        = bool
  description = "Determines whether to create Route53 records for the ALB"
  default     = true
}

################################################################################
# ACM
################################################################################

variable "create_certificate" {
  type        = bool
  description = "Determines whether to create an ACM certificate for the ALB"
  default     = true
}

variable "certificate_arn" {
  type        = string
  description = "ARN of an existing ACM certificate to use with the ALB. If not provided, a new certificate will be created. Required if `create_alb` is `true` and `create_certificate` is `false`"
  default     = ""
}

variable "certificate_domain_name" {
  type        = string
  description = "Route53 domain name to use for ACM certificate. Route53 zone for this domain should be created in advance."
  default     = ""
}

variable "validate_certificate" {
  type        = bool
  description = "Determines whether to validate ACM certificate using Route53 DNS. If false, certificate will be created but not validated"
  default     = true
}

variable "route53_record_name" {
  type        = string
  description = "Name of Route53 record to create ACM certificate in and main A-record. If not specified var.name will be used. Required if create_route53_records is true"
  default     = null
}

variable "route53_zone_id" {
  type        = string
  description = "ID of the Route53 zone in which to create records. Required if create_route53_records is true"
  default     = ""
}

################################################################################
# ECS
################################################################################

variable "create_cluster" {
  type        = bool
  description = "Determines whether to create an ECS cluster for the service"
  default     = true
}

variable "cluster" {
  type        = any
  description = "Map of values passed to ECS cluster module definition. See the [ECS cluster module](https://github.com/terraform-aws-modules/terraform-aws-ecs/tree/master/modules/cluster) for full list of supported arguments"
  default     = {}
}

variable "cluster_arn" {
  type        = string
  description = "ARN of the ECS cluster in which the service will be deployed. Required if create_cluster is false"
  default     = null
}

variable "service" {
  description = "Map of values passed to ECS service module definition. See the [ECS service module](https://github.com/terraform-aws-modules/terraform-aws-ecs/tree/master/modules/service) for full list of arguments supported"
  type        = any
  default     = {}
}

variable "service_subnets" {
  type        = list(string)
  description = "A list of subnets in which the ECS service for will be deployed"
}

################################################################################
# EFS
################################################################################

variable "efs" {
  type        = any
  description = "Map of values passed to EFS module definition. See the [EFS module](https://github.com/terraform-aws-modules/terraform-aws-efs) for full list of arguments supported"
  default     = {}
}

variable "enable_efs" {
  type        = bool
  description = "Determines whether to create an EFS volume for the ECS service, this is used for model storage if enabled"
  default     = false
}
