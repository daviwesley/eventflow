# Sistema de Reservas para Eventos de Alta Demanda

## Objetivo

Construir uma plataforma serverless para reservar ingressos ou assentos em eventos de alta demanda, evitando venda duplicada, controlando reservas temporárias e processando pagamentos de forma assíncrona.

## Decisões arquiteturais

- API: Amazon API Gateway **HTTP API**.
- Estilo de aplicação: monólito serverless modular, com todas as Lambdas e a infraestrutura no mesmo projeto.
- Computação: AWS Lambda usando Python.
- Framework HTTP: FastAPI executado na Lambda através do adaptador Mangum.
- Validação e schemas: Pydantic.
- SDK AWS: Boto3.
- Utilitários serverless: AWS Lambda Powertools for Python.
- Persistência: Amazon DynamoDB usando **Single Table Design**.
- Mensageria: Amazon SNS para distribuição de eventos.
- Filas: Amazon SQS para processamento assíncrono.
- Falhas: toda fila SQS de processamento deve possuir uma DLQ dedicada.
- Observabilidade: Amazon CloudWatch.
- Objetivo de custo: utilizar somente recursos e limites do AWS Free Tier.

## Infraestrutura como código

- Ferramenta: Terraform.
- A infraestrutura AWS será mantida no mesmo repositório do código das Lambdas.
- Recursos principais: HTTP API, funções Lambda, tabela DynamoDB, tópico SNS, filas SQS, DLQs, permissões IAM, logs e alarmes CloudWatch.
- Os recursos devem ser parametrizados por ambiente, mesmo que o primeiro ambiente seja apenas `dev`.
- O estado do Terraform não deve ser versionado no repositório.
- Segredos e credenciais não devem ser armazenados em arquivos `.tf`, `.tfvars` ou no código-fonte.

## Organização planejada do monólito

```text
sistema-reservas-eventos/
├── reservation_service/       # Pacote principal da aplicação
│   ├── api/                    # FastAPI, rotas, dependências e schemas HTTP
│   ├── application/            # Casos de uso e orquestração
│   ├── domain/                 # Entidades, value objects e regras de negócio
│   ├── infrastructure/        # Boto3, DynamoDB, SNS, SQS e implementações
│   ├── workers/                # Handlers dos consumidores SQS
│   ├── config/                 # Configuração e variáveis de ambiente
│   ├── observability/          # Logger, métricas e tracing Powertools
│   └── shared/                 # Erros, tipos e utilitários realmente compartilhados
├── tests/
│   ├── unit/
│   ├── integration/
│   └── contract/
├── infra/
│   ├── environments/
│   │   └── dev/
│   │       ├── backend.tf
│   │       ├── versions.tf
│   │       ├── main.tf
│   │       ├── variables.tf
│   │       ├── outputs.tf
│   │       └── terraform.tfvars.example
│   ├── modules/
│   │   ├── api/
│   │   ├── compute/
│   │   ├── data/
│   │   ├── messaging/
│   │   ├── observability/
│   │   └── iam/
│   └── docker/
│       └── lambda-build.Dockerfile
├── .github/
│   └── workflows/
│       ├── ci.yml
│       ├── terraform-plan.yml
│       ├── deploy-dev.yml
│       └── destroy-dev.yml
├── .python-version
├── uv.lock
├── pyproject.toml
├── PLAN.md
└── README.md
```

O monólito terá módulos internos bem definidos, mas será implantado e versionado como uma única aplicação. A separação entre API, workers, domínio e infraestrutura deve permitir testes independentes e uma futura extração de componentes, caso isso seja necessário.

### Convenções Python

- Manter o pacote da aplicação na raiz em `reservation_service/`, pois o projeto não será distribuído como pacote Python.
- Usar `pyproject.toml` como fonte principal de configuração do projeto, dependências e ferramentas.
- Usar `__init__.py` nos pacotes Python necessários.
- Os testes importarão diretamente o pacote `reservation_service` a partir da raiz do projeto.
- Manter tipagem explícita nas interfaces, casos de uso e adaptadores.
- Usar `ruff` para lint e formatação, `pytest` para testes e `mypy` ou `pyright` para verificação de tipos.
- Evitar um módulo genérico `utils.py`; utilitários devem pertencer ao contexto ao qual realmente se aplicam.
- Evitar que regras de negócio dependam diretamente de Boto3 ou FastAPI.
- Definir portas/interfaces na camada de aplicação e implementá-las na infraestrutura.
- Usar injeção de dependência para conectar casos de uso aos adaptadores AWS.

