# Sistema de Reservas para Eventos de Alta Demanda

## Objetivo

Construir uma aplicação serverless para reservar ingressos ou assentos em eventos de alta demanda, evitando reservas duplicadas e suportando milhares de tentativas concorrentes.

O sistema controla reservas temporárias, processa pagamentos de forma assíncrona, libera reservas expiradas e envia notificações ao cliente sobre cada mudança de estado.

## Características principais

- Reserva atômica de assentos ou ingressos.
- Bloqueio temporário antes do pagamento.
- Prevenção de overbooking.
- Processamento assíncrono de pagamentos e notificações.
- Retry automático de mensagens com SQS.
- DLQ dedicada para cada fila de processamento.
- Idempotência nas APIs e consumidores.
- Rastreamento de reservas, pagamentos e eventos.
- Infraestrutura como código com Terraform.
- Implementação compatível com o AWS Free Tier sempre que possível.

## Stack

- Python.
- FastAPI e Mangum.
- Pydantic.
- uv para gerenciamento e lock das dependências.
- Boto3.
- AWS Lambda Powertools.
- Amazon API Gateway HTTP API.
- Amazon DynamoDB com Single Table Design.
- Amazon SNS.
- Amazon SQS e Dead Letter Queues.
- Terraform.
- GitHub Actions com Gitflow.

## State do Terraform

O state dos ambientes fica em um bucket S3 dedicado, com versionamento, bloqueio nativo por `.tflock`, bloqueio de acesso público e criptografia SSE-S3. O workflow de destruição remove todos os recursos registrados no state da aplicação, valida que o state ficou vazio e então remove todas as versões do state e do lock do ambiente `dev`. O bucket de state pertence ao bootstrap da infraestrutura de gerenciamento e permanece preservado; um próximo deploy poderá criar o state novamente.

Antes do primeiro deploy, execute manualmente o workflow **Bootstrap Terraform State**. Ele cria e configura o bucket informado em `TERRAFORM_STATE_BUCKET`. A policy da role OIDC precisa conter as permissões de bootstrap presentes em `infra/bootstrap/github-actions-policy.json`.

Para importar log groups criados por uma tentativa anterior, execute o workflow **Import Lambda Log Groups** com a confirmação `IMPORT-LOG-GROUPS`. Essa é uma operação única; depois da importação, o Terraform passa a gerenciar esses recursos pelo state.

Se uma execução for cancelada durante um `apply`, pode ficar um lock órfão no state. Nesse caso, execute **Unlock Terraform State**, informe o ID do lock exibido no erro e use a confirmação `UNLOCK-DEV`. Nunca use `-lock=false` no deploy.

```bash
cd infra/bootstrap
terraform init
terraform apply

cd ../environments/dev
cp backend.hcl.example backend.hcl
# Edite backend.hcl com o bucket exibido pelo bootstrap.
terraform init -backend-config=backend.hcl
```

Como a conta AWS não é nova, a estimativa não considera Free Tier promocional. Para o state deste projeto, o custo esperado do S3 é de aproximadamente US$ 0,01–0,05 por mês, considerando armazenamento pequeno, versionamento e uso normal do Terraform. O custo pode aumentar com muitas versões, transferências ou funcionalidades opcionais.

## Arquitetura resumida

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

O cliente recebe respostas síncronas apenas para operações da API. Processos como pagamento, expiração, notificações e métricas são executados de forma assíncrona.

## Fluxo comum do cliente

O fluxo abaixo representa a jornada normal de um cliente: consultar eventos, escolher um assento, criar uma reserva temporária, realizar o checkout e receber a confirmação.

