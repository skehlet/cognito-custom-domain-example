## PoC for Cognito custom domains using terraform.

See `main.tf`. Also see [the terraform docs](https://www.terraform.io/docs/providers/aws/r/cognito_user_pool_domain.html)
and [the github issue](https://github.com/terraform-providers/terraform-provider-aws/issues/5026)
to add support for custom domains.

You can see it working with `curl`, like:
```
curl -vv 'https://auth.aws.stevekehlet.com/oauth2/authorize?response_type=code&client_id=1otf2f1qpp0h5slu15l0vs9jd3&redirect_uri=https%3A%2F%2Faws.stevekehlet.com%2Fauth%2Fcallback&scope=openid'
```
This will redirect you to the Cognito login page.
