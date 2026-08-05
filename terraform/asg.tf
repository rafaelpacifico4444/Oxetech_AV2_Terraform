resource "aws_launch_template" "web" {
  iam_instance_profile {
    name = aws_iam_instance_profile.ssm.name
  }
  name_prefix   = "${var.project_name}-${var.environment}-lt-"
  image_id      = data.aws_ssm_parameter.ubuntu_2404.value
  instance_type = var.instance_type
  user_data = base64encode(templatefile("${path.module}/../scripts/user-data.sh", {
    flask_secret_key = var.flask_secret_key
    db_host          = aws_db_instance.lab.address
    db_name          = var.db_name
    db_user          = var.db_username
    db_password      = var.db_password
  }))

  vpc_security_group_ids = [aws_security_group.web.id]

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_type           = "gp3"
      volume_size           = 8
      encrypted             = true
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name           = "${var.project_name}-${var.environment}-web"
      ReleaseVersion = var.release_version
    }
  }

  lifecycle { create_before_destroy = true }
}

resource "aws_autoscaling_group" "web" {
  name_prefix         = "${var.project_name}-${var.environment}-asg-"
  vpc_zone_identifier = aws_subnet.public[*].id
  target_group_arns   = [aws_lb_target_group.web.arn]
  health_check_type   = "EC2"

  min_size         = var.asg_min_size
  max_size         = var.asg_max_size
  desired_capacity = var.asg_desired_capacity

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-${var.environment}-web"
    propagate_at_launch = true
  }

  tag {
    key                 = "ReleaseVersion"
    value               = var.release_version
    propagate_at_launch = true
  }

  lifecycle { create_before_destroy = true }
}