## Boas práticas de Terraform

- Usar `infra/environments/<ambiente>` como root module de cada ambiente.
- Manter módulos locais pequenos e orientados a responsabilidade: API, compute, dados, mensageria, observabilidade e IAM.
- O root module deve apenas compor módulos e conectar seus inputs/outputs; regras de recursos devem ficar nos módulos.
- Fixar a versão do Terraform e do provider AWS em `versions.tf`.
- Usar `required_providers` com versão restrita e atualizar dependências de forma deliberada.
- Definir descrições e validações para todas as variáveis públicas.
- Definir descrições para todos os outputs e expor somente valores necessários.
- Centralizar nomes, tags, região e configurações comuns em `locals.tf`.
- Aplicar tags padronizadas como `Project`, `Environment`, `ManagedBy` e `Component`.
- Não usar `terraform apply` sem um `terraform plan` revisado.
- Não usar `-target` no fluxo normal de deploy.
- Usar `terraform-aws-modules/lambda/aws` para gerar os artefatos ZIP e instalar dependências com `uv`.
- Usar `build_in_docker = true` para produzir dependências compatíveis com o runtime Linux da Lambda.
- Não manter um script de empacotamento Python separado; o módulo será responsável pelo build.
- Separar permissões IAM por Lambda e conceder somente as ações e recursos necessários.
- Usar nomes determinísticos para filas, DLQs, tópicos, funções e tabela.
- Evitar `count` quando a identidade do recurso for importante; preferir `for_each` com chaves estáveis.
- Usar `lifecycle` somente quando houver uma justificativa documentada; não esconder alterações destrutivas.

### State e ambientes

- Não versionar `terraform.tfstate`, `.terraform/`, planos binários ou credenciais.
- Usar backend S3 no ambiente `dev`, com state versionado e locking nativo do Terraform via objeto `.tflock`.
- Não versionar o arquivo `terraform.tfstate`; o bucket deve ter bloqueio de acesso público, SSE-S3 e lifecycle para expirar versões antigas.
- Criar o bucket por `infra/bootstrap`, separado do root module da aplicação, pois o backend precisa existir antes do `terraform init`.
- O CI usa o mesmo state remoto, com OIDC e uma role IAM dedicada; deploy e destroy permanecem protegidos por environments e concorrência.
- Manter um state separado para cada ambiente (`dev`, `staging`, `prod`).
- O primeiro ambiente será `dev`, com configurações de baixo custo e sem recursos não essenciais.
- Nunca colocar credenciais AWS diretamente no backend ou nos arquivos `.tf`; usar perfil AWS, variáveis de ambiente ou identidade da CI.
- Não armazenar segredos em outputs. Quando inevitável, marcar outputs como `sensitive` e lembrar que valores sensíveis ainda podem existir no state.

### Qualidade e CI

Antes de qualquer apply:

```text
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
terraform plan
```

O pipeline deverá executar também lint, análise de segurança e revisão do plano. O `apply` ficará restrito à branch principal e exigirá aprovação explícita.

### Escopo compatível com Free Tier

- Não criar VPC ou NAT Gateway sem necessidade; a primeira versão usará Lambdas fora de VPC.
- Usar somente DynamoDB on-demand ou configuração mínima adequada ao Free Tier.
- Configurar retenção curta de logs e alarmes de billing.
- Evitar API Gateway REST, CloudFront, WAF, OpenSearch, RDS e recursos de rede pagos na primeira versão.
- Manter uma única stack monolítica por ambiente, sem criar states separados por componente neste estágio.

## Gitflow e GitHub Actions

### Estratégia de branches

- `main`: código estável e releases.
- `develop`: integração contínua do próximo ciclo.
- `feature/<nome>`: novas funcionalidades criadas a partir de `develop`.
- `release/<versao>`: preparação de uma versão para `main`.
- `hotfix/<nome>`: correções urgentes criadas a partir de `main`.
- `main` e `develop` devem exigir pull request, revisão e checks aprovados.

### Workflows

#### `ci.yml`

Executar em push e pull request para `main`, `develop`, `release/**` e `hotfix/**`:

