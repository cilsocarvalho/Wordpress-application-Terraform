resource "aws_s3_bucket" "mission_app" {
  bucket_prefix = "${var.namespace}-mission-app-"

  tags = {
    Description = "Used to store items"
  }
}

resource "aws_s3_bucket_public_access_block" "mission_app" {
  bucket = aws_s3_bucket.mission_app.bucket

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "mission_app-private_key" {
  bucket = aws_s3_bucket.mission_app.bucket

  key     = "server.key"
  content = tls_private_key.mission_app.private_key_pem
}

resource "aws_s3_object" "mission_app-public_key" {
  bucket = aws_s3_bucket.mission_app.bucket

  key     = "server.crt"
  content = tls_self_signed_cert.mission_app.cert_pem
}