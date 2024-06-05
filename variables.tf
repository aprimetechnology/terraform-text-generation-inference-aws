################################################################################
# General
################################################################################

variable "name" {
  type        = string
  description = "Common name to use on all resources"
  default     = "text_generation_inference"
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

variable "availability_zones" {
  type        = list(string)
  description = "The availability_zones to create objects in."
}

variable "text_generation_inference_discovery_name" {
  type        = string
  description = "Name of text-generation-inference used for service discovery"
}

variable "text_generation_inference_discovery_namespace" {
  type        = string
  description = "Namespace of text-generation-inference used for service discovery"
}

variable "create_ui" {
  type        = bool
  description = "Whether you want to create the open webui"
  default     = true

}

variable "use_ssl_ui" {
  type        = bool
  description = "Create domain + certs for ssl connection to the UI."
  default     = true
}

variable "text_generation_inference" {
  description = "Configuration for the text generation inference"
  type = object({
    mount_points                           = optional(list(any), [])
    command                                = optional(list(string), [])
    cpu                                    = optional(number, null)
    dependencies                           = optional(list(map(string)), []) # depends_on is a reserved word
    disable_networking                     = optional(bool, null)
    dns_search_domains                     = optional(list(string), [])
    dns_servers                            = optional(list(string), [])
    docker_labels                          = optional(map(string), {})
    docker_security_options                = optional(list(string), [])
    enable_execute_command                 = optional(bool, false)
    entrypoint                             = optional(list(string), [])
    environment                            = optional(list(object({ name = string, value = string })), [])
    environment_files                      = optional(list(object({ value = string, type = string })), [])
    essential                              = optional(bool, true)
    extra_hosts                            = optional(list(object({ hostname = string, ipAddress = string })), [])
    firelens_configuration                 = optional(map(string), {})
    health_check                           = optional(map(string), {})
    hostname                               = optional(string, null)
    image_repo                             = optional(string, "ghcr.io/huggingface/text-generation-inference")
    image_version                          = optional(string, "latest")
    interactive                            = optional(bool, false)
    links                                  = optional(list(string), [])
    linux_parameters                       = optional(any, {})
    log_configuration                      = optional(map(string), {})
    memory                                 = optional(number, null)
    memory_reservation                     = optional(number, null)
    privileged                             = optional(bool, false)
    pseudo_terminal                        = optional(bool, false)
    readonly_root_filesystem               = optional(bool, false)
    repository_credentials                 = optional(map(string), {})
    resource_requirements                  = optional(list(object({ type = string, value = string })), [])
    secrets                                = optional(list(object({ name = string, valueFrom = string })), [])
    start_timeout                          = optional(number, 30)
    stop_timeout                           = optional(number, 120)
    system_controls                        = optional(list(map(string)), [])
    ulimits                                = optional(list(map(string)), [])
    user                                   = optional(string, null)
    volumes_from                           = optional(list(map(string)), [])
    working_directory                      = optional(string, null)
    enable_cloudwatch_logging              = optional(bool, true)
    create_cloudwatch_log_group            = optional(bool, true)
    cloudwatch_log_group_use_name_prefix   = optional(bool, true)
    cloudwatch_log_group_retention_in_days = optional(number, 14)
    cloudwatch_log_group_kms_key_id        = optional(string, null)
    port                                   = optional(number, 11434)
  })
}

variable "init_nginx" {
  description = "Map of values passed to nginx init container definition. See the [ECS container definition module](https://github.com/terraform-aws-modules/terraform-aws-ecs/tree/master/modules/container-definition) for full list of arguments supported"
  type        = any
  default     = {}
}

variable "nginx" {
  description = "Map of values passed to nginx container definition. See the [ECS container definition module](https://github.com/terraform-aws-modules/terraform-aws-ecs/tree/master/modules/container-definition) for full list of arguments supported"
  type        = any
  default     = {}
}

variable "text_generation_inference_gid" {
  description = "GID of the text_generation_inference user"
  type        = number
  default     = 1000
}

variable "text_generation_inference_uid" {
  description = "UID of the text_generation_inference user"
  type        = number
  default     = 100
}

variable "hugging_face_hub_token" {
  description = "Hugging Face Hub API token"
  type        = string
  sensitive   = true
  default     = ""
}

variable "model_name" {
  description = "The name of the model to load. Can be a MODEL_ID as listed on <https://hf.co/models> like `gpt2` or `OpenAssistant/oasst-sft-1-pythia-12b`. Or it can be a local directory containing the necessary files as saved by `save_pretrained(...)` methods of transformers"
  type        = string
  default     = "teknium/OpenHermes-2.5-Mistral-7B"
}

variable "quantize" {
  description = "Quantize the model to reduce memory usage. This can be useful for large models that don't fit in memory. The default is to not quantize the model"
  type        = string
  default     = null

  validation {
    condition     = var.quantize == null || can(regex("^(awq|eetq|gptq|bitsandbytes|bitsandbytes-nf4|bitsandbytes-fp4|fp8)$", var.quantize))
    error_message = "Quantize must be one of either 'awq', 'eetq', 'gptq', 'bitsandbytes', 'bitsandbytes-nf4', 'bitsandbytes-fp4', or 'fp8'"
  }
}

variable "dtype" {
  description = "Data type to use for model weights. The default is to use the default data type for the model. This is not compatible with quantization"
  type        = string
  default     = null

  validation {
    condition     = var.dtype == null || can(regex("^(float16|bfloat16)$", var.dtype))
    error_message = "dtype must be one of either 'float16' or 'bfloat16'"
  }
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
      target_group_key = "text_generation_inference"
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
  description = "ARN of an existing ALB target group that will be used to route traffic to the Text Generation Inference service. Required if `create_alb` is `false`"
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

variable "route53_zone_name" {
  type        = string
  description = "Name of the Route53 zone in which to create records. Required if create_route53_records is true"
  default     = ""
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
# ECS Autoscaling
################################################################################

variable "autoscaling" {
  type        = any
  description = "Map of values passed to ECS autoscaling module definition. See the [ECS autoscaling module](https://github.com/terraform-aws-modules/terraform-aws-autoscaling) for full list of arguments supported"
  default     = {}
}

variable "cluster_agent_log_level" {
  type        = string
  description = "Log level for ECS cluster agent"
  default     = "info"
}

variable "instance_type" {
  type        = string
  description = "Instance type to use for ECS autoscaling group, note that currently only g4dn.* instance types are supported. When using > 7B models, be sure to select an instance type that has at least 20GB of RAM for initial loading unless using a non-default QUANTIZE setting which reduces RAM usage"
  default     = "g4dn.xlarge"

  validation {
    condition     = can(regex("^g4dn.[a-z0-9]+$", var.instance_type))
    error_message = "Instance type must be in the format 'g4dn.type', e.g. 'g4dn.2xlarge', note that currently only g4dn.* instance types are supported"
  }
}

variable "use_spot_instances" {
  type        = bool
  description = "Determines whether to use spot instances for the ECS autoscaling group"
  default     = false
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
