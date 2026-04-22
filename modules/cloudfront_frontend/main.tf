# Origin Access Control (OAC) for CloudFront
resource "aws_cloudfront_origin_access_control" "this" {
  name = "${var.project_name}-oac"

  description = "OAC for S3 frontend access"
  origin_access_control_origin_type = "s3"
  signing_behavior = "always"
  signing_protocol = "sigv4"
}

# CloudFront distribution for the frontend
resource "aws_cloudfront_distribution" "this" {
    enabled = true
    is_ipv6_enabled = true
    default_root_object = "index.html"

    # Link to the S3 bucket as the origin
    origin {
        domain_name = var.s3_bucket_regional_domain_name
        origin_id   = "S3Origin"
        origin_access_control_id = aws_cloudfront_origin_access_control.this.id
    }

    # Cache behavior
    default_cache_behavior {
        allowed_methods  = ["GET", "HEAD", "OPTIONS"]
        cached_methods   = ["GET", "HEAD"]
        target_origin_id = "S3Origin"

        # Using the Managed Caching Optimized policy (Best Practice)
        viewer_protocol_policy = "redirect-to-https"
        cache_policy_id        = "658327ea-f89d-4fab-a63d-7e88639e58f6" # Managed-CachingOptimized
    }
    
    # SPA support - redirect 404s to index.html
    custom_error_response {
        error_code         = 403
        response_code      = 200
        response_page_path = "/index.html"
}

    custom_error_response {
      error_code = 404
      response_code = 200
      response_page_path = "/index.html"
    }

    # Restrictions
    restrictions {
        geo_restriction {
            restriction_type = "none"
        }
    }

    # SSL/TLS Certificate
    viewer_certificate {
        cloudfront_default_certificate = true
    }

    tags = var.tags

}