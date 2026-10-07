locals {
  name_prefix = "case2-${var.environ}"

  default_tags = {
    application = "case2"
    env         = var.environ
    maintainer  = var.maintainer
    bu          = "bu-case2"
    tribe       = "squad-sre"
    ManagedBy   = "Terraform"
    Repository  = "aws-portfolio-blueprints"
  }
}
