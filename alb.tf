# Application Load Balancer
resource "aws_lb" "mission_app" {
  name               = "${var.namespace}-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = values(aws_subnet.private)[*].id

  tags = {
    Name = "${var.namespace}-lb"
  }

  security_groups = [aws_security_group.app.id]
}

resource "aws_lb_target_group" "mission_app" {
  name     = "${var.namespace}-lb-tg"
  port     = 443
  protocol = "HTTPS"
  vpc_id   = aws_vpc.default.id

  stickiness {
    type            = "lb_cookie"
    cookie_duration = 1800
    enabled         = true
  }

  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 10
    timeout             = 5
    interval            = 10
    path                = "/"
    port                = 443
    protocol            = "HTTPS"
  }
}

resource "aws_lb_listener" "mission_app_http" {
  load_balancer_arn = aws_lb.mission_app.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.mission_app.arn
  }
}

resource "aws_lb_listener_rule" "redirect_cloudfront_to_http" {
  listener_arn = aws_lb_listener.mission_app_http.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.mission_app.arn
  }

  condition {
    http_header {
      http_header_name = "X-Request"
      values           = [aws_lb.mission_app.dns_name]
    }
  }
}

resource "aws_lb_listener_rule" "redirect_http_to_https" {
  listener_arn = aws_lb_listener.mission_app_http.arn
  priority     = 200

  action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  condition {
    host_header {
      values = [aws_lb.mission_app.dns_name]
    }
  }
}

# Application Load Balancer (finishing touch)
resource "aws_lb_listener" "mission_app_https" {
  load_balancer_arn = aws_lb.mission_app.arn
  port              = "443"
  protocol          = "HTTPS"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.mission_app.arn
  }

  certificate_arn = aws_acm_certificate.mission_app_private.arn
}
