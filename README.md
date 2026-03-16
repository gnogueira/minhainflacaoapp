# Minha Inflação

> Fotografe suas notas fiscais, acompanhe sua inflação pessoal e compare preços com sua região — de forma anônima e privada.
>
> *Photograph your receipts, track your personal inflation, and compare prices with your region — anonymously and privately.*

---

## Português

### O que é

**Minha Inflação** é um aplicativo móvel de código aberto para Android e iOS que permite ao usuário construir um histórico pessoal de gastos a partir de notas fiscais brasileiras. Usando visão computacional (Gemini Vision API), o app extrai automaticamente os produtos e preços de cada nota fotografada. Com esses dados, você pode:

- Ver como os preços dos produtos que você compra evoluem ao longo do tempo
- Comparar preços com outros usuários da mesma região (por CEP parcial), de forma anônima
- Entender sua inflação real — não a do IBGE, mas a da sua cesta de compras

### Funcionalidades

- **Leitura de nota fiscal** — fotografe a nota e a IA extrai loja, data, produtos, quantidades e preços
- **Revisão manual** — confira e corrija os dados antes de confirmar
- **Histórico pessoal** — acompanhe a evolução de preços dos produtos que você compra
- **Índice regional** — compare preços anonimamente com usuários do mesmo CEP (5 dígitos)
- **Privacidade por design** — dados só são compartilhados com consentimento explícito; o índice regional exige mínimo de 3 contribuições para ser exibido (k-anonimato)

### Arquitetura

```
Aplicativo Flutter (Android + iOS)
       │
       ├── Firebase Auth       (autenticação)
       ├── Firebase Storage    (upload das fotos)
       └── API no Cloud Run ──► Gemini Vision API
                    │
                    └── Firestore
                          ├── users/
                          ├── receipts/
                          │     └── items/
                          ├── products/
                          └── price_index/
```

### Stack

| Camada | Tecnologia |
|--------|-----------|
| Mobile | Flutter (Dart), Riverpod, go_router |
| Backend | Node.js + TypeScript, Express |
| Banco de dados | Firestore |
| Autenticação | Firebase Auth (e-mail, Google, Apple) |
| Armazenamento | Firebase Storage |
| IA | Gemini Vision API |
| Infraestrutura | Google Cloud Run |

### Como contribuir

