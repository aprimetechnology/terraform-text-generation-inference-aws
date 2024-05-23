################################################################################
# EFS
################################################################################

locals {
  root_directory_path = "/open-webui"
}

module "efs" {
  source  = "terraform-aws-modules/efs/aws"
  version = "1.3.1"

  create = var.enable_efs
  name   = try(var.efs.name, var.name)

  # File system
  availability_zone_name          = try(var.efs.availability_zone_name, null)
  creation_token                  = try(var.efs.creation_token, var.name)
  performance_mode                = try(var.efs.performance_mode, null)
  encrypted                       = try(var.efs.encrypted, true)
  kms_key_arn                     = try(var.efs.kms_key_arn, null)
  provisioned_throughput_in_mibps = try(var.efs.provisioned_throughput_in_mibps, null)
  throughput_mode                 = try(var.efs.throughput_mode, null)
  lifecycle_policy                = try(var.efs.lifecycle_policy, {})

  # File system policy
  attach_policy                      = try(var.efs.attach_policy, true)
  bypass_policy_lockout_safety_check = try(var.efs.bypass_policy_lockout_safety_check, null)
  source_policy_documents            = try(var.efs.source_policy_documents, [])
  override_policy_documents          = try(var.efs.override_policy_documents, [])
  policy_statements = concat(
    [{
      actions = [
        "elasticfilesystem:ClientMount",
        "elasticfilesystem:ClientWrite",
      ]
      principals = [
        {
          type        = "AWS"
          identifiers = [module.ecs_service.tasks_iam_role_arn]
        }
      ]
    }],
    lookup(var.efs, "policy_statements", [])
  )
  deny_nonsecure_transport = try(var.efs.deny_nonsecure_transport, true)

  # Mount targets
  mount_targets = lookup(var.efs, "mount_targets", {})

  # Security group
  create_security_group          = try(var.efs.create_security_group, true)
  security_group_name            = try(var.efs.security_group_name, "${var.name}-efs-")
  security_group_use_name_prefix = try(var.efs.security_group_use_name_prefix, true)
  security_group_description     = try(var.efs.security_group_description, null)
  security_group_vpc_id          = try(var.efs.security_group_vpc_id, var.vpc_id)
  security_group_rules = merge(
    {
      open_webui = {
        # relying on the defaults provdied for EFS/NFS (2049/TCP + ingress)
        description              = "NFS ingress from Open WebUI"
        source_security_group_id = module.ecs_service.security_group_id
      }
    },
    lookup(var.efs, "security_group_rules", {})
  )

  # Access point(s)
  access_points = merge(
    {
      open_webui = {
        posix_user = {
          gid = var.open_webui_gid
          uid = var.open_webui_uid
        }
        root_directory = {
          path = local.root_directory_path
          creation_info = {
            owner_gid   = var.open_webui_gid
            owner_uid   = var.open_webui_uid
            permissions = "0750"
          }
        }
      }
    },
    lookup(var.efs, "access_points", {})
  )

  # Backup policy
  create_backup_policy = try(var.efs.create_backup_policy, false)
  enable_backup_policy = try(var.efs.enable_backup_policy, false)

  # Replication configuration
  create_replication_configuration      = try(var.efs.create_replication_configuration, false)
  replication_configuration_destination = try(var.efs.replication_configuration_destination, {})

  tags = var.tags
}
