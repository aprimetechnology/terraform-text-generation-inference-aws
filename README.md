# terraform-text-generation-inference-aws

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.0 |
| <a name="requirement_time"></a> [time](#requirement\_time) | 0.11.1 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 5.0 |
| <a name="provider_time"></a> [time](#provider\_time) | 0.11.1 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_acm"></a> [acm](#module\_acm) | terraform-aws-modules/acm/aws | 5.0.0 |
| <a name="module_alb"></a> [alb](#module\_alb) | terraform-aws-modules/alb/aws | 9.1.0 |
| <a name="module_autoscaling"></a> [autoscaling](#module\_autoscaling) | terraform-aws-modules/autoscaling/aws | ~> 6.5 |
| <a name="module_autoscaling_sg"></a> [autoscaling\_sg](#module\_autoscaling\_sg) | terraform-aws-modules/security-group/aws | ~> 5.0 |
| <a name="module_ecs_cluster"></a> [ecs\_cluster](#module\_ecs\_cluster) | terraform-aws-modules/ecs/aws//modules/cluster | 5.11.0 |
| <a name="module_ecs_service"></a> [ecs\_service](#module\_ecs\_service) | terraform-aws-modules/ecs/aws//modules/service | 5.11.0 |
| <a name="module_efs"></a> [efs](#module\_efs) | terraform-aws-modules/efs/aws | 1.3.1 |
| <a name="module_open_webui"></a> [open\_webui](#module\_open\_webui) | ./modules/terraform-open-webui-aws | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_security_group_rule.allow_open_webui_to_text_generation_inference](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [time_static.activation_date](https://registry.terraform.io/providers/hashicorp/time/0.11.1/docs/resources/static) | resource |
| [aws_ec2_instance_type.cluster_autoscaler](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ec2_instance_type) | data source |
| [aws_ssm_parameter.ecs_optimized_ami](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alb"></a> [alb](#input\_alb) | Map of values passed to ALB module definition. See the [ALB module](https://github.com/terraform-aws-modules/terraform-aws-alb) for full list of supported arguments | `any` | `{}` | no |
| <a name="input_alb_https_default_action"></a> [alb\_https\_default\_action](#input\_alb\_https\_default\_action) | Default action for ALB HTTPS listener | `any` | <pre>{<br>  "forward": {<br>    "target_group_key": "text_generation_inference"<br>  }<br>}</pre> | no |
| <a name="input_alb_security_group_id"></a> [alb\_security\_group\_id](#input\_alb\_security\_group\_id) | ID of an existing security group to attach to the ALB. Required if `create_alb` is `false` | `string` | `""` | no |
| <a name="input_alb_subnets"></a> [alb\_subnets](#input\_alb\_subnets) | A list of subnets in which the ALB will be deployed. Required if `create_alb` is `true` | `list(string)` | `[]` | no |
| <a name="input_alb_target_group_arn"></a> [alb\_target\_group\_arn](#input\_alb\_target\_group\_arn) | ARN of an existing ALB target group that will be used to route traffic to the Text Generation Inference service. Required if `create_alb` is `false` | `string` | `""` | no |
| <a name="input_autoscaling"></a> [autoscaling](#input\_autoscaling) | Map of values passed to ECS autoscaling module definition. See the [ECS autoscaling module](https://github.com/terraform-aws-modules/terraform-aws-autoscaling) for full list of arguments supported | `any` | `{}` | no |
| <a name="input_availability_zones"></a> [availability\_zones](#input\_availability\_zones) | The availability\_zones to create objects in. | `list(string)` | n/a | yes |
| <a name="input_certificate_arn"></a> [certificate\_arn](#input\_certificate\_arn) | ARN of an existing ACM certificate to use with the ALB. If not provided, a new certificate will be created. Required if `create_alb` is `true` and `create_certificate` is `false` | `string` | `""` | no |
| <a name="input_certificate_domain_name"></a> [certificate\_domain\_name](#input\_certificate\_domain\_name) | Route53 domain name to use for ACM certificate. Route53 zone for this domain should be created in advance. | `string` | `""` | no |
| <a name="input_cluster"></a> [cluster](#input\_cluster) | Map of values passed to ECS cluster module definition. See the [ECS cluster module](https://github.com/terraform-aws-modules/terraform-aws-ecs/tree/master/modules/cluster) for full list of supported arguments | `any` | `{}` | no |
| <a name="input_cluster_agent_log_level"></a> [cluster\_agent\_log\_level](#input\_cluster\_agent\_log\_level) | Log level for ECS cluster agent | `string` | `"info"` | no |
| <a name="input_cluster_arn"></a> [cluster\_arn](#input\_cluster\_arn) | ARN of the ECS cluster in which the service will be deployed. Required if create\_cluster is false | `string` | `null` | no |
| <a name="input_create_alb"></a> [create\_alb](#input\_create\_alb) | Determines whether to create an Application Load Balancer for the ECS service | `bool` | `true` | no |
| <a name="input_create_certificate"></a> [create\_certificate](#input\_create\_certificate) | Determines whether to create an ACM certificate for the ALB | `bool` | `true` | no |
| <a name="input_create_cluster"></a> [create\_cluster](#input\_create\_cluster) | Determines whether to create an ECS cluster for the service | `bool` | `true` | no |
| <a name="input_create_route53_records"></a> [create\_route53\_records](#input\_create\_route53\_records) | Determines whether to create Route53 records for the ALB | `bool` | `true` | no |
| <a name="input_create_ui"></a> [create\_ui](#input\_create\_ui) | Whether you want to create the open webui | `bool` | `true` | no |
| <a name="input_dtype"></a> [dtype](#input\_dtype) | Data type to use for model weights. The default is to use the default data type for the model. This is not compatible with quantization | `string` | `null` | no |
| <a name="input_efs"></a> [efs](#input\_efs) | Map of values passed to EFS module definition. See the [EFS module](https://github.com/terraform-aws-modules/terraform-aws-efs) for full list of arguments supported | `any` | `{}` | no |
| <a name="input_enable_efs"></a> [enable\_efs](#input\_enable\_efs) | Determines whether to create an EFS volume for the ECS service, this is used for model storage if enabled | `bool` | `false` | no |
| <a name="input_hugging_face_hub_token"></a> [hugging\_face\_hub\_token](#input\_hugging\_face\_hub\_token) | Hugging Face Hub API token | `string` | `""` | no |
| <a name="input_init_nginx"></a> [init\_nginx](#input\_init\_nginx) | Map of values passed to nginx init container definition. See the [ECS container definition module](https://github.com/terraform-aws-modules/terraform-aws-ecs/tree/master/modules/container-definition) for full list of arguments supported | `any` | `{}` | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | Instance type to use for ECS autoscaling group, note that currently only g4dn.* instance types are supported. When using > 7B models, be sure to select an instance type that has at least 20GB of RAM for initial loading unless using a non-default QUANTIZE setting which reduces RAM usage | `string` | `"g4dn.xlarge"` | no |
| <a name="input_model_name"></a> [model\_name](#input\_model\_name) | The name of the model to load. Can be a MODEL\_ID as listed on <https://hf.co/models> like `gpt2` or `OpenAssistant/oasst-sft-1-pythia-12b`. Or it can be a local directory containing the necessary files as saved by `save_pretrained(...)` methods of transformers | `string` | `"teknium/OpenHermes-2.5-Mistral-7B"` | no |
| <a name="input_name"></a> [name](#input\_name) | Common name to use on all resources | `string` | `"text_generation_inference"` | no |
| <a name="input_nginx"></a> [nginx](#input\_nginx) | Map of values passed to nginx container definition. See the [ECS container definition module](https://github.com/terraform-aws-modules/terraform-aws-ecs/tree/master/modules/container-definition) for full list of arguments supported | `any` | `{}` | no |
| <a name="input_quantize"></a> [quantize](#input\_quantize) | Quantize the model to reduce memory usage. This can be useful for large models that don't fit in memory. The default is to not quantize the model | `string` | `null` | no |
| <a name="input_route53_record_name"></a> [route53\_record\_name](#input\_route53\_record\_name) | Name of Route53 record to create ACM certificate in and main A-record. If not specified var.name will be used. Required if create\_route53\_records is true | `string` | `null` | no |
| <a name="input_route53_zone_id"></a> [route53\_zone\_id](#input\_route53\_zone\_id) | ID of the Route53 zone in which to create records. Required if create\_route53\_records is true | `string` | `""` | no |
| <a name="input_route53_zone_name"></a> [route53\_zone\_name](#input\_route53\_zone\_name) | Name of the Route53 zone in which to create records. Required if create\_route53\_records is true | `string` | `""` | no |
| <a name="input_service"></a> [service](#input\_service) | Map of values passed to ECS service module definition. See the [ECS service module](https://github.com/terraform-aws-modules/terraform-aws-ecs/tree/master/modules/service) for full list of arguments supported | `any` | `{}` | no |
| <a name="input_service_subnets"></a> [service\_subnets](#input\_service\_subnets) | A list of subnets in which the ECS service for will be deployed | `list(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to add to all resources | `map(string)` | `{}` | no |
| <a name="input_text_generation_inference"></a> [text\_generation\_inference](#input\_text\_generation\_inference) | Configuration for the text generation inference | <pre>object({<br>    mount_points                           = optional(list(any), [])<br>    command                                = optional(list(string), [])<br>    cpu                                    = optional(number, null)<br>    dependencies                           = optional(list(map(string)), []) # depends_on is a reserved word<br>    disable_networking                     = optional(bool, null)<br>    dns_search_domains                     = optional(list(string), [])<br>    dns_servers                            = optional(list(string), [])<br>    docker_labels                          = optional(map(string), {})<br>    docker_security_options                = optional(list(string), [])<br>    enable_execute_command                 = optional(bool, false)<br>    entrypoint                             = optional(list(string), [])<br>    environment                            = optional(list(object({ name = string, value = string })), [])<br>    environment_files                      = optional(list(object({ value = string, type = string })), [])<br>    essential                              = optional(bool, true)<br>    extra_hosts                            = optional(list(object({ hostname = string, ipAddress = string })), [])<br>    firelens_configuration                 = optional(map(string), {})<br>    health_check                           = optional(map(string), {})<br>    hostname                               = optional(string, null)<br>    image_repo                             = optional(string, "ghcr.io/huggingface/text-generation-inference")<br>    image_version                          = optional(string, "latest")<br>    interactive                            = optional(bool, false)<br>    links                                  = optional(list(string), [])<br>    linux_parameters                       = optional(any, {})<br>    log_configuration                      = optional(map(string), {})<br>    memory                                 = optional(number, null)<br>    memory_reservation                     = optional(number, null)<br>    privileged                             = optional(bool, false)<br>    pseudo_terminal                        = optional(bool, false)<br>    readonly_root_filesystem               = optional(bool, false)<br>    repository_credentials                 = optional(map(string), {})<br>    resource_requirements                  = optional(list(object({ type = string, value = string })), [])<br>    secrets                                = optional(list(object({ name = string, valueFrom = string })), [])<br>    start_timeout                          = optional(number, 30)<br>    stop_timeout                           = optional(number, 120)<br>    system_controls                        = optional(list(map(string)), [])<br>    ulimits                                = optional(list(map(string)), [])<br>    user                                   = optional(string, null)<br>    volumes_from                           = optional(list(map(string)), [])<br>    working_directory                      = optional(string, null)<br>    enable_cloudwatch_logging              = optional(bool, true)<br>    create_cloudwatch_log_group            = optional(bool, true)<br>    cloudwatch_log_group_use_name_prefix   = optional(bool, true)<br>    cloudwatch_log_group_retention_in_days = optional(number, 14)<br>    cloudwatch_log_group_kms_key_id        = optional(string, null)<br>    port                                   = optional(number, 11434)<br>  })</pre> | n/a | yes |
| <a name="input_text_generation_inference_discovery_name"></a> [text\_generation\_inference\_discovery\_name](#input\_text\_generation\_inference\_discovery\_name) | Name of text-generation-inference used for service discovery | `string` | n/a | yes |
| <a name="input_text_generation_inference_discovery_namespace"></a> [text\_generation\_inference\_discovery\_namespace](#input\_text\_generation\_inference\_discovery\_namespace) | Namespace of text-generation-inference used for service discovery | `string` | n/a | yes |
| <a name="input_text_generation_inference_gid"></a> [text\_generation\_inference\_gid](#input\_text\_generation\_inference\_gid) | GID of the text\_generation\_inference user | `number` | `1000` | no |
| <a name="input_text_generation_inference_uid"></a> [text\_generation\_inference\_uid](#input\_text\_generation\_inference\_uid) | UID of the text\_generation\_inference user | `number` | `100` | no |
| <a name="input_use_spot_instances"></a> [use\_spot\_instances](#input\_use\_spot\_instances) | Determines whether to use spot instances for the ECS autoscaling group | `bool` | `false` | no |
| <a name="input_use_ssl_ui"></a> [use\_ssl\_ui](#input\_use\_ssl\_ui) | Create domain + certs for ssl connection to the UI. | `bool` | `true` | no |
| <a name="input_validate_certificate"></a> [validate\_certificate](#input\_validate\_certificate) | Determines whether to validate ACM certificate using Route53 DNS. If false, certificate will be created but not validated | `bool` | `true` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | ID of the VPC in which the resources will be created | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_arn"></a> [cluster\_arn](#output\_cluster\_arn) | n/a |
| <a name="output_ecs_service_security_group_id"></a> [ecs\_service\_security\_group\_id](#output\_ecs\_service\_security\_group\_id) | n/a |
| <a name="output_open_webui_ecs_service_security_group_id"></a> [open\_webui\_ecs\_service\_security\_group\_id](#output\_open\_webui\_ecs\_service\_security\_group\_id) | n/a |
| <a name="output_service_name"></a> [service\_name](#output\_service\_name) | n/a |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
