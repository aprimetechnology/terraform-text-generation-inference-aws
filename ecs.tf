################################################################################
# ECS
################################################################################

locals {
  mount_path = "/data"
  mount_points = var.enable_efs ? [{
    containerPath = local.mount_path
    sourceVolume  = "efs"
    readOnly      = false
  }] : var.text_generation_inference.mount_points
  nginx_mount_points = concat(
    [{
      containerPath = "/etc/nginx/conf.d"
      sourceVolume  = "nginx_config"
      readOnly      = false
    }],
    lookup(var.nginx, "mount_points", [])
  )

  deployment_maximum_percent         = 100
  deployment_minimum_healthy_percent = 66

  nginx_task_cpu         = 1024
  nginx_task_memory      = 2048
  init_nginx_task_cpu    = 100
  init_nginx_task_memory = 128
  tasks_per_instance     = 1
  task_memory_buffer     = floor(data.aws_ec2_instance_type.cluster_autoscaler.memory_size * 0.1)
  task_memory_shared     = 1024 * 1 # 1 GB
  task_memory            = (data.aws_ec2_instance_type.cluster_autoscaler.memory_size - local.task_memory_buffer - local.task_memory_shared) / local.tasks_per_instance - local.nginx_task_memory
  task_cpu               = (data.aws_ec2_instance_type.cluster_autoscaler.default_vcpus * 1024) / local.tasks_per_instance - local.nginx_task_cpu - local.init_nginx_task_cpu
  service_memory         = local.task_memory + local.nginx_task_memory + local.init_nginx_task_memory
  service_cpu            = local.task_cpu + local.nginx_task_cpu + local.init_nginx_task_cpu

  nginx_config = <<EOF
server {
    listen ${local.nginx_port};

    location /v1/models {
        default_type application/json;
        return 200 '{ "object": "list", "data": [ { "id": "${var.model_name}", "object": "model", "created": ${time_static.activation_date.unix}, "owned_by": "system" } ]}';
    }

    location / {
        proxy_pass http://localhost:${var.text_generation_inference.port}/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

  default_autoscaling_capacity_providers = {
    "${var.name}-asg" = {
      auto_scaling_group_arn         = module.autoscaling.autoscaling_group_arn
      managed_termination_protection = "ENABLED"

      managed_scaling = {
        maximum_scaling_step_size = 2
        minimum_scaling_step_size = 1
        status                    = "ENABLED"
        target_capacity           = 100
      }

      default_capacity_provider_strategy = {
        weight = 0
      }
    }
  }
}

data "aws_ec2_instance_type" "cluster_autoscaler" {
  instance_type = var.instance_type
}

resource "time_static" "activation_date" {}

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
  default_capacity_provider_use_fargate = true
  autoscaling_capacity_providers        = local.default_autoscaling_capacity_providers
  fargate_capacity_providers            = try(var.cluster.fargate_capacity_providers, {})

  tags = var.tags
}

module "ecs_service" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "5.11.0"

  create = true

  # Service
  ignore_task_definition_changes = try(var.service.ignore_task_definition_changes, false)
  alarms                         = try(var.service.alarms, {})
  capacity_provider_strategy = try(var.service.capacity_provider_strategy, {
    try(var.autoscaling.name, "${var.name}-asg") = {
      capacity_provider = module.ecs_cluster.autoscaling_capacity_providers[try(var.autoscaling.name, "${var.name}-asg")].name
      weight            = 100
      base              = 1
    }
  })
  cluster_arn                        = var.create_cluster ? module.ecs_cluster.arn : var.cluster_arn
  deployment_controller              = try(var.service.deployment_controller, {})
  deployment_maximum_percent         = try(var.service.deployment_maximum_percent, local.deployment_maximum_percent)
  deployment_minimum_healthy_percent = try(var.service.deployment_minimum_healthy_percent, local.deployment_minimum_healthy_percent)
  desired_count                      = try(var.service.desired_count, 1)
  enable_ecs_managed_tags            = try(var.service.enable_ecs_managed_tags, true)
  enable_execute_command             = try(var.service.enable_execute_command, false)
  force_new_deployment               = try(var.service.force_new_deployment, true)
  health_check_grace_period_seconds  = try(var.service.health_check_grace_period_seconds, null)
  launch_type                        = try(var.service.launch_type, "EC2")
  load_balancer = merge(
    var.create_alb && var.alb_target_group_arn != null ? {
      service = {
        target_group_arn = var.create_alb ? module.alb.target_groups["text_generation_inference"].arn : var.alb_target_group_arn
        container_name   = "text_generation_inference"
        container_port   = local.text_generation_inference_port
      }
    } : {},
    lookup(var.service, "load_balancer", {})
  )
  name                       = try(var.service.name, var.name)
  assign_public_ip           = try(var.service.assign_public_ip, false)
  security_group_ids         = try(var.service.security_group_ids, [])
  subnet_ids                 = try(var.service.subnet_ids, var.service_subnets)
  ordered_placement_strategy = try(var.service.ordered_placement_strategy, {})
  placement_constraints = try(var.service.placement_constraints, local.tasks_per_instance == 1 ? [{
    type = "distinctInstance"
  }] : [])
  platform_version              = try(var.service.platform_version, null)
  propagate_tags                = try(var.service.propagate_tags, null)
  scheduling_strategy           = try(var.service.scheduling_strategy, null)
  service_connect_configuration = lookup(var.service, "service_connect_configuration", {})
  service_registries            = lookup(var.service, "service_registries", {})
  timeouts                      = try(var.service.timeouts, {})
  triggers                      = try(var.service.triggers, {})
  wait_for_steady_state         = try(var.service.wait_for_steady_state, null)

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
      init_nginx = {
        command                 = try(var.init_nginx.command, [])
        cpu                     = try(var.init_nginx.cpu, local.init_nginx_task_cpu)
        dependencies            = try(var.init_nginx.dependencies, []) # depends_on is a reserved word
        disable_networking      = try(var.init_nginx.disable_networking, null)
        dns_search_domains      = try(var.init_nginx.dns_search_domains, [])
        dns_servers             = try(var.init_nginx.dns_servers, [])
        docker_labels           = try(var.init_nginx.docker_labels, {})
        docker_security_options = try(var.init_nginx.docker_security_options, [])
        enable_execute_command  = try(var.init_nginx.enable_execute_command, try(var.service.enable_execute_command, false))
        entrypoint = try(var.init_nginx.entrypoint, [
          "bash",
          "-c",
          "set -ueo pipefail; mkdir -p /etc/nginx/conf.d/; echo ${base64encode(local.nginx_config)} | base64 -d > /etc/nginx/conf.d/default.conf; cat /etc/nginx/conf.d/default.conf",
        ])
        environment = concat(
          [],
          lookup(var.init_nginx, "environment", [])
        )
        environment_files        = try(var.init_nginx.environment_files, [])
        essential                = try(var.init_nginx.essential, false)
        extra_hosts              = try(var.init_nginx.extra_hosts, [])
        firelens_configuration   = try(var.init_nginx.firelens_configuration, {})
        health_check             = try(var.init_nginx.health_check, {})
        hostname                 = try(var.init_nginx.hostname, null)
        image                    = try(var.init_nginx.image, "public.ecr.aws/docker/library/bash:5")
        interactive              = try(var.init_nginx.interactive, false)
        links                    = try(var.init_nginx.links, [])
        linux_parameters         = try(var.init_nginx.linux_parameters, {})
        log_configuration        = lookup(var.init_nginx, "log_configuration", {})
        memory                   = try(var.init_nginx.memory, local.init_nginx_task_memory)
        memory_reservation       = try(var.init_nginx.memory_reservation, null)
        mount_points             = local.nginx_mount_points
        name                     = "init_nginx"
        port_mappings            = []
        privileged               = try(var.init_nginx.privileged, false)
        pseudo_terminal          = try(var.init_nginx.pseudo_terminal, false)
        readonly_root_filesystem = try(var.init_nginx.readonly_root_filesystem, false)
        repository_credentials   = try(var.init_nginx.repository_credentials, {})
        resource_requirements    = try(var.init_nginx.resource_requirements, [])
        secrets                  = try(var.init_nginx.secrets, [])
        start_timeout            = try(var.init_nginx.start_timeout, 30)
        stop_timeout             = try(var.init_nginx.stop_timeout, 120)
        system_controls          = try(var.init_nginx.system_controls, [])
        ulimits                  = try(var.init_nginx.ulimits, [])
        user                     = try(var.init_nginx.user, null)
        volumes_from             = try(var.init_nginx.volumes_from, [])
        working_directory        = try(var.init_nginx.working_directory, null)

        # CloudWatch Log Group
        service                                = var.name
        enable_cloudwatch_logging              = try(var.init_nginx.enable_cloudwatch_logging, true)
        create_cloudwatch_log_group            = try(var.init_nginx.create_cloudwatch_log_group, true)
        cloudwatch_log_group_use_name_prefix   = try(var.init_nginx.cloudwatch_log_group_use_name_prefix, true)
        cloudwatch_log_group_retention_in_days = try(var.init_nginx.cloudwatch_log_group_retention_in_days, 14)
        cloudwatch_log_group_kms_key_id        = try(var.init_nginx.cloudwatch_log_group_kms_key_id, null)
      }
      nginx = {
        command = try(var.nginx.command, [])
        cpu     = try(var.nginx.cpu, local.nginx_task_cpu)
        dependencies = try(var.nginx.dependencies, [
          {
            containerName = "init_nginx"
            condition     = "SUCCESS"
          }
        ]) # depends_on is a reserved word
        disable_networking      = try(var.nginx.disable_networking, null)
        dns_search_domains      = try(var.nginx.dns_search_domains, [])
        dns_servers             = try(var.nginx.dns_servers, [])
        docker_labels           = try(var.nginx.docker_labels, {})
        docker_security_options = try(var.nginx.docker_security_options, [])
        enable_execute_command  = try(var.nginx.enable_execute_command, try(var.service.enable_execute_command, false))
        entrypoint              = try(var.nginx.entrypoint, [])
        environment = concat(
          [],
          lookup(var.nginx, "environment", [])
        )
        environment_files      = try(var.nginx.environment_files, [])
        essential              = try(var.nginx.essential, true)
        extra_hosts            = try(var.nginx.extra_hosts, [])
        firelens_configuration = try(var.nginx.firelens_configuration, {})
        health_check           = try(var.nginx.health_check, {})
        hostname               = try(var.nginx.hostname, null)
        image                  = try(var.nginx.image, "nginx:stable-alpine")
        interactive            = try(var.nginx.interactive, false)
        links                  = try(var.nginx.links, [])
        linux_parameters       = try(var.nginx.linux_parameters, {})
        log_configuration      = lookup(var.nginx, "log_configuration", {})
        memory                 = try(var.nginx.memory, local.nginx_task_memory)
        memory_reservation     = try(var.nginx.memory_reservation, null)
        mount_points           = local.nginx_mount_points
        name                   = "nginx"
        port_mappings = [{
          name          = "http-proxy"
          containerPort = local.nginx_port
          hostPort      = local.nginx_port
          protocol      = "tcp"
        }]
        privileged               = try(var.nginx.privileged, false)
        pseudo_terminal          = try(var.nginx.pseudo_terminal, false)
        readonly_root_filesystem = try(var.nginx.readonly_root_filesystem, false)
        repository_credentials   = try(var.nginx.repository_credentials, {})
        resource_requirements    = try(var.nginx.resource_requirements, [])
        secrets                  = try(var.nginx.secrets, [])
        start_timeout            = try(var.nginx.start_timeout, 30)
        stop_timeout             = try(var.nginx.stop_timeout, 120)
        system_controls          = try(var.nginx.system_controls, [])
        ulimits                  = try(var.nginx.ulimits, [])
        user                     = try(var.nginx.user, null)
        volumes_from             = try(var.nginx.volumes_from, [])
        working_directory        = try(var.nginx.working_directory, null)

        # CloudWatch Log Group
        service                                = var.name
        enable_cloudwatch_logging              = try(var.nginx.enable_cloudwatch_logging, true)
        create_cloudwatch_log_group            = try(var.nginx.create_cloudwatch_log_group, true)
        cloudwatch_log_group_use_name_prefix   = try(var.nginx.cloudwatch_log_group_use_name_prefix, true)
        cloudwatch_log_group_retention_in_days = try(var.nginx.cloudwatch_log_group_retention_in_days, 14)
        cloudwatch_log_group_kms_key_id        = try(var.nginx.cloudwatch_log_group_kms_key_id, null)
      },
      text_generation_inference = {
        command                 = var.text_generation_inference.command
        cpu                     = var.text_generation_inference.cpu != null ? var.text_generation_inference.cpu : local.task_cpu
        dependencies            = var.text_generation_inference.dependencies
        disable_networking      = var.text_generation_inference.disable_networking
        dns_search_domains      = var.text_generation_inference.dns_search_domains
        dns_servers             = var.text_generation_inference.dns_servers
        docker_labels           = var.text_generation_inference.docker_labels
        docker_security_options = var.text_generation_inference.docker_security_options
        enable_execute_command  = var.text_generation_inference.enable_execute_command
        entrypoint              = var.text_generation_inference.entrypoint
        environment = concat(
          [
            {
              name  = "HUGGING_FACE_HUB_TOKEN"
              value = var.hugging_face_hub_token
            },
            {
              name  = "NUMBA_CACHE_DIR"
              value = "/tmp/numba_cache"
            },
            {
              name  = "MODEL_ID"
              value = var.model_name
            },
            {
              name  = "PORT"
              value = local.text_generation_inference_port
            },
          ],
          var.quantize != null ? [
            {
              name  = "QUANTIZE"
              value = var.quantize
            }
          ] : [],
          var.dtype != null ? [
            {
              name  = "DTYPE"
              value = var.dtype
            }
          ] : [],
          lookup(var.text_generation_inference, "environment", [])
        )
        environment_files      = var.text_generation_inference.environment_files
        essential              = var.text_generation_inference.essential
        extra_hosts            = var.text_generation_inference.extra_hosts
        firelens_configuration = var.text_generation_inference.firelens_configuration
        health_check           = var.text_generation_inference.health_check
        hostname               = var.text_generation_inference.hostname
        image                  = "${var.text_generation_inference.image_repo}:${var.text_generation_inference.image_version}"
        interactive            = var.text_generation_inference.interactive
        links                  = var.text_generation_inference.links
        linux_parameters = length(var.text_generation_inference.linux_parameters) > 0 ? var.text_generation_inference.linux_parameters : {
          sharedMemorySize = local.task_memory_shared
        }
        log_configuration  = var.text_generation_inference.log_configuration
        memory             = var.text_generation_inference.memory != null ? var.text_generation_inference.memory : local.task_memory
        memory_reservation = var.text_generation_inference.memory_reservation != null ? var.text_generation_inference.memory_reservation : local.task_memory / 2
        mount_points       = local.mount_points
        name               = "text_generation_inference"
        port_mappings = [{
          name          = "http"
          containerPort = local.text_generation_inference_port
          hostPort      = local.text_generation_inference_port
          protocol      = "tcp"
        }]
        privileged               = var.text_generation_inference.privileged
        pseudo_terminal          = var.text_generation_inference.pseudo_terminal
        readonly_root_filesystem = var.text_generation_inference.readonly_root_filesystem
        repository_credentials   = var.text_generation_inference.repository_credentials
        resource_requirements = concat(
          [
            {
              type  = "GPU"
              value = one(data.aws_ec2_instance_type.cluster_autoscaler.gpus[*].count)
            }
          ],
          lookup(var.text_generation_inference, "resource_requirements", [])
        )
        secrets           = var.text_generation_inference.secrets
        start_timeout     = var.text_generation_inference.start_timeout
        stop_timeout      = var.text_generation_inference.stop_timeout
        system_controls   = var.text_generation_inference.system_controls
        ulimits           = var.text_generation_inference.ulimits
        user              = var.text_generation_inference.user != null ? var.text_generation_inference.user : "${var.text_generation_inference_uid}:${var.text_generation_inference_gid}"
        volumes_from      = var.text_generation_inference.volumes_from
        working_directory = var.text_generation_inference.working_directory

        # CloudWatch Log Group
        service                                = var.name
        enable_cloudwatch_logging              = var.text_generation_inference.enable_cloudwatch_logging
        create_cloudwatch_log_group            = var.text_generation_inference.create_cloudwatch_log_group
        cloudwatch_log_group_use_name_prefix   = var.text_generation_inference.cloudwatch_log_group_use_name_prefix
        cloudwatch_log_group_retention_in_days = var.text_generation_inference.cloudwatch_log_group_retention_in_days
        cloudwatch_log_group_kms_key_id        = var.text_generation_inference.cloudwatch_log_group_kms_key_id
      },
    },
    lookup(var.service, "container_definitions", {})
  )
  container_definition_defaults         = lookup(var.service, "container_definition_defaults", {})
  cpu                                   = try(var.service.cpu, local.service_cpu)
  ephemeral_storage                     = try(var.service.ephemeral_storage, {})
  family                                = try(var.service.family, null)
  inference_accelerator                 = try(var.service.inference_accelerator, {})
  ipc_mode                              = try(var.service.ipc_mode, null)
  memory                                = try(var.service.memory, local.service_memory)
  network_mode                          = try(var.service.network_mode, "awsvpc")
  pid_mode                              = try(var.service.pid_mode, null)
  task_definition_placement_constraints = try(var.service.task_definition_placement_constraints, {})
  proxy_configuration                   = try(var.service.proxy_configuration, {})
  requires_compatibilities              = try(var.service.requires_compatibilities, ["EC2"])
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
            access_point_id = try(module.efs.access_points["text_generation_inference"].id, null)
            iam             = "ENABLED"
          }
        }
      },
      nginx_config = {}
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
  force_delete              = try(var.service.force_delete, null)
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
    var.create_alb && var.alb_security_group_id != "" ? {
      text_generation_inference = {
        type                     = "ingress"
        from_port                = local.text_generation_inference_port
        to_port                  = local.text_generation_inference_port
        protocol                 = "tcp"
        source_security_group_id = var.create_alb ? module.alb.security_group_id : var.alb_security_group_id
      }
    } : {},
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