```mermaid
sequenceDiagram
    autonumber
    actor Cliente
    participant API as HTTP API
    participant Reservation as Lambda Reservation API
    participant DB as DynamoDB
    participant SNS as SNS reservation-events
    participant PaymentQ as SQS payment-queue
    participant Payment as Lambda Payment Worker
    participant NotificationQ as SQS notification-queue
    participant Notification as Lambda Notification Worker

    Cliente->>API: GET /events
    API->>Reservation: Invoca Lambda
    Reservation->>DB: Consulta eventos disponíveis
    DB-->>Reservation: Eventos
    Reservation-->>API: Lista de eventos
    API-->>Cliente: Eventos disponíveis

    Cliente->>API: GET /events/{eventId}/availability
    API->>Reservation: Invoca Lambda
    Reservation->>DB: Consulta assentos
    DB-->>Reservation: Assentos disponíveis
    Reservation-->>API: Disponibilidade
    API-->>Cliente: Mapa de assentos

    Cliente->>API: POST /reservations
    API->>Reservation: Dados do assento + Idempotency-Key
    Reservation->>DB: Escrita condicional AVAILABLE -> HELD

    alt Assento disponível
        DB-->>Reservation: Assento bloqueado
        Reservation->>DB: Cria reserva temporária
        Reservation->>SNS: Publica ReservationHeld
        SNS-->>NotificationQ: Envia evento de notificação
        Reservation-->>API: Reserva HELD + expiresAt
        API-->>Cliente: Reserva temporária criada
    else Assento ocupado
        DB-->>Reservation: Condição falhou
        Reservation-->>API: HTTP 409 Conflict
        API-->>Cliente: Assento indisponível
    end

    Cliente->>API: POST /reservations/{id}/checkout
    API->>Reservation: Solicita pagamento
    Reservation->>DB: HELD -> PAYMENT_PENDING
    Reservation->>SNS: Publica PaymentRequested
    SNS-->>PaymentQ: Envia evento de pagamento
    Reservation-->>API: Pagamento em processamento
    API-->>Cliente: Status PAYMENT_PENDING

    PaymentQ->>Payment: Entrega mensagem
    Payment->>Payment: Processa pagamento

    alt Pagamento aprovado
        Payment->>DB: PAYMENT_PENDING -> CONFIRMED
        Payment->>SNS: Publica PaymentApproved
        SNS-->>NotificationQ: Envia confirmação
        NotificationQ->>Notification: Entrega mensagem
        Notification-->>Cliente: Envia reserva confirmada
    else Pagamento recusado
        Payment->>DB: PAYMENT_PENDING -> CANCELLED
        Payment->>DB: Libera assento
        Payment->>SNS: Publica PaymentDeclined
        SNS-->>NotificationQ: Envia recusa
        NotificationQ->>Notification: Entrega mensagem
        Notification-->>Cliente: Envia pagamento recusado
    end
```

## Expiração da reserva

Se o cliente não concluir o pagamento dentro do prazo, o worker de expiração verifica a reserva e executa:

```text
HELD -> EXPIRED
assento reservado -> AVAILABLE
```

A operação deve ser condicional para não expirar uma reserva que já tenha sido confirmada ou cancelada.

## Estados da reserva

```text
AVAILABLE
    -> HELD
    -> PAYMENT_PENDING
    -> CONFIRMED

HELD
    -> EXPIRED
    -> CANCELLED

PAYMENT_PENDING
    -> CONFIRMED
    -> CANCELLED
```

## Princípios técnicos

- Usar escrita condicional no DynamoDB para impedir reserva duplicada.
- Usar `TransactWriteItems` quando a operação precisar atualizar itens relacionados atomicamente.
- Usar idempotência para requisições repetidas e mensagens duplicadas.
- Não depender de ordenação global de mensagens; o estado deve ser validado no DynamoDB.
- Configurar DLQ para todas as filas SQS.
- Usar partial batch response nos consumidores Lambda.
- Manter regras de negócio fora do FastAPI e do Boto3.
- Usar Terraform para criar e alterar os recursos AWS.

## Estrutura do projeto

```text
reservation_service/   # Código da aplicação Python
tests/                 # Testes unitários, integração e contrato
infra/                 # Terraform, ambientes e módulos
.github/workflows/     # CI, plan, deploy e destroy
pyproject.toml         # Metadados e dependências do projeto
uv.lock               # Resolução reproduzível das dependências
PLAN.md               # Requisitos e decisões do projeto
README.md             # Visão geral e documentação inicial
```

## Segurança operacional

O workflow de destruição será exclusivamente manual, exigirá aprovação do environment `dev-destroy` e destruirá somente os recursos presentes no Terraform state do ambiente selecionado.
