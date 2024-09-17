# Launch configuration
resource "aws_launch_template" "mission_app_lc" {
  name_prefix = "${var.namespace}-mission_app_iac_lc-"
  image_id    = aws_ami_copy.mission_app_ami.id

  instance_requirements {
    memory_mib {
      min = local.vm.instance_requirements.memory_mib.min
    }
    vcpu_count {
      min = local.vm.instance_requirements.vcpu_count.min
    }

    allowed_instance_types = ["m*"]
    instance_generations   = local.vm.instance_requirements.instance_generations
  }

  ebs_optimized          = true
  vpc_security_group_ids = [aws_security_group.app.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.web_hosting.name
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      delete_on_termination = true
      encrypted             = true
    }
  }

  monitoring {
    enabled = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 1
    http_tokens                 = "required"
    instance_metadata_tags      = "enabled"
  }

  user_data = base64encode(templatefile("${path.module}/userdata/staging-wordpress.sh", {
    region    = data.aws_region.current.name,
    efs_id    = aws_efs_file_system.mission_app.id,
    s3_bucket = aws_s3_bucket.mission_app.bucket
  }))

  update_default_version = true
}

resource "aws_autoscaling_group" "mission_app_asg" {
  name     = "${var.namespace}-asg-mission_app"
  min_size = 2
  max_size = 8

  vpc_zone_identifier = values(aws_subnet.private_ingress)[*].id
  target_group_arns   = [aws_lb_target_group.mission_app.arn]

  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.mission_app_lc.id
        version            = "$Latest"
      }
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  tag {
    key                 = "Name"
    value               = "${var.namespace}-asg-mission_app"
    propagate_at_launch = true
  }

  depends_on = [aws_instance.staging_app, aws_db_instance.wp_mysql]
}

resource "aws_autoscaling_policy" "mission_app_scale_out_policy" {
  name                   = "${var.namespace}-out-policy"
  scaling_adjustment     = 4
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.mission_app_asg.name
}

# ASG Cloudwatch policy
resource "aws_cloudwatch_metric_alarm" "mission_app_scale_out_alarm" {
  alarm_name          = "${var.namespace}-out-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "30"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.mission_app_asg.name
  }

  alarm_description = "This metric monitors ec2 cpu utilization for Mission App ASG"
  alarm_actions     = [aws_autoscaling_policy.mission_app_scale_out_policy.arn]
}

resource "aws_autoscaling_policy" "mission_app_scale_in_policy" {
  name                   = "${var.namespace}-in-policy"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 180
  autoscaling_group_name = aws_autoscaling_group.mission_app_asg.name
}

# ASG Cloudwatch policy
resource "aws_cloudwatch_metric_alarm" "mission_app_scale_in_alarm" {
  alarm_name          = "${var.namespace}-in-alarm"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "20"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.mission_app_asg.name
  }

  alarm_description = "This metric monitors ec2 cpu utilization for Mission App ASG"
  alarm_actions     = [aws_autoscaling_policy.mission_app_scale_in_policy.arn]
}