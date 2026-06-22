# static-website module
# Creates S3 bucket + CloudFront distribution for hosting
# the WHATS'ON Dashboard frontend.

# Random suffix for globally unique bucket name

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# S3 Bucket

resource "aws_s3_bucket" "frontend" {
  bucket = "${var.bucket_name_prefix}-${random_id.bucket_suffix.hex}"

  tags = merge(var.tags, {
    Name = "${var.bucket_name_prefix}-${random_id.bucket_suffix.hex}"
  })
}

# Block all public access — CloudFront accesses via OAC, not public URL
resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Server-side encryption (AWS-managed keys)
resource "aws_s3_bucket_server_side_encryption_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Versioning — keep old file versions for rollback
resource "aws_s3_bucket_versioning" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Ownership controls — required for newer buckets
resource "aws_s3_bucket_ownership_controls" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Origin Access Control

resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = "${var.bucket_name_prefix}-oac"
  description                       = "OAC for ${aws_s3_bucket.frontend.id}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront Distribution

resource "aws_cloudfront_distribution" "frontend" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CDN for ${aws_s3_bucket.frontend.id}"
  default_root_object = "index.html"
  price_class         = var.cloudfront_price_class

  # S3 origin
  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "s3-${aws_s3_bucket.frontend.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  # API Gateway origin
  origin {
    domain_name = var.api_gateway_domain_name
    origin_id   = "api-gateway-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }

    # Secret header to lock the API to CloudFront-only traffic
    custom_header {
      name  = "X-Origin-Verify"
      value = var.origin_verify_secret_value
    }
  }

  # Default cache behavior — applies to all requests
  # Default cache behavior — static files (HTML/CSS/JS) with edge auth
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-${aws_s3_bucket.frontend.id}"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6" # CachingOptimized


    # check-auth on viewer-request (validates JWT cookie, redirects to login)
    dynamic "lambda_function_association" {
      for_each = var.enable_edge_auth ? [1] : []
      content {
        event_type   = "viewer-request"
        lambda_arn   = var.lambda_edge_check_auth_arn
        include_body = false
      }
    }

    # http-headers on origin-response (adds security headers)
    dynamic "lambda_function_association" {
      for_each = var.enable_edge_auth ? [1] : []
      content {
        event_type   = "origin-response"
        lambda_arn   = var.lambda_edge_http_headers_arn
        include_body = false
      }
    }
  }

  # API behavior — route /databases* to API Gateway
  ordered_cache_behavior {
    path_pattern           = "/databases*"
    target_origin_id       = "api-gateway-origin"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods  = ["GET", "HEAD"]

    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_disabled.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer_except_host.id

    # Inject the Authorization header from the idToken cookie
    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.inject_auth_header.arn
    }
  }

  # /parseauth — OAuth callback handler (parse-auth Lambda@Edge)
  dynamic "ordered_cache_behavior" {
    for_each = var.enable_edge_auth ? [1] : []
    content {
      path_pattern           = "/parseauth"
      target_origin_id       = "s3-${aws_s3_bucket.frontend.id}"
      viewer_protocol_policy = "redirect-to-https"
      allowed_methods        = ["GET", "HEAD", "OPTIONS"]
      cached_methods         = ["GET", "HEAD"]
      cache_policy_id        = data.aws_cloudfront_cache_policy.caching_disabled.id


      lambda_function_association {
        event_type   = "viewer-request"
        lambda_arn   = var.lambda_edge_parse_auth_arn
        include_body = false
      }
    }
  }

  # /refreshauth — silent token refresh (refresh-auth Lambda@Edge)
  dynamic "ordered_cache_behavior" {
    for_each = var.enable_edge_auth ? [1] : []
    content {
      path_pattern           = "/refreshauth"
      target_origin_id       = "s3-${aws_s3_bucket.frontend.id}"
      viewer_protocol_policy = "redirect-to-https"
      allowed_methods        = ["GET", "HEAD", "OPTIONS"]
      cached_methods         = ["GET", "HEAD"]
      cache_policy_id        = data.aws_cloudfront_cache_policy.caching_disabled.id


      lambda_function_association {
        event_type   = "viewer-request"
        lambda_arn   = var.lambda_edge_refresh_auth_arn
        include_body = false
      }
    }
  }

  # /signout — sign out and clear cookies (sign-out Lambda@Edge)
  dynamic "ordered_cache_behavior" {
    for_each = var.enable_edge_auth ? [1] : []
    content {
      path_pattern           = "/signout"
      target_origin_id       = "s3-${aws_s3_bucket.frontend.id}"
      viewer_protocol_policy = "redirect-to-https"
      allowed_methods        = ["GET", "HEAD", "OPTIONS"]
      cached_methods         = ["GET", "HEAD"]
      cache_policy_id        = data.aws_cloudfront_cache_policy.caching_disabled.id


      lambda_function_association {
        event_type   = "viewer-request"
        lambda_arn   = var.lambda_edge_sign_out_arn
        include_body = false
      }
    }
  }

  # SPA-style routing: 403/404 from S3 → serve index.html
  # Useful if you later add client-side routing; harmless otherwise.
  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  # Restrict to no specific geo (or set if needed)
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Use default CloudFront SSL cert (works with *.cloudfront.net domain)
  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = merge(var.tags, {
    Name = "${var.bucket_name_prefix}-cdn"
  })
}

