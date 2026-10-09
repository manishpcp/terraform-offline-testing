# INTENTIONALLY INSECURE. Used only to watch Checkov fail (make demo-fail).
# Never deploy this. It is excluded from the normal scan in .checkov.yaml.
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

resource "aws_s3_bucket" "bad" {
  bucket = "definitely-not-secure"
}

# ACL is a separate resource in AWS provider v6+.
resource "aws_s3_bucket_acl" "bad" {
  bucket = aws_s3_bucket.bad.id
  acl    = "public-read"
}

resource "aws_security_group" "bad" {
  name        = "open-to-world"
  description = "SSH open to the internet"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
