# Certificates
resource "tls_private_key" "mission_app" {
  algorithm = "RSA"
}

resource "tls_self_signed_cert" "mission_app" {
  private_key_pem = tls_private_key.mission_app.private_key_pem

  validity_period_hours = 8760

  # Generate a new certificate if Terraform is run within three
  # hours of the certificate's expiration time.
  early_renewal_hours = 3

  # Reasonable set of uses for a server SSL certificate.
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]

  dns_names = [
    aws_lb.mission_app.dns_name
  ]

  subject {
    common_name         = aws_lb.mission_app.dns_name
    organization        = "Amazon Web Services"
    organizational_unit = "WWPS ProServe"
    country             = "USA"
    locality            = "San Diego"
  }
}

resource "aws_acm_certificate" "mission_app_private" {
  private_key      = tls_private_key.mission_app.private_key_pem
  certificate_body = tls_self_signed_cert.mission_app.cert_pem
}