- Instalar Python e dependências.
- Executar Ruff.
- Executar verificação de tipos.
- Executar testes unitários.
- Executar testes de integração sem criar recursos reais por padrão.
- Validar empacotamento das Lambdas.

#### `terraform-plan.yml`

Executar em pull requests que alterem `infra/**`:

- Executar `terraform fmt -check`.
- Executar `terraform init`.
- Executar `terraform validate`.
- Executar análise de segurança.
- Gerar `terraform plan`.
- Publicar o resultado do plano como artefato ou comentário do pull request.
- Nunca executar `apply` em pull request.

#### `deploy-dev.yml`

Executar somente após merge em `develop` ou por acionamento manual:

- Construir e empacotar as Lambdas.
- Executar o plano novamente.
- Exigir aprovação do environment `dev` antes do apply.
- Executar `terraform apply` somente com o plano revisado.
- Usar concorrência para impedir dois deploys simultâneos do mesmo ambiente.

#### `destroy-dev.yml`

Workflow exclusivamente manual (`workflow_dispatch`), protegido por:

- Execução somente a partir de `main`.
- Environment GitHub `dev-destroy` com aprovação obrigatória.
- Campo de confirmação manual, por exemplo `DESTROY-DEV`.
- `terraform plan -destroy` exibido antes da execução.
- `terraform destroy` somente após aprovação explícita.
- Concorrência exclusiva com o workflow de deploy.
- Registro do commit, usuário executor, horário e plano destruído.

O workflow destruirá somente os recursos registrados no Terraform state do ambiente. Ele não deverá usar comandos genéricos da AWS para apagar recursos fora do state.

### Autenticação AWS

- Usar GitHub Actions OIDC com uma IAM Role dedicada.
- Não armazenar `AWS_ACCESS_KEY_ID` ou `AWS_SECRET_ACCESS_KEY` como secrets permanentes.
- Separar roles de plan e apply/destroy quando possível.
- Restringir a role por repositório, branch e environment.

### Requisito para deploy e destroy

Os workflows de `apply` e `destroy` usam o mesmo state remoto no S3 em `us-east-1`. O workflow destrói todos os recursos registrados no state da aplicação, executa uma verificação final com `terraform state list` e, somente depois dessa confirmação, remove todas as versões e delete markers das chaves de state e lock do ambiente `dev`. O bucket S3 pertence ao bootstrap da infraestrutura de gerenciamento e permanece preservado; um próximo deploy poderá criar o state novamente. O nome do bucket deve ser configurado na variável de ambiente do GitHub `TERRAFORM_STATE_BUCKET`; a role deve ser configurada em `AWS_GITHUB_ACTIONS_ROLE_ARN`.

### Uso do S3

O S3 é usado somente para o state do Terraform, não como armazenamento funcional da aplicação. O backend usa `use_lockfile = true`, criptografia SSE-S3 e versionamento. A criação inicial pode ser feita pelo workflow manual **Bootstrap Terraform State**, que configura o bucket antes do primeiro `terraform init`.

```bash
cd infra/bootstrap
terraform init
terraform apply
terraform output -raw terraform_state_bucket_name

cd ../environments/dev
terraform init -backend-config=backend.hcl
```

Para a conta atual, que não é nova, não se deve assumir o benefício promocional do Free Tier. Em `us-east-1`, um state pequeno (até 1 MB), mesmo com dezenas de versões, tende a custar menos de US$ 0,01/mês em armazenamento. As requisições de planos/applies normalmente ficam abaixo de US$ 0,01/mês; o custo total esperado para este projeto é aproximadamente US$ 0,01–0,05/mês, sem recursos adicionais como replicação, logs de acesso ou SSE-KMS. O valor real depende da região, quantidade de execuções, versões retidas e transferência.

### Entrypoints das Lambdas

Os entrypoints serão pequenos e ficarão próximos de suas responsabilidades. O ZIP da Lambda será um artefato de implantação gerado pelo build, não uma distribuição pública do pacote Python:

```text
reservation_service/api/handler.py
reservation_service/workers/payment_handler.py
reservation_service/workers/expiration_handler.py
reservation_service/workers/notification_handler.py
reservation_service/workers/analytics_handler.py
```

O `api/handler.py` exporá a aplicação FastAPI por meio do Mangum. Os workers receberão eventos SQS e delegarão o processamento aos casos de uso da camada `application`.

