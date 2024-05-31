################################################################################
# ECS
################################################################################

locals {
  mount_path = "/app/backend/data"
  mount_points = var.enable_efs ? [{
    containerPath = local.mount_path
    sourceVolume  = "efs"
    readOnly      = false
  }] : try(var.open_webui.mount_points, [])

  deployment_maximum_percent         = 100
  deployment_minimum_healthy_percent = 66
}

module "ecs_cluster" {
  source  = "terraform-aws-modules/ecs/aws//modules/cluster"
  version = "5.11.0"

  create = var.create_cluster

  # Cluster
  cluster_name          = try(var.cluster.name, var.name)
  cluster_configuration = try(var.cluster.configuration, {})
  cluster_settings = try(var.cluster.settings, {
    name  = "containerInsights"
    value = "enabled"
    }
  )

  # Cloudwatch log group
  create_cloudwatch_log_group            = try(var.cluster.create_cloudwatch_log_group, true)
  cloudwatch_log_group_retention_in_days = try(var.cluster.cloudwatch_log_group_retention_in_days, 90)
  cloudwatch_log_group_kms_key_id        = try(var.cluster.cloudwatch_log_group_kms_key_id, null)
  cloudwatch_log_group_tags              = try(var.cluster.cloudwatch_log_group_tags, {})

  # Capacity providers
  fargate_capacity_providers = try(var.cluster.fargate_capacity_providers, {})

  tags = var.tags
}

