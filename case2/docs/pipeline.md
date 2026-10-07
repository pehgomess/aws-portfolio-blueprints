# case2 — Estratégia de CI, Git e estado por ambiente

Status: workflow de CI criado em .github/workflows/terraform-ci.yml. Execução no GitHub ainda pendente; backend remoto não ativado. O escopo vigente está em ../tasks.md e o progresso em ../process/process.log.

## 1. Modelo de trabalho

Usar main e branches curtas feat/* ou fix/*. Toda alteração entra por Pull Request. Dev, hml e prd são configurações de infraestrutura, não branches obrigatórias.

```text
Branch curta → Pull Request → fmt → init sem backend → validate → merge na main
```

Configurar ruleset/proteção da main no GitHub com PR e checks obrigatórios. Avaliar revisão conforme os colaboradores disponíveis; uma pessoa não aprova o próprio PR. A regra escrita aqui não configura o repositório remoto.

Trunk-based não exige workspaces ou deploy sequencial. Branches e tfvars não isolam estado. Workspaces CLI separam estados dentro de um backend, mas não substituem separação de permissões/contas. Para este case, preferir configuração de backend explícita por ambiente quando houver implantação futura.

## 2. CI Terraform sem AWS

Workflow implementado: .github/workflows/terraform-ci.yml, na raiz do repositório. Diretório de execução: case2/terraform.

Gatilhos: PR para main, push em main e execução manual (workflow_dispatch). Sem filtros de caminhos, para que o check sempre seja emitido. O CI verifica a configuração compartilhada uma vez; repetir validate em uma matriz dev/hml/prd não prova os resultados dos tfvars.

Passos:

```bash
terraform -chdir=case2/terraform fmt -check -recursive
terraform -chdir=case2/terraform init -backend=false -input=false
terraform -chdir=case2/terraform validate -no-color
```

Terraform 1.16.5 fixado no runner; usar a mesma versão localmente. Lockfile gerado e versionado para o provider AWS. O CI usa -lockfile=readonly para não atualizar dependências silenciosamente. Não inserir credenciais AWS ou permissões id-token:write no CI estático. Instalar providers requer acesso de rede ao registry, mas não acesso a bucket S3.

Configurar permissions: contents: read, tempo máximo do job e concurrency para cancelar validações antigas do mesmo PR. Fixar actions por SHA verificado na implementação. Se forem usados filtros de caminhos, garantir que mudanças em módulos, lockfile e workflow sejam cobertas e que checks obrigatórios não fiquem permanentemente pendentes em PRs sem Terraform.

Trivy é melhoria opcional posterior. Se adotado, usar scan-type: config, scan-ref: case2/terraform, severidades escolhidas e exit-code: '1' para bloquear o job. Evitar @master; fixar versão/SHA e documentar exceções justificadas. O default working-directory dos comandos run não altera automaticamente os caminhos de uma action uses.

CI estático não comprova conectividade, permissões efetivas, imagens disponíveis ou deploy AWS. Custos/minutos do GitHub Actions dependem do plano e do runner; não prometer gratuidade irrestrita.

## 3. CI da aplicação — etapa posterior

Definir aplicação pequena, testes de endpoints, build Docker e teste de integração local no runner. Publicação ECR e deploy AWS ficam fora da execução atual. O runner pode baixar dependências para o build; a aplicação em runtime deve respeitar as dependências privadas do case2.

Separar checks da aplicação dos checks Terraform para mostrar evidências distintas. Não criar workflows ou badges antes da implementação e verificação.

## 4. Região dos recursos versus região do estado

Provider e backend têm configurações independentes:

| Configuração | Quando é usada | O que controla |
| --- | --- | --- |
| region no tfvars, lida por var.region | Operações do provider | Região dos recursos |
| region no arquivo de backend | terraform init | Região onde existe o bucket S3 |
| bucket e key no backend | Inicialização/operações de estado | Bucket e objeto que guardam aquele estado |

O backend não aceita var.region, var.environ ou locals. Passar sua configuração por arquivo com -backend-config no init. O tfvars não configura backend. [HashiCorp: configuração parcial](https://developer.hashicorp.com/terraform/language/backend).

Dev/hml em us-east-2 e prd em sa-east-1 são compatíveis com essa estratégia. O bucket de estado pode ficar na mesma região dos recursos ou em outra região; a configuração do backend deve apontar para a região real do bucket. Isso não altera a região do provider. [HashiCorp: backend S3](https://developer.hashicorp.com/terraform/language/backend/s3).

## 5. Proposta de S3 por ambiente — somente referência futura

Manter o backend comentado e estado local agora. Futuramente, substituir o exemplo fixo comentado por configuração parcial, habilitando apenas após bootstrap autorizado:

```hcl
terraform {
  backend "s3" {}
}
```

Estrutura sugerida, ainda não criada:

```text
case2/terraform/
├── backend/
│   ├── dev.s3.tfbackend.example
│   ├── hml.s3.tfbackend.example
│   └── prd.s3.tfbackend.example
└── tfvars/
    ├── dev.tfvars.example
    ├── hml.tfvars.example
    └── prd.tfvars.example
```

Exemplos fictícios sem credenciais:

```hcl
# backend/dev.s3.tfbackend.example
bucket  = "aurora-case2-dev-state-example"
key     = "case2/dev/terraform.tfstate"
region  = "us-east-2"
encrypt = true
```

```hcl
# backend/hml.s3.tfbackend.example
bucket  = "aurora-case2-hml-state-example"
key     = "case2/hml/terraform.tfstate"
region  = "us-east-2"
encrypt = true
```

```hcl
# backend/prd.s3.tfbackend.example
bucket  = "aurora-case2-prd-state-example"
key     = "case2/prd/terraform.tfstate"
region  = "sa-east-1"
encrypt = true
```

Na mesma proposta, os tfvars teriam region="us-east-2" em dev/hml e region="sa-east-1" em prd. Os exemplos atuais ainda não foram alterados; na etapa dos ambientes, revisar também AZs, imagens, certificados e serviços dependentes da região.

Buckets separados facilitam políticas específicas, principalmente para prd. Uma alternativa é bucket compartilhado com keys distintas e políticas por prefixo, conforme os requisitos. Separação forte exige identidade/permissões coerentes, não apenas nomes diferentes.

Antes de ativar S3: preparar bucket com versionamento, criptografia, bloqueio de acesso público, políticas e mecanismo de locking compatível com a versão Terraform escolhida. O bucket deve existir antes do init; usar bootstrap separado. Locking não é configurado pelos exemplos acima e será definido nessa etapa.

## 6. Como selecionar backend e entradas do mesmo ambiente

Referência futura, NÃO executar no laboratório atual. Exige backend S3 ativo, buckets reais preparados e autenticação externa. Executar a partir da raiz:

```bash
# DEV
TF_DATA_DIR="$PWD/case2/.terraform-data/remote-dev" terraform -chdir=case2/terraform init -input=false -backend-config=backend/dev.s3.tfbackend.example
TF_DATA_DIR="$PWD/case2/.terraform-data/remote-dev" terraform -chdir=case2/terraform plan -input=false -var-file=tfvars/dev.tfvars.example

# HML
TF_DATA_DIR="$PWD/case2/.terraform-data/remote-hml" terraform -chdir=case2/terraform init -input=false -backend-config=backend/hml.s3.tfbackend.example
TF_DATA_DIR="$PWD/case2/.terraform-data/remote-hml" terraform -chdir=case2/terraform plan -input=false -var-file=tfvars/hml.tfvars.example

# PRD
TF_DATA_DIR="$PWD/case2/.terraform-data/remote-prd" terraform -chdir=case2/terraform init -input=false -backend-config=backend/prd.s3.tfbackend.example
TF_DATA_DIR="$PWD/case2/.terraform-data/remote-prd" terraform -chdir=case2/terraform plan -input=false -var-file=tfvars/prd.tfvars.example
```

TF_DATA_DIR separa os metadados de inicialização; bucket/key separam o estado remoto. Não misturar backend dev com tfvars prd. Usar uma seleção única e validada de ambiente numa automação futura, que determine ambos os arquivos. Não receber caminhos arbitrários como entrada.

Se já houver estado local, migrar é uma operação própria: revisar origem/destino, fazer backup e planejar migração. Não usar reconfigure indiscriminadamente para migrar estado; reconfiguração e migração têm propósitos diferentes. Nada nesta documentação migra estado.

## 7. Delivery AWS — fora do escopo atual

Não criar workflow executável com plan/apply nesta fase. Para uma entrega futura, definir OIDC por ambiente, least privilege, backend/locking, concurrency por ambiente, plano salvo revisável, aprovação antes de aplicar o plano e testes posteriores. Configurar GitHub Environments/proteções e conferir disponibilidade no plano do GitHub.

Usar o mesmo commit revisado para promoção. Runners efêmeros não preservam estado local entre jobs; um deploy futuro precisará de estado persistente e controle de concorrência. Nunca tratar a existência de environment: production como aprovação automática: os reviewers precisam ser configurados.

O portfólio atual demonstrará revisão de código, CI estático e testes/build locais. Não haverá deploy AWS nem evidência operacional inventada.

## Verificação inicial

fmt, init sem backend e validate executados com Terraform 1.16.5 em cópia temporária Linux, sem AWS. Workflow YAML revisado localmente. A execução no GitHub depende de enviar os arquivos para o repositório; não houve commit/push automático.
