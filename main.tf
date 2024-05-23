locals {
  text_generation_inference_port = try(var.text_generation_inference.port, 11434)
  nginx_port                     = try(var.nginx.port, 80)
}
