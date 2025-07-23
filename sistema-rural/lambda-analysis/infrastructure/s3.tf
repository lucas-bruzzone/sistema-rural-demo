# ===================================
# S3 BUCKET - GEOSPATIAL CACHE
# ===================================

resource "aws_s3_bucket" "geospatial_cache" {
  bucket = "${var.project_name}-geospatial-cache"

  tags = {
    Name = "${var.project_name}-geospatial-cache"
    Type = "geospatial-data"
  }
}

# ===================================
# S3 BUCKET CONFIGURATION
# ===================================

resource "aws_s3_bucket_versioning" "geospatial_cache" {
  bucket = aws_s3_bucket.geospatial_cache.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "geospatial_cache" {
  bucket = aws_s3_bucket.geospatial_cache.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "geospatial_cache" {
  bucket = aws_s3_bucket.geospatial_cache.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ===================================
# LIFECYCLE CONFIGURATION
# ===================================

resource "aws_s3_bucket_lifecycle_configuration" "geospatial_cache" {
  bucket = aws_s3_bucket.geospatial_cache.id

  rule {
    id     = "cache_cleanup"
    status = "Enabled"

    filter {
      prefix = ""
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}