// Prereqs:
// You have a hosted zone in Route 53, e.g. aws.stevekehlet.com
// You have a bucket in S3 with a matching name (e.g. aws.stevekehlet.com), with static website hosting enabled
// You have an issued certificate for auth.<your-hosted-zone> in AWS Certificate Manager in us-east-1

variable "my_domain" {
  default = "aws.stevekehlet.com"
}

variable "aws_region" {
  default = "us-west-2"
}

provider "aws" {
  region  = "${var.aws_region}"
}

provider "aws" {
  region = "us-east-1"
  alias = "us-east-1"
}

data "aws_route53_zone" "my_domain" {
  name = "${var.my_domain}."
}

data "aws_s3_bucket" "my_bucket" {
  bucket = "${var.my_domain}"
}

data "aws_acm_certificate" "auth_certificate" {
  provider = "aws.us-east-1" // Note that the cert for Cognito custom domains must be in us-east-1
  domain   = "auth.${var.my_domain}"
  statuses = ["ISSUED"]
}

// Cognito custom domains require: "A web domain that you own. Its root must have a valid A record in DNS"
// So we need <my_domain> to be an A record. Point it to my S3 bucket that has static website hosting enabled.
resource "aws_route53_record" "my_domain_a_record" {
  zone_id = "${data.aws_route53_zone.my_domain.zone_id}"
  name    = "${var.my_domain}"
  type    = "A"
  alias {
    name = "${data.aws_s3_bucket.my_bucket.website_domain}"
    zone_id = "${data.aws_s3_bucket.my_bucket.hosted_zone_id}"
    evaluate_target_health = false
  }
}

resource "aws_cognito_user_pool" "my_pool" {
  name                     = "mypool"
  mfa_configuration        = "OFF"
  auto_verified_attributes = ["email"]
  admin_create_user_config {
    allow_admin_create_user_only = true
    unused_account_validity_days = "30"
  }
}

resource "aws_cognito_user_pool_client" "my_pool_client" {
  name                                 = "myclient"
  user_pool_id                         = "${aws_cognito_user_pool.my_pool.id}"
  refresh_token_validity               = 30
  generate_secret                      = false
  explicit_auth_flows                  = ["ADMIN_NO_SRP_AUTH", "USER_PASSWORD_AUTH"]
  supported_identity_providers         = ["COGNITO"]
  callback_urls                        = ["https://${var.my_domain}/auth/callback"]
  logout_urls                          = ["https://${var.my_domain}/auth"]
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["openid"]
  allowed_oauth_flows_user_pool_client = true
}

resource "aws_cognito_user_pool_domain" "my_custom_domain" {
  domain          = "auth.${var.my_domain}"
  certificate_arn = "${data.aws_acm_certificate.auth_certificate.arn}"
  user_pool_id    = "${aws_cognito_user_pool.my_pool.id}"
  depends_on      = ["aws_route53_record.my_domain_a_record"]
}

resource "aws_route53_record" "cognito_auth_custom_domain" {
  zone_id = "${data.aws_route53_zone.my_domain.zone_id}"
  name    = "auth.${data.aws_route53_zone.my_domain.name}"
  type    = "A"
  alias {
    name = "${aws_cognito_user_pool_domain.my_custom_domain.cloudfront_distribution_arn}"
    // The following zone id is CloudFront.
    // See https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-route53-aliastarget.html
    zone_id = "Z2FDTNDATAQYW2"
    evaluate_target_health = false
  }
}
