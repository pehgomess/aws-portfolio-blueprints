variable "region" {
  description = "Região AWS do ambiente."
  type        = string
  default     = "us-east-2"

  validation {
    condition     = length(trimspace(var.region)) > 0
    error_message = "A região não pode ser vazia."
  }
}

variable "environ" {
  description = "Ambiente da configuração: dev, hml ou prd."
  type        = string

  validation {
    condition     = contains(["dev", "hml", "prd"], var.environ)
    error_message = "Use dev, hml ou prd."
  }
}

variable "maintainer" {
  description = "Equipe responsável pela infraestrutura."
  type        = string
  default     = "squad-sre"

  validation {
    condition     = length(trimspace(var.maintainer)) > 0
    error_message = "O responsável não pode ser vazio."
  }
}
