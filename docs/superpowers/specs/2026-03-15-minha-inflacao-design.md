# Minha Inflação — Design Spec (MVP)

## Visão Geral

App Flutter (Android + iOS) que permite aos usuários fotografar notas fiscais brasileiras, extrair produtos e preços via Gemini Vision API, construir um histórico pessoal de gastos e comparar preços anonimamente com outros usuários da mesma região (por CEP parcial).

---

## Decisões de Produto

| Decisão | Escolha | Racional |
|---|---|---|
| Foco do MVP | Tracker pessoal + comparação regional | Ambos desde o início |
| Normalização de produtos | EAN (código de barras) | Notas NF-e brasileiras contêm EAN; resolve ambiguidade de nome |
| Autenticação | Email/senha + Google Sign-In + Apple Sign-In | Apple obrigatório pela App Store; email para usuários sem conta social |
| Definição de região | CEP parcial (5 primeiros dígitos) | Equivale a microrregião/bairro; não requer GPS; protege privacidade |
| Custo Gemini API | Absorvido pelo desenvolvedor no MVP | Valida produto sem atrito; limite de segurança: 50 notas/usuário/mês |
| Erro de parse | Tela de revisão manual | Qualidade dos dados é crítica para comparação regional |
| Consentimento LGPD | Opt-in explícito no onboarding | Exigência legal; gera confiança |

---

## Escopo do MVP

### Incluso
1. Autenticação (Email/senha + Google + Apple)
2. Câmera + envio ao Gemini (parse da nota fiscal)
3. Tela de revisão manual pós-parse
4. Histórico de notas do usuário
5. Comparação regional de preços por produto (CEP5 anonimizado)

### Excluído (v2+)
- Gráfico de gastos mensais
- Mini-gráficos de evolução de preço por produto
- Categorias de estabelecimento
- Alertas de preço
- Importação via QR Code NF-e (XML SEFAZ)
- Modo offline com sync posterior
- Ranking de estabelecimentos

---

## Arquitetura

```
Flutter App (Android + iOS)
       │
       ├── Firebase Auth       (autenticação)
       ├── Firebase Storage    (upload de imagens de notas)
       └── Cloud Run API  ───► Gemini Vision API
                    │
                    └── Firestore
                          ├── users/
                          ├── receipts/
                          │     └── items/
                          ├── products/
                          └── price_index/
```

### Stack Técnico

**Flutter (frontend)**
- Flutter 3.x / Dart
- `firebase_auth`, `cloud_firestore`, `firebase_storage`
- `camera`, `image_picker`
- `go_router` — navegação declarativa
- `riverpod` — gerenciamento de estado

**Cloud Run (backend)**
- Node.js 20 + TypeScript
- Express.js
- `@google/generative-ai` (Gemini SDK)
- `firebase-admin` SDK
- Docker + Cloud Build (CI/CD)
- Gemini API key armazenada no Secret Manager

---

## Modelo de Dados (Firestore)

### `users/{userId}`
```
displayName: string
email: string
createdAt: timestamp
cep5: string              // primeiros 5 dígitos do CEP
consentSharing: boolean   // opt-in LGPD para comparação regional
consentAt: timestamp
```

### `receipts/{receiptId}`
```
userId: string
storeName: string
storeAddress: string
cep5: string
date: timestamp           // data da compra (extraída da nota)
total: number
status: "pending_review" | "confirmed" | "error"
imageUrl: string          // path no Firebase Storage
createdAt: timestamp
```

### `receipts/{receiptId}/items/{itemId}`
```
ean: string | null        // código EAN — ID canônico do produto
rawName: string           // nome exato como impresso na nota
quantity: number
unit: "un" | "kg" | "L" | "g" | "ml"
unitPrice: number
totalPrice: number
confidence: "high" | "medium" | "low"  // legibilidade retornada pelo Gemini; persiste para exibição na tela de revisão
```