module "ecs_service" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "5.11.0"

  create = true

  # Service
  ignore_task_definition_changes     = try(var.service.ignore_task_definition_changes, false)
  alarms                             = try(var.service.alarms, {})
  capacity_provider_strategy         = try(var.service.capacity_provider_strategy, {})
  cluster_arn                        = var.create_cluster ? module.ecs_cluster.arn : var.cluster_arn
  deployment_controller              = try(var.service.deployment_controller, {})
  deployment_maximum_percent         = try(var.service.deployment_maximum_percent, local.deployment_maximum_percent)
  deployment_minimum_healthy_percent = try(var.service.deployment_minimum_healthy_percent, local.deployment_minimum_healthy_percent)
  desired_count                      = try(var.service.desired_count, 1)
  enable_ecs_managed_tags            = try(var.service.enable_ecs_managed_tags, true)
  enable_execute_command             = try(var.service.enable_execute_command, false)
  force_new_deployment               = try(var.service.force_new_deployment, true)
  health_check_grace_period_seconds  = try(var.service.health_check_grace_period_seconds, null)
  launch_type                        = try(var.service.launch_type, "FARGATE")
  load_balancer = merge(
    var.create_alb && var.alb_target_group_arn != null ? {
      service = {
        target_group_arn = var.create_alb ? module.alb.target_groups["open_webui"].arn : var.alb_target_group_arn
        container_name   = "open_webui"
        container_port   = local.open_webui_port
      }
    } : {},
    lookup(var.service, "load_balancer", {})
  )
  name                          = try(var.service.name, var.name)
  assign_public_ip              = try(var.service.assign_public_ip, false)
  security_group_ids            = try(var.service.security_group_ids, [])
  subnet_ids                    = try(var.service.subnet_ids, var.service_subnets)
  ordered_placement_strategy    = try(var.service.ordered_placement_strategy, {})
  placement_constraints         = try(var.service.placement_constraints, {})
  platform_version              = try(var.service.platform_version, null)
  propagate_tags                = try(var.service.propagate_tags, null)
  scheduling_strategy           = try(var.service.scheduling_strategy, null)
  service_connect_configuration = lookup(var.service, "service_connect_configuration", {})
  service_registries            = lookup(var.service, "service_registries", {})
  timeouts                      = try(var.service.timeouts, {})
  triggers                      = try(var.service.triggers, {})
  wait_for_steady_state         = try(var.service.wait_for_steady_state, true)

  # Service IAM role
  create_iam_role               = try(var.service.create_iam_role, true)
  iam_role_arn                  = try(var.service.iam_role_arn, null)
  iam_role_name                 = try(var.service.iam_role_name, null)
  iam_role_use_name_prefix      = try(var.service.iam_role_use_name_prefix, true)
  iam_role_path                 = try(var.service.iam_role_path, null)
  iam_role_description          = try(var.service.iam_role_description, null)
  iam_role_permissions_boundary = try(var.service.iam_role_permissions_boundary, null)
  iam_role_tags                 = try(var.service.iam_role_tags, {})
  iam_role_statements           = lookup(var.service, "iam_role_statements", {})

  # Task definition
  create_task_definition = try(var.service.create_task_definition, true)
  task_definition_arn    = try(var.service.task_definition_arn, null)
  container_definitions = merge(
    {
      open_webui = {
        command                 = try(var.open_webui.command, [])
        cpu                     = try(var.open_webui.cpu, 1024)
        dependencies            = try(var.open_webui.dependencies, []) # depends_on is a reserved word
        disable_networking      = try(var.open_webui.disable_networking, null)
        dns_search_domains      = try(var.open_webui.dns_search_domains, [])
        dns_servers             = try(var.open_webui.dns_servers, [])
        docker_labels           = try(var.open_webui.docker_labels, {})
        docker_security_options = try(var.open_webui.docker_security_options, [])
        enable_execute_command  = try(var.open_webui.enable_execute_command, try(var.service.enable_execute_command, false))
        entrypoint              = try(var.open_webui.entrypoint, [])
        environment = concat(
          [
            {
              name  = "WEBUI_URL"
              value = local.open_webui_url
            },
            {
              name  = "PORT"
              value = local.open_webui_port
            },
            {
              name  = "OPENAI_API_KEY"
              value = var.openai_api_key
            },
            {
              name  = "OPENAI_API_BASE_URL"
              value = var.openai_api_base_url
            },
          ],
          lookup(var.open_webui, "environment", [])
        )
        environment_files      = try(var.open_webui.environment_files, [])
        essential              = try(var.open_webui.essential, true)
        extra_hosts            = try(var.open_webui.extra_hosts, [])
        firelens_configuration = try(var.open_webui.firelens_configuration, {})
        health_check           = try(var.open_webui.health_check, {})
        hostname               = try(var.open_webui.hostname, null)
        image                  = try(var.open_webui.image, "ghcr.io/open-webui/open-webui:${var.open_webui_version}")
        interactive            = try(var.open_webui.interactive, false)
        links                  = try(var.open_webui.links, [])
        linux_parameters       = try(var.open_webui.linux_parameters, {})
        log_configuration      = lookup(var.open_webui, "log_configuration", {})
        memory                 = try(var.open_webui.memory, 2048)
        memory_reservation     = try(var.open_webui.memory_reservation, null)
        mount_points           = local.mount_points
        name                   = "open_webui"
        port_mappings = [{
          name          = "open_webui"
          containerPort = local.open_webui_port
          hostPort      = local.open_webui_port
          protocol      = "tcp"
        }]
        privileged               = try(var.open_webui.privileged, false)
        pseudo_terminal          = try(var.open_webui.pseudo_terminal, false)
        readonly_root_filesystem = try(var.open_webui.readonly_root_filesystem, false)
        repository_credentials   = try(var.open_webui.repository_credentials, {})
        resource_requirements    = try(var.open_webui.resource_requirements, [])
        secrets                  = try(var.open_webui.secrets, [])
        start_timeout            = try(var.open_webui.start_timeout, 30)
        stop_timeout             = try(var.open_webui.stop_timeout, 120)
        system_controls          = try(var.open_webui.system_controls, [])
        ulimits                  = try(var.open_webui.ulimits, [])
        user                     = try(var.open_webui.user, "${var.open_webui_uid}:${var.open_webui_gid}")
        volumes_from             = try(var.open_webui.volumes_from, [])
        working_directory        = try(var.open_webui.working_directory, null)

        # CloudWatch Log Group
        service                                = var.name
        enable_cloudwatch_logging              = try(var.open_webui.enable_cloudwatch_logging, true)
        create_cloudwatch_log_group            = try(var.open_webui.create_cloudwatch_log_group, true)
        cloudwatch_log_group_use_name_prefix   = try(var.open_webui.cloudwatch_log_group_use_name_prefix, true)
        cloudwatch_log_group_retention_in_days = try(var.open_webui.cloudwatch_log_group_retention_in_days, 14)
        cloudwatch_log_group_kms_key_id        = try(var.open_webui.cloudwatch_log_group_kms_key_id, null)
      },
    },
    lookup(var.service, "container_definitions", {})
  )
  container_definition_defaults         = lookup(var.service, "container_definition_defaults", {})
  cpu                                   = try(var.service.cpu, 1024)
  ephemeral_storage                     = try(var.service.ephemeral_storage, {})
  family                                = try(var.service.family, null)
  inference_accelerator                 = try(var.service.inference_accelerator, {})
  ipc_mode                              = try(var.service.ipc_mode, null)
  memory                                = try(var.service.memory, 2048)
  network_mode                          = try(var.service.network_mode, "awsvpc")
  pid_mode                              = try(var.service.pid_mode, null)
  task_definition_placement_constraints = try(var.service.task_definition_placement_constraints, {})
  proxy_configuration                   = try(var.service.proxy_configuration, {})
  requires_compatibilities              = try(var.service.requires_compatibilities, ["FARGATE"])
  runtime_platform = try(var.service.runtime_platform, {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  })
  skip_destroy = try(var.service.skip_destroy, null)
  volume = { for k, v in merge(
    {
      efs = {
        efs_volume_configuration = {
          file_system_id     = module.efs.id
          transit_encryption = "ENABLED"
          authorization_config = {
            access_point_id = try(module.efs.access_points["open_webui"].id, null)
            iam             = "ENABLED"
          }
        }
      }
    },
    lookup(var.service, "volume", {})
  ) : k => v if var.enable_efs }
  task_tags = try(var.service.task_tags, {})

  # Task execution IAM role
  create_task_exec_iam_role               = try(var.service.create_task_exec_iam_role, true)
  task_exec_iam_role_arn                  = try(var.service.task_exec_iam_role_arn, null)
  task_exec_iam_role_name                 = try(var.service.task_exec_iam_role_name, null)
  task_exec_iam_role_use_name_prefix      = try(var.service.task_exec_iam_role_use_name_prefix, true)
  task_exec_iam_role_path                 = try(var.service.task_exec_iam_role_path, null)
  task_exec_iam_role_description          = try(var.service.task_exec_iam_role_description, null)
  task_exec_iam_role_permissions_boundary = try(var.service.task_exec_iam_role_permissions_boundary, null)
  task_exec_iam_role_tags                 = try(var.service.task_exec_iam_role_tags, {})
  task_exec_iam_role_policies             = lookup(var.service, "task_exec_iam_role_policies", {})
  task_exec_iam_role_max_session_duration = try(var.service.task_exec_iam_role_max_session_duration, null)

  # Task execution IAM role policy
  create_task_exec_policy  = try(var.service.create_task_exec_policy, true)
  task_exec_ssm_param_arns = try(var.service.task_exec_ssm_param_arns, ["arn:aws:ssm:*:*:parameter/*"])
  task_exec_secret_arns    = try(var.service.task_exec_secret_arns, ["arn:aws:secretsmanager:*:*:secret:*"])
  task_exec_iam_statements = lookup(var.service, "task_exec_iam_statements", {})

  # Tasks - IAM role
  create_tasks_iam_role               = try(var.service.create_tasks_iam_role, true)
  tasks_iam_role_arn                  = try(var.service.tasks_iam_role_arn, null)
  tasks_iam_role_name                 = try(var.service.tasks_iam_role_name, null)
  tasks_iam_role_use_name_prefix      = try(var.service.tasks_iam_role_use_name_prefix, true)
  tasks_iam_role_path                 = try(var.service.tasks_iam_role_path, null)
  tasks_iam_role_description          = try(var.service.tasks_iam_role_description, null)
  tasks_iam_role_permissions_boundary = try(var.service.tasks_iam_role_permissions_boundary, null)
  tasks_iam_role_tags                 = try(var.service.tasks_iam_role_tags, {})
  tasks_iam_role_policies             = lookup(var.service, "tasks_iam_role_policies", {})
  tasks_iam_role_statements           = lookup(var.service, "tasks_iam_role_statements", {})

  # Task set
  external_id               = try(var.service.external_id, null)
  scale                     = try(var.service.scale, {})
  force_delete              = try(var.service.force_delete, true)
  wait_until_stable         = try(var.service.wait_until_stable, null)
  wait_until_stable_timeout = try(var.service.wait_until_stable_timeout, null)

  # Autoscaling
  enable_autoscaling            = try(var.service.enable_autoscaling, false)
  autoscaling_min_capacity      = try(var.service.autoscaling_min_capacity, 1)
  autoscaling_max_capacity      = try(var.service.autoscaling_max_capacity, 10)
  autoscaling_policies          = try(var.service.autoscaling_policies, {})
  autoscaling_scheduled_actions = try(var.service.autoscaling_scheduled_actions, {})

  # Security Group
  create_security_group          = try(var.service.create_security_group, true)
  security_group_name            = try(var.service.security_group_name, null)
  security_group_use_name_prefix = try(var.service.security_group_use_name_prefix, true)
  security_group_description     = try(var.service.security_group_description, null)
  security_group_rules = merge(
    {
      open_webui = {
        type                     = "ingress"
        from_port                = local.open_webui_port
        to_port                  = local.open_webui_port
        protocol                 = "tcp"
        source_security_group_id = var.create_alb ? module.alb.security_group_id : var.alb_security_group_id
      }
    },
    lookup(var.service, "security_group_rules", {
      egress = {
        type        = "egress"
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
      }
    })
  )
  security_group_tags = try(var.service.security_group_tags, {})

  tags = var.tags
}
