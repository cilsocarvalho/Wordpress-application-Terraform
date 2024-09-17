resource "aws_cloudfront_distribution" "mission_app" {
  enabled = true
  comment = "${var.namespace} - frontend site for mission app"

  origin {
    domain_name = aws_lb.mission_app.dns_name
    origin_id   = aws_lb.mission_app.dns_name
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }

    custom_header {
      name  = "X-Request"
      value = aws_lb.mission_app.dns_name
    }
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    target_origin_id       = aws_lb.mission_app.dns_name
    viewer_protocol_policy = "redirect-to-https"
    cache_policy_id        = aws_cloudfront_cache_policy.default.id
  }

  # https://en.wikipedia.org/wiki/List_of_ISO_3166_country_codes
  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

resource "aws_cloudfront_cache_policy" "default" {
  name        = "${var.namespace}-default-policy"
  comment     = "Default Policy"
  default_ttl = 50
  max_ttl     = 100
  min_ttl     = 1

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "all"
    }
    headers_config {
      header_behavior = "whitelist"
      headers {
        items = ["X-Request"]
      }
    }
    query_strings_config {
      query_string_behavior = "all"
    }
  }
}