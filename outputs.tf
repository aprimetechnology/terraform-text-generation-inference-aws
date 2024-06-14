output "cluster_arn" {
  value = try(module.ecs_cluster.arn, var.cluster_arn)
}

output "service_name" {
  value = module.ecs_service.name
}

output "ecs_service_security_group_id" {
  value = module.ecs_service.security_group_id
}

output "open_webui_ecs_service_security_group_id" {
  value = var.create_ui ? module.open_webui[0].ecs_service_security_group_id : null
}

output "alb_dns_name" {
  description = "The DNS name of the load balancer"
  value       = var.create_ui ? module.open_webui[0].alb_dns_name : null
}

output "ui_url" {
  description = "The UI url if a domain was given"
  value       = var.create_ui && var.use_ssl_ui ? local.domain_name : ""
}