### `products/{ean}`
```
ean: string
canonicalName: string     // nome normalizado pelo Gemini
brand: string
category: string
unit: string
imageUrl: string | null
```
> Criado/atualizado pelo Cloud Run na primeira vez que um EAN é encontrado.

### `price_index/{ean}_{cep5}`
```
ean: string
cep5: string
avgPrice: number          // média ponderada
minPrice: number
maxPrice: number
count: number             // número de registros
lastUpdated: timestamp
```
> Atualizado atomicamente via Firestore transaction no Cloud Run.
> Somente usuários com `consentSharing=true` contribuem para este índice.

**Regras de segurança Firestore:**
- Usuário lê/escreve apenas seus próprios `receipts`
- `price_index` e `products`: somente leitura para o app (escrita exclusiva via service account do Cloud Run)

---

## API Cloud Run

Todos os endpoints exigem `Authorization: Bearer {firebaseIdToken}`.

### `POST /receipts`
Inicia o processamento de uma nota.

```
Body:    { storageImagePath: string }
Returns: {
  receiptId: string,
  status: "pending_review",
  parsedData: {
    storeName: string,
    storeAddress: string,
    cep: string,
    receiptDate: string,   // ISO 8601
    total: number,
    items: [{
      ean: string | null,
      rawName: string,
      quantity: number,
      unit: string,
      unitPrice: number,
      totalPrice: number,
      confidence: "high" | "medium" | "low"
    }]
  }
}
```
Flow: baixa imagem do Storage → chama Gemini Vision → grava rascunho no Firestore com `status: pending_review`.

---

### `PATCH /receipts/:id/confirm`
Confirma nota após revisão manual do usuário.

```
Body: {
  storeName, storeAddress, cep5, date,
  items: [{ ean, rawName, unitPrice, quantity, unit }]
}
Returns: { receiptId, status: "confirmed" }
```
Flow: valida ownership (retorna `403` se o receipt não pertence ao usuário autenticado) → atualiza receipt para `confirmed` → se `consentSharing=true`, atualiza `price_index` via Firestore transaction para cada item com EAN não-nulo (itens com EAN adicionados manualmente durante a revisão também contribuem para o índice).

---

### `GET /prices/:ean?region=CEP5`
Retorna estatísticas de preço regional para um produto.

```
Returns: { ean, cep5, avgPrice, minPrice, maxPrice, count, lastUpdated }
```
> Retorna `404` se `count < 3` — proteção de privacidade: evita identificação de usuário único em região com poucos dados.

---

### `GET /receipts`
Lista notas do usuário autenticado.

```
Query: limit (default 20), cursor (paginação)
Returns: { items: [receipt], nextCursor }
```

---

### `GET /receipts/:id`
Detalhe de uma nota com seus itens.

```
Returns: { receipt, items: [...] }
```

---

## Telas e Navegação

### Estrutura de rotas (go_router)
```
/onboarding          → Onboarding + consentimento LGPD (apenas 1ª vez)
/auth/login          → Login
/auth/register       → Cadastro
/home                → Shell route
  /home/receipts     → Lista de notas
  /home/profile      → Perfil / Configurações
/receipts/camera     → Câmera
/receipts/review     → Revisão pós-parse
/receipts/:id        → Detalhe da nota
```

### Telas

**1. Onboarding**
- Apresentação do app (2–3 slides)
- Tela de consentimento LGPD: explicação clara do que é compartilhado, opt-in explícito
- CTA: "Criar conta" / "Já tenho conta"

**2. Auth**
- Login: Email/senha + botões Google + Apple
- Cadastro: nome, email, senha
- Recuperação de senha via email

**3. Home**
- Saudação com nome do usuário
- Lista de últimas notas (estabelecimento, data, total)
- FAB "Adicionar Nota" → `/receipts/camera`

