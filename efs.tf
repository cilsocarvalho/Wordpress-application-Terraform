# EFS
resource "aws_efs_file_system" "mission_app" {
  creation_token = "${var.namespace}-efs"
  encrypted      = true

  tags = {
    Name = "${var.namespace}-efs"
  }
}

resource "aws_efs_mount_target" "mission_app_targets" {
  count = length(local.vpc.azs)

  file_system_id  = aws_efs_file_system.mission_app.id
  subnet_id       = aws_subnet.private_ingress[count.index].id
  security_groups = [aws_security_group.nfs.id]
}