locals {
  # https://github.com/aws/amazon-ecs-agent/blob/master/README.md#environment-variables
  user_data = <<-EOT
    #!/bin/bash

    cat <<'EOF' >> /etc/ecs/ecs.config
    ECS_CLUSTER=${try(var.cluster.name, var.name)}
    ECS_LOGLEVEL=${try(var.cluster_agent_log_level, "info")}
    ECS_CONTAINER_INSTANCE_TAGS=${jsonencode(var.tags)}
    ECS_ENABLE_TASK_IAM_ROLE=true
    EOF
  EOT
}

# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-optimized_AMI.html#ecs-optimized-ami-linux
data "aws_ssm_parameter" "ecs_optimized_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/gpu/recommended"
}

module "autoscaling" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "~> 6.5"

  create = var.create_cluster

  name = try(var.autoscaling.name, "${var.name}-asg")

  image_id      = try(var.autoscaling.image_id, jsondecode(data.aws_ssm_parameter.ecs_optimized_ami.value)["image_id"])
  instance_type = try(var.autoscaling.instance_type, var.instance_type)

  security_groups                 = [module.autoscaling_sg.security_group_id]
  user_data                       = try(var.autoscaling.user_data, base64encode(local.user_data))
  ignore_desired_capacity_changes = try(var.autoscaling.ignore_desired_capacity_changes, true)

  create_iam_instance_profile = try(var.autoscaling.create_iam_instance_profile, true)
  iam_role_name               = try(var.autoscaling.iam_role_name, var.name)
  iam_role_description        = try(var.autoscaling.iam_role_description, "ECS role for ${var.name}")
  iam_role_policies = try(var.autoscaling.iam_role_policies, {
    AmazonEC2ContainerServiceforEC2Role = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
    AmazonSSMManagedInstanceCore        = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  })

  vpc_zone_identifier = try(var.autoscaling.vpc_zone_identifier, var.service_subnets)
  health_check_type   = try(var.autoscaling.health_check_type, "EC2")
  min_size            = try(var.autoscaling.min_size, 1)
  max_size            = try(var.autoscaling.max_size, 1)
  desired_capacity    = try(var.autoscaling.desired_capacity, 1)

  # https://github.com/hashicorp/terraform-provider-aws/issues/12582
  autoscaling_group_tags = {
    AmazonECSManaged = true
  }

  # Required for  managed_termination_protection = "ENABLED"
  protect_from_scale_in = try(var.autoscaling.protect_from_scale_in, true)

  # Spot instances
  use_mixed_instances_policy = try(var.autoscaling.use_mixed_instances_policy, false)
  mixed_instances_policy     = try(var.autoscaling.mixed_instances_policy, {})

  capacity_reservation_specification = try(var.autoscaling.capacity_reservation_specification, {
    capacity_reservation_preference = var.use_spot_instances ? "open" : "none"
  })

  credit_specification = try(var.autoscaling.credit_specification, {
    cpu_credits = "standard"
  })

  instance_market_options = try(var.autoscaling.instance_market_options, var.use_spot_instances ?
    {
      market_type = "spot"
      spot_options = {
        tags = var.tags
      }
  } : null)

  placement       = try(var.autoscaling.placement, {})
  placement_group = try(var.autoscaling.placement_group, null)

  create_scaling_policy = try(var.autoscaling.create_scaling_policy, true)
  scaling_policies      = try(var.autoscaling.scaling_policies, {})

  tags = var.tags
}

module "autoscaling_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  create = var.create_cluster

  name        = "${var.name}-asg-sg"
  description = "Autoscaling group security group for ${var.name} ECS cluster"
  vpc_id      = var.vpc_id

  computed_ingress_with_source_security_group_id = var.create_alb ? [
    {
      rule                     = "http-80-tcp"
      source_security_group_id = try(module.alb.security_group_id, var.alb_security_group_id)
    }
  ] : []
  number_of_computed_ingress_with_source_security_group_id = var.create_alb ? 1 : 0

  egress_rules = ["all-all"]

  tags = var.tags
}