## Stack de desenvolvimento

```text
Python
FastAPI
Mangum
Pydantic
Boto3
uv
AWS Lambda Powertools for Python
```

Diretrizes:

- Usar Pydantic para validar payloads de entrada e respostas da API.
- Usar Boto3 para acesso ao DynamoDB, SNS, SQS e demais serviços AWS.
- Usar Powertools para Logger, Tracer, Metrics e parsing de eventos.
- Manter handlers finos; regras de negócio devem ficar em services/use cases.
- Separar adaptadores AWS, domínio e camada HTTP para facilitar testes.
- Usar injeção de dependência do FastAPI somente onde não aumentar o custo ou a complexidade da Lambda.
- Reutilizar clientes Boto3 fora do handler para aproveitar conexões entre invocações.

## Arquitetura inicial

```text
Cliente
  -> API Gateway HTTP API
  -> Lambda Reservation API
  -> DynamoDB
  -> SNS reservation-events
       -> SQS payment-queue       -> Lambda Payment Worker
       -> SQS expiration-queue    -> Lambda Expiration Worker
       -> SQS notification-queue  -> Lambda Notification Worker
       -> SQS analytics-queue     -> Lambda Analytics Worker
```

## Política obrigatória de DLQ

Nenhuma fila SQS de processamento será criada sem uma DLQ associada:

```text
payment-queue       -> payment-dlq
expiration-queue    -> expiration-dlq
notification-queue  -> notification-dlq
analytics-queue     -> analytics-dlq
```

Diretrizes:

- Usar uma DLQ dedicada para cada fila principal, evitando misturar falhas de domínios diferentes.
- Configurar `RedrivePolicy` com `maxReceiveCount` inicial de 5 ou mais.
- Configurar `VisibilityTimeout` da fila principal para pelo menos seis vezes o timeout máximo da Lambda, acrescido do batch window quando aplicável.
- Ativar partial batch response (`ReportBatchItemFailures`) nos event source mappings, para que apenas mensagens com falha retornem à fila.
- Não apagar a mensagem até concluir o processamento e as gravações necessárias.
- Tornar todos os consumidores idempotentes, pois SQS utiliza entrega at-least-once.
- Configurar retenção da DLQ maior que a retenção da fila principal, permitindo investigação e reprocessamento.
- Não conectar automaticamente uma Lambda à DLQ; o reprocessamento deve ser controlado e auditável.
- Usar o recurso de redrive da SQS para devolver mensagens corrigidas à fila de origem, inicialmente com velocidade baixa.
- Restringir a `RedriveAllowPolicy` para permitir somente as filas de origem esperadas.
- Criar alarmes para mensagens visíveis na DLQ, idade da mensagem mais antiga, backlog e mensagens em processamento.
- Registrar no payload e nos logs `eventId`, `correlationId`, `attempt` e `failureReason`.

### Critérios de tratamento de falhas

1. Falha transitória: deixar a mensagem retornar após o visibility timeout para retry.
2. Falha repetida: após exceder `maxReceiveCount`, mover para a DLQ.
3. Falha permanente ou payload inválido: registrar o motivo e manter a mensagem na DLQ para análise.
4. Falha corrigida: reprocessar a DLQ de forma controlada, observando o backlog da fila principal.
5. Mensagem duplicada: reconhecer como processada sem repetir efeitos no domínio.

O valor final de `VisibilityTimeout` deverá ser calculado por consumidor. Por exemplo, para uma Lambda com timeout de 10 segundos e sem batch window, iniciar com pelo menos 60 segundos e validar durante os testes.

## Escopo funcional

### Eventos

- Criar evento.
- Consultar evento.
- Listar eventos disponíveis.
- Configurar capacidade ou assentos e preços.

### Disponibilidade

- Consultar assentos de um evento.
- Consultar quantidade de ingressos disponíveis.
- Representar estados `AVAILABLE`, `HELD`, `PAYMENT_PENDING`, `CONFIRMED`, `CANCELLED` e `EXPIRED`.

### Reservas

- Criar reserva temporária.
- Bloquear o recurso por tempo limitado.
- Consultar reserva.
- Confirmar reserva mediante pagamento.
- Cancelar reserva.
- Liberar automaticamente reservas expiradas.

### Pagamentos

