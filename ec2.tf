resource "aws_instance" "staging_app" {

  lifecycle {
    prevent_destroy = false
    ignore_changes  = [iam_instance_profile, tags, tags_all]
  }

  ami                         = data.aws_ami.linux.image_id
  instance_type               = local.vm.instance_type
  subnet_id                   = aws_subnet.private_ingress[0].id
  user_data_replace_on_change = true

  user_data = templatefile("${path.module}/userdata/staging-efs.sh", {
    region        = data.aws_region.current.name,
    efs_id        = aws_efs_file_system.mission_app.id
    db_name       = aws_db_instance.wp_mysql.db_name
    db_username   = aws_db_instance.wp_mysql.username
    db_password   = aws_db_instance.wp_mysql.password
    db_host       = aws_db_instance.wp_mysql.address
    DOMAIN_NAME   = aws_cloudfront_distribution.mission_app.domain_name
    demo_username = local.demo.admin.username
    demo_password = local.demo.admin.password
    demo_email    = local.demo.admin.email
  })

  iam_instance_profile   = aws_iam_instance_profile.app.name
  availability_zone      = data.aws_availability_zones.available.names[0]
  vpc_security_group_ids = [aws_security_group.app.id]

  metadata_options {
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 1
    http_tokens                 = "required"
    instance_metadata_tags      = "enabled"
  }

  root_block_device {
    delete_on_termination = true
    encrypted             = true
  }

  tags = {
    Name = format("${var.namespace}-staging_app-%s", element(data.aws_availability_zones.available.names, 0))
  }

  depends_on = [aws_s3_object.mission_app-private_key, aws_s3_object.mission_app-public_key]
}

resource "aws_ami_copy" "mission_app_ami" {
  name              = "Amazon Linux 2 Image"
  description       = "A copy of ${data.aws_ami.linux.image_id} - ${data.aws_ami.linux.description}"
  source_ami_id     = data.aws_ami.linux.image_id
  source_ami_region = data.aws_region.current.name

  tags = {
    Name               = "${var.namespace}-ami"
    Description        = data.aws_ami.linux.description
    "Creation Date"    = data.aws_ami.linux.creation_date
    "Deprecation Time" = data.aws_ami.linux.deprecation_time
  }
}