1. Faça um fork do repositório
2. Configure seu projeto Firebase (veja [Configuração](#configuração))
3. Crie uma branch: `git checkout -b minha-feature`
4. Faça suas alterações e os testes
5. Abra um Pull Request

### Configuração

#### Pré-requisitos

- Flutter SDK ≥ 3.0
- Node.js ≥ 18
- Conta no Firebase com projeto criado
- Chave da [Gemini API](https://ai.google.dev/)

#### Backend

```bash
cd backend
cp .env.example .env          # preencha GEMINI_API_KEY e credenciais Firebase
npm install
npm run dev
```

#### App Flutter

```bash
cd minha_inflacao
flutter pub get
flutter run
```

> **Atenção:** Para rodar o app você precisa gerar seus próprios arquivos `google-services.json` (Android) e `GoogleService-Info.plist` (iOS) a partir do seu projeto Firebase e colocá-los em `android/app/` e `ios/Runner/` respectivamente. Os arquivos deste repositório apontam para o projeto de produção.

### Segurança e privacidade

- Nenhum dado de compra é compartilhado sem consentimento explícito do usuário
- O índice de preços usa apenas os 5 primeiros dígitos do CEP
- O índice só é exibido quando há pelo menos 3 contribuições (k-anonimato)
- O backend valida o token Firebase em todas as rotas autenticadas
- Dados de outros usuários nunca são acessíveis diretamente

### Deploy do backend (Cloud Run)

#### Primeira vez

```bash
# 1. Instale a Google Cloud CLI: https://cloud.google.com/sdk/docs/install
# 2. Faça login e configure o projeto
gcloud auth login
gcloud config set project minhainflacaoapp

# 3. Execute o script de setup (habilita APIs, cria secrets, configura IAM)
GITHUB_REPO=seu-usuario/minha-inflacao \
  ./backend/scripts/setup-gcp.sh
```

O script vai exibir os valores dos secrets que precisam ser cadastrados no GitHub.

#### Secrets necessários no GitHub

| Secret | Descrição |
|--------|-----------|
| `GCP_WIF_PROVIDER` | Workload Identity Provider (exibido pelo script) |
| `GCP_WIF_SERVICE_ACCOUNT` | Service account do GitHub Actions (exibido pelo script) |

#### Deploy automático

Qualquer push para `main` que altere arquivos em `backend/` aciona o workflow [deploy-backend.yml](.github/workflows/deploy-backend.yml) automaticamente:
1. Roda os testes
2. Compila o TypeScript
3. Faz o deploy para o Cloud Run via Docker

### Licença

MIT — veja [LICENSE](LICENSE)

---

## English

### What it is

**Minha Inflação** (*My Inflation*) is an open-source mobile app for Android and iOS that lets users build a personal spending history from Brazilian fiscal receipts (*notas fiscais*). Using computer vision (Gemini Vision API), the app automatically extracts products and prices from each photographed receipt. With this data, you can:

- See how prices of products you buy evolve over time
- Compare prices with other users in the same region (by partial ZIP code), anonymously
- Understand your real inflation — not the government's index, but your own shopping basket

### Features

- **Receipt scanning** — photograph a receipt and AI extracts the store, date, products, quantities, and prices
- **Manual review** — check and correct the extracted data before confirming
- **Personal history** — track price evolution for the products you buy
- **Regional index** — compare prices anonymously with users in the same ZIP code (5 digits)
- **Privacy by design** — data is only shared with explicit consent; the regional index requires a minimum of 3 contributions before being shown (k-anonymity)

### Architecture

```
Flutter App (Android + iOS)
       │
       ├── Firebase Auth       (authentication)
       ├── Firebase Storage    (receipt image upload)
       └── Cloud Run API  ───► Gemini Vision API
                    │
                    └── Firestore
                          ├── users/
                          ├── receipts/
                          │     └── items/
                          ├── products/
                          └── price_index/
```

### Stack

| Layer | Technology |
|-------|-----------|
| Mobile | Flutter (Dart), Riverpod, go_router |
| Backend | Node.js + TypeScript, Express |
| Database | Firestore |
| Auth | Firebase Auth (email, Google, Apple Sign-In) |
| Storage | Firebase Storage |
| AI | Gemini Vision API |
| Infrastructure | Google Cloud Run |

### Contributing

1. Fork the repository
2. Set up your own Firebase project (see [Setup](#setup))
3. Create a branch: `git checkout -b my-feature`
4. Make your changes and run the tests
5. Open a Pull Request

### Setup

#### Prerequisites

- Flutter SDK ≥ 3.0
- Node.js ≥ 18
- Firebase project
- [Gemini API](https://ai.google.dev/) key

#### Backend

```bash
cd backend
cp .env.example .env          # fill in GEMINI_API_KEY and Firebase credentials
npm install
npm run dev
```

#### Flutter App

```bash
cd minha_inflacao
flutter pub get
flutter run
```

> **Note:** To run the app you need to generate your own `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) from your Firebase project and place them in `android/app/` and `ios/Runner/` respectively. The files in this repository point to the production project.

### Security & Privacy

- No purchase data is shared without explicit user consent
- The price index uses only the first 5 digits of the ZIP code
- The index is only shown when there are at least 3 contributions (k-anonymity)
- The backend validates the Firebase token on all authenticated routes
- Other users' data is never directly accessible

### Backend Deploy (Cloud Run)

#### First-time setup

```bash
# 1. Install Google Cloud CLI: https://cloud.google.com/sdk/docs/install
# 2. Log in and set your project
gcloud auth login
gcloud config set project minhainflacaoapp

# 3. Run the setup script (enables APIs, creates secrets, configures IAM)
GITHUB_REPO=your-user/minha-inflacao \
  ./backend/scripts/setup-gcp.sh
```

The script will print the secret values that need to be added to GitHub.

#### Required GitHub secrets

| Secret | Description |
|--------|-------------|
| `GCP_WIF_PROVIDER` | Workload Identity Provider (printed by the script) |
| `GCP_WIF_SERVICE_ACCOUNT` | GitHub Actions service account (printed by the script) |

#### Automated deploy

Any push to `main` that changes files under `backend/` triggers the [deploy-backend.yml](.github/workflows/deploy-backend.yml) workflow automatically:
1. Runs tests
2. Compiles TypeScript
3. Deploys to Cloud Run via Docker

### License

MIT — see [LICENSE](LICENSE)
