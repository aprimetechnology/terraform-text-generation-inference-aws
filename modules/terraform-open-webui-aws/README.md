# terraform-open-webui-aws

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_acm"></a> [acm](#module\_acm) | terraform-aws-modules/acm/aws | 5.0.0 |
| <a name="module_alb"></a> [alb](#module\_alb) | terraform-aws-modules/alb/aws | 9.1.0 |
| <a name="module_ecs_cluster"></a> [ecs\_cluster](#module\_ecs\_cluster) | terraform-aws-modules/ecs/aws//modules/cluster | 5.11.0 |
| <a name="module_ecs_service"></a> [ecs\_service](#module\_ecs\_service) | terraform-aws-modules/ecs/aws//modules/service | 5.11.0 |
| <a name="module_efs"></a> [efs](#module\_efs) | terraform-aws-modules/efs/aws | 1.3.1 |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alb"></a> [alb](#input\_alb) | Map of values passed to ALB module definition. See the [ALB module](https://github.com/terraform-aws-modules/terraform-aws-alb) for full list of supported arguments | `any` | `{}` | no |
| <a name="input_alb_http_default_action"></a> [alb\_http\_default\_action](#input\_alb\_http\_default\_action) | Default action for ALB HTTP listener | `any` | <pre>{<br>  "forward": {<br>    "target_group_key": "open_webui"<br>  }<br>}</pre> | no |
| <a name="input_alb_https_default_action"></a> [alb\_https\_default\_action](#input\_alb\_https\_default\_action) | Default action for ALB HTTPS listener | `any` | <pre>{<br>  "forward": {<br>    "target_group_key": "open_webui"<br>  }<br>}</pre> | no |
| <a name="input_alb_security_group_id"></a> [alb\_security\_group\_id](#input\_alb\_security\_group\_id) | ID of an existing security group to attach to the ALB. Required if `create_alb` is `false` | `string` | `""` | no |
| <a name="input_alb_subnets"></a> [alb\_subnets](#input\_alb\_subnets) | A list of subnets in which the ALB will be deployed. Required if `create_alb` is `true` | `list(string)` | `[]` | no |
| <a name="input_alb_target_group_arn"></a> [alb\_target\_group\_arn](#input\_alb\_target\_group\_arn) | ARN of an existing ALB target group that will be used to route traffic to the OpenWebUi service. Required if `create_alb` is `false` | `string` | `""` | no |
| <a name="input_alb_use_https"></a> [alb\_use\_https](#input\_alb\_use\_https) | Determines whether to use https for the alb. | `bool` | `true` | no |
| <a name="input_certificate_arn"></a> [certificate\_arn](#input\_certificate\_arn) | ARN of an existing ACM certificate to use with the ALB. If not provided, a new certificate will be created. Required if `create_alb` is `true` and `create_certificate` is `false` | `string` | `""` | no |
| <a name="input_certificate_domain_name"></a> [certificate\_domain\_name](#input\_certificate\_domain\_name) | Route53 domain name to use for ACM certificate. Route53 zone for this domain should be created in advance. | `string` | `""` | no |
| <a name="input_cluster"></a> [cluster](#input\_cluster) | Map of values passed to ECS cluster module definition. See the [ECS cluster module](https://github.com/terraform-aws-modules/terraform-aws-ecs/tree/master/modules/cluster) for full list of supported arguments | `any` | `{}` | no |
| <a name="input_cluster_arn"></a> [cluster\_arn](#input\_cluster\_arn) | ARN of the ECS cluster in which the service will be deployed. Required if create\_cluster is false | `string` | `null` | no |
| <a name="input_create_alb"></a> [create\_alb](#input\_create\_alb) | Determines whether to create an Application Load Balancer for the ECS service | `bool` | `true` | no |
| <a name="input_create_certificate"></a> [create\_certificate](#input\_create\_certificate) | Determines whether to create an ACM certificate for the ALB | `bool` | `true` | no |
| <a name="input_create_cluster"></a> [create\_cluster](#input\_create\_cluster) | Determines whether to create an ECS cluster for the service | `bool` | `true` | no |
| <a name="input_create_route53_records"></a> [create\_route53\_records](#input\_create\_route53\_records) | Determines whether to create Route53 records for the ALB | `bool` | `true` | no |
| <a name="input_efs"></a> [efs](#input\_efs) | Map of values passed to EFS module definition. See the [EFS module](https://github.com/terraform-aws-modules/terraform-aws-efs) for full list of arguments supported | `any` | `{}` | no |
| <a name="input_enable_efs"></a> [enable\_efs](#input\_enable\_efs) | Determines whether to create an EFS volume for the ECS service, this is used for model storage if enabled | `bool` | `false` | no |
| <a name="input_name"></a> [name](#input\_name) | Common name to use on all resources | `string` | `"open-web-ui"` | no |
| <a name="input_open_webui"></a> [open\_webui](#input\_open\_webui) | Map of values passed to OpenWebUI container definition. See the [ECS container definition module](https://github.com/terraform-aws-modules/terraform-aws-ecs/tree/master/modules/container-definition) for full list of arguments supported | `any` | `{}` | no |
| <a name="input_open_webui_gid"></a> [open\_webui\_gid](#input\_open\_webui\_gid) | GID of the open\_webui user | `number` | `1000` | no |
| <a name="input_open_webui_uid"></a> [open\_webui\_uid](#input\_open\_webui\_uid) | UID of the open\_webui user | `number` | `100` | no |
| <a name="input_open_webui_version"></a> [open\_webui\_version](#input\_open\_webui\_version) | Version of the OpenWebUI container to deploy | `string` | `"main"` | no |
| <a name="input_openai_api_base_url"></a> [openai\_api\_base\_url](#input\_openai\_api\_base\_url) | OpenAI API base URL | `string` | `null` | no |
| <a name="input_openai_api_key"></a> [openai\_api\_key](#input\_openai\_api\_key) | OpenAI API key | `string` | `""` | no |
| <a name="input_route53_record_name"></a> [route53\_record\_name](#input\_route53\_record\_name) | Name of Route53 record to create ACM certificate in and main A-record. If not specified var.name will be used. Required if create\_route53\_records is true | `string` | `null` | no |
| <a name="input_route53_zone_id"></a> [route53\_zone\_id](#input\_route53\_zone\_id) | ID of the Route53 zone in which to create records. Required if create\_route53\_records is true | `string` | `""` | no |
| <a name="input_service"></a> [service](#input\_service) | Map of values passed to ECS service module definition. See the [ECS service module](https://github.com/terraform-aws-modules/terraform-aws-ecs/tree/master/modules/service) for full list of arguments supported | `any` | `{}` | no |
| <a name="input_service_subnets"></a> [service\_subnets](#input\_service\_subnets) | A list of subnets in which the ECS service for will be deployed | `list(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to add to all resources | `map(string)` | `{}` | no |
| <a name="input_validate_certificate"></a> [validate\_certificate](#input\_validate\_certificate) | Determines whether to validate ACM certificate using Route53 DNS. If false, certificate will be created but not validated | `bool` | `true` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | ID of the VPC in which the resources will be created | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_alb_dns_name"></a> [alb\_dns\_name](#output\_alb\_dns\_name) | The DNS name of the load balancer |
| <a name="output_cluster_arn"></a> [cluster\_arn](#output\_cluster\_arn) | n/a |
| <a name="output_ecs_service_security_group_id"></a> [ecs\_service\_security\_group\_id](#output\_ecs\_service\_security\_group\_id) | n/a |
| <a name="output_service_name"></a> [service\_name](#output\_service\_name) | n/a |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