**4. Câmera**
- Viewfinder com guia de recorte para nota fiscal
- Captura manual via botão (MVP); captura automática fora do escopo do MVP
- Loading multi-etapas: "Enviando imagem… Lendo itens… Salvando…"
- Tratamento de erro com opção de retry

**5. Revisão Pós-Parse**
- Campos editáveis: estabelecimento, data, CEP
- Lista de itens editáveis: nome, EAN, quantidade, preço unitário
- Itens com `confidence: low` destacados com ícone de aviso
- Adicionar / remover itens manualmente
- Botão "Confirmar" → chama `PATCH /receipts/:id/confirm`

**6. Detalhe da Nota**
- Header: loja, data, total
- Lista de itens com:
  - Nome do produto, preço pago
  - Média regional (se `count ≥ 3`): "Média na região: R$ X,XX"
  - Badge: "Acima da média" (vermelho) / "Abaixo da média" (verde)

**7. Perfil / Configurações**
- Nome e email (read-only)
- CEP editável
- Toggle: "Compartilhar meus preços anonimamente"
- Sair / excluir conta

---

## Gemini Vision — Prompt

```
You are a Brazilian fiscal receipt (nota fiscal) parser.
Extract ALL information from this receipt image and return ONLY valid JSON.

Return this exact structure:
{
  "storeName": "string",
  "storeAddress": "string",
  "cep": "string (digits only, may be partial)",
  "receiptDate": "ISO 8601 date string",
  "total": number,
  "items": [
    {
      "ean": "string or null if not visible",
      "rawName": "exact text from receipt",
      "quantity": number,
      "unit": "un|kg|L|g|ml",
      "unitPrice": number,
      "totalPrice": number,
      "confidence": "high|medium|low"
    }
  ]
}

Rules:
- Use null for EAN if not visible or illegible, do NOT guess
- rawName must be exactly as printed, even if abbreviated
- confidence reflects legibility: high=clearly readable, low=guessed/partial
- All prices in BRL as decimal numbers (e.g. 25.90 not "R$ 25,90")
- receiptDate: if year is missing, assume current year
- Return ONLY the JSON object, no markdown, no explanation
```

---

## Tratamento de Erros

| Cenário | Comportamento | UX |
|---|---|---|
| Gemini retorna JSON inválido | Retry 1x com prompt corrigido | Transparente |
| Retry falha | Salva rascunho com campos vazios, status `error` | Tela de revisão com aviso de preenchimento manual |
| Imagem ilegível | Items vazios ou todos com `confidence: low` | Banner: "Foto com baixa qualidade. Tente novamente." + opção de retirar foto |
| EAN ausente/null | Item salvo sem EAN, não contribui para price_index | Ícone de aviso no item na tela de revisão |
| Sem conexão | Upload falha no Storage | "Sem conexão. Tente novamente." — sem fila offline no MVP |
| Gemini timeout (>30s) | Cloud Run cancela, retorna 504 | "O processamento demorou muito. Tente novamente." |

---

## Privacidade e LGPD

- Consentimento explícito (opt-in) coletado no onboarding antes de qualquer uso
- `price_index` só é atualizado para usuários com `consentSharing=true`
- `price_index` retorna `404` quando `count < 3` (k-anonimato mínimo)
- CEP parcial (5 dígitos) — não expõe endereço exato
- Imagens das notas armazenadas no Firebase Storage com regras de acesso por `userId`
- Usuário pode revogar consentimento a qualquer momento nas configurações
- Usuário pode excluir conta (e dados) nas configurações

---

## Limites e Segurança

- Máximo 50 notas/usuário/mês (Cloud Run valida antes de chamar Gemini; retorna `429 Too Many Requests` com body `{ error: "monthly_limit_reached", limit: 50 }` quando excedido)
- Chave da Gemini API armazenada no GCP Secret Manager
- Firebase ID Token validado em todos os endpoints do Cloud Run
- Firestore Security Rules: usuário acessa apenas seus próprios dados; `price_index` e `products` são somente leitura para o app
