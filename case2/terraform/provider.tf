terraform {
  required_version = ">= 1.6.0, < 2.0.0"

  # Sem backend ativo, o Terraform usa estado local.
  # Opção futura: descomentar somente após preparar o bucket S3.
  # Exemplo fictício para dev; bucket/key devem ser separados por ambiente.
  # Não colocar credenciais no código.
  # backend "s3" {
  #   bucket  = "aurora-case2-terraform-dev-example"
  #   key     = "case2/dev/terraform.tfstate"
  #   region  = "us-east-2"
  #   encrypt = true
  # }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.25.0, < 7.0.0"
    }
  }
}

# Estado local por padrão. Backend remoto exige bootstrap separado.
provider "aws" {
  region = var.region

  # Quando necessário, autenticar externamente pela cadeia padrão AWS.
  default_tags {
    tags = local.default_tags
  }
}
