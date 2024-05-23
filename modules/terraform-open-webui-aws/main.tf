locals {
  # OpenWebUI
  open_webui_url = "https://${try(coalesce(
    try(var.open_webui.fqdn, module.alb.route53_records["A"].fqdn, null),
    module.alb.dns_name,
  ), "")}"

  open_webui_port = try(var.open_webui.port, 8080)
}