- Criar solicitação de pagamento de forma assíncrona.
- Simular provedor de pagamento na primeira versão.
- Processar aprovação, recusa e timeout.
- Garantir idempotência em callbacks e reprocessamentos.

### Notificações

- Notificar criação da reserva.
- Notificar aprovação ou recusa do pagamento.
- Notificar expiração ou cancelamento.

### Operação

- Configurar retry nas filas.
- Enviar mensagens com falha para DLQs.
- Reprocessar mensagens da DLQ por endpoint administrativo protegido.
- Registrar `correlationId` e `eventId` nos logs.

## Modelo Single Table

Tabela: `ReservationsTable`

| Entidade | PK | SK |
|---|---|---|
| Evento | `EVENT#eventId` | `META` |
| Assento | `EVENT#eventId` | `SEAT#seatId` |
| Reserva | `RESERVATION#reservationId` | `META` |
| Reserva por evento | `EVENT#eventId` | `RESERVATION#reservationId` |
| Reserva por cliente | `CUSTOMER#customerId` | `RESERVATION#reservationId` |
| Pagamento | `RESERVATION#reservationId` | `PAYMENT#paymentId` |
| Idempotência | `IDEMPOTENCY#key` | `META` |
| Evento processado | `EVENTID#eventId` | `CONSUMER#consumerName` |

Índices planejados:

- `GSI1`: reservas por cliente.
- `GSI2`: reservas por evento e status.
- `GSI3`: itens relacionados à expiração.

## Access patterns obrigatórios

- Buscar evento por `eventId`.
- Listar assentos de um evento.
- Reservar assento somente se estiver disponível.
- Consultar reserva por `reservationId`.
- Listar reservas de um cliente.
- Listar reservas temporárias de um evento.
- Consultar pagamento de uma reserva.
- Verificar chave de idempotência.
- Impedir reprocessamento do mesmo evento pelo mesmo consumidor.

## Regras de negócio

- Um assento não pode possuir duas reservas ativas.
- A reserva temporária deve possuir `expiresAt`.
- Somente reservas `HELD` podem iniciar pagamento.
- Somente pagamentos aprovados podem confirmar uma reserva.
- Uma reserva expirada não pode ser confirmada.
- Requisições repetidas com a mesma chave de idempotência devem produzir o mesmo resultado.
- Consumidores SQS devem ser idempotentes.
- A alteração de disponibilidade deve usar escrita condicional no DynamoDB.

## Endpoints previstos

```text
GET    /events
POST   /events
GET    /events/{eventId}
GET    /events/{eventId}/availability

POST   /reservations
GET    /reservations/{reservationId}
POST   /reservations/{reservationId}/checkout
DELETE /reservations/{reservationId}

GET    /customers/{customerId}/reservations

GET    /admin/events/{eventId}/metrics
GET    /admin/dlq/messages
POST   /admin/dlq/reprocess
```

## Requisitos não funcionais

- Operações críticas de reserva devem ser atômicas.
- Não utilizar `Scan` no fluxo principal.
- Todas as Lambdas devem possuir timeout e memória mínimos necessários.
- Manter retenção curta nos CloudWatch Logs.
- Criar alarmes de billing e monitorar mensagens acumuladas nas filas.
- Evitar NAT Gateway, serviços pagos e recursos fora do Free Tier.
- Utilizar infraestrutura como código.
- Adicionar testes unitários, de integração e de concorrência.

## Fases de implementação

- [ ] Definir linguagem e framework das Lambdas.
- [ ] Definir estrutura final da Single Table e access patterns.
- [ ] Criar infraestrutura como código.
- [ ] Criar tabela DynamoDB e índices.
- [ ] Implementar HTTP API e integração com Lambda.
- [ ] Implementar criação de eventos e assentos.
- [ ] Implementar reserva condicional.
- [ ] Implementar publicação no SNS.
- [ ] Implementar filas SQS e DLQs.
- [ ] Implementar worker de pagamento.
- [ ] Implementar expiração de reservas.
- [ ] Implementar notificações.
- [ ] Implementar idempotência.
- [ ] Implementar observabilidade.
- [ ] Criar testes de concorrência e falhas.
- [ ] Validar consumo no Free Tier.

## Fora do escopo inicial

- Pagamento real.
- Aplicativo mobile nativo.
- Multi-região.
- Alta disponibilidade entre regiões.
- CDN e domínio customizado.
- WAF e API Gateway REST API.