# S3 Bucket Policy: allow CloudFront only

data "aws_iam_policy_document" "frontend_bucket_policy" {
  statement {
    sid    = "AllowCloudFrontServicePrincipalReadOnly"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.frontend.arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.frontend.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  policy = data.aws_iam_policy_document.frontend_bucket_policy.json

  # Ensure public access block is in place first
  depends_on = [aws_s3_bucket_public_access_block.frontend]
}

# Frontend File Uploads Static files (everything EXCEPT config.js.tftpl)

locals {
  # Find all files in the frontend source dir, EXCLUDING the template
  static_files = setsubtract(
    fileset(var.frontend_source_dir, "**/*"),
    ["js/config.js.tftpl"]
  )

  # Map file extension → MIME type
  content_types = {
    "html"  = "text/html"
    "css"   = "text/css"
    "js"    = "application/javascript"
    "json"  = "application/json"
    "png"   = "image/png"
    "jpg"   = "image/jpeg"
    "jpeg"  = "image/jpeg"
    "gif"   = "image/gif"
    "svg"   = "image/svg+xml"
    "ico"   = "image/x-icon"
    "txt"   = "text/plain"
    "woff"  = "font/woff"
    "woff2" = "font/woff2"
  }
}

resource "aws_s3_object" "static_files" {
  for_each = local.static_files

  bucket       = aws_s3_bucket.frontend.id
  key          = each.value
  source       = "${var.frontend_source_dir}/${each.value}"
  etag         = filemd5("${var.frontend_source_dir}/${each.value}")
  content_type = lookup(local.content_types, regex("[^.]+$", each.value), "application/octet-stream")
}

# Templated config.js (rendered with API URL)

resource "aws_s3_object" "config_js" {
  bucket = aws_s3_bucket.frontend.id
  key    = "js/config.js"
  content = templatefile(
    "${var.frontend_source_dir}/js/config.js.tftpl",
    {
      api_base_url = var.api_base_url
    }
  )
  content_type = "application/javascript"

  # Force re-upload when API URL changes
  etag = md5(templatefile(
    "${var.frontend_source_dir}/js/config.js.tftpl",
    {
      api_base_url = var.api_base_url
    }
  ))
}

# CloudFront Cache Invalidation

# When any uploaded file changes, invalidate CloudFront cache so users get fresh content
# Uses a null_resource + local-exec; runs the AWS CLI
resource "null_resource" "invalidate_cloudfront" {
  triggers = {
    # Re-run whenever any object's etag changes
    static_files_hash = sha256(jsonencode([for k, v in aws_s3_object.static_files : v.etag]))
    config_hash       = aws_s3_object.config_js.etag
  }

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command     = "aws cloudfront create-invalidation --distribution-id ${aws_cloudfront_distribution.frontend.id} --paths '/*'"
  }
}


# CloudFront Function — inject Authorization header from idToken cookie
# Converts the HttpOnly idToken cookie into an Authorization: Bearer header
# so the API Gateway JWT authorizer can read it.

resource "aws_cloudfront_function" "inject_auth_header" {
  name    = "${var.bucket_name_prefix}-inject-auth-header"
  runtime = "cloudfront-js-2.0"
  comment = "Injects Authorization header from idToken cookie for API requests."
  publish = true
  code    = <<-EOT
    function handler(event) {
        var request = event.request;
        var cookies = request.cookies;
        for (var name in cookies) {
            if (name.indexOf('idToken') !== -1) {
                request.headers['authorization'] = {
                    value: 'Bearer ' + cookies[name].value
                };
                break;
            }
        }
        return request;
    }
  EOT
}

# AWS-managed origin request policy: AllViewerExceptHostHeader
# Forwards all viewer data EXCEPT the Host header (required for API Gateway origin).
data "aws_cloudfront_origin_request_policy" "all_viewer_except_host" {
  name = "Managed-AllViewerExceptHostHeader"
}

# AWS-managed cache policy: CachingDisabled (for API — never cache)
data "aws_cloudfront_cache_policy" "caching_disabled" {
  name = "Managed-CachingDisabled"
}
