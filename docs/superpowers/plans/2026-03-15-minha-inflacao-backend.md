# Minha Inflação — Backend Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and deploy the Cloud Run REST API (Node.js/TypeScript) that authenticates users via Firebase, processes receipt images through Gemini Vision, stores data in Firestore, and serves anonymized regional price comparison data.

**Architecture:** Express.js app running on Cloud Run, with all endpoints protected by Firebase ID token validation. Services use constructor injection for testability. The app factory (`createApp`) accepts service dependencies, allowing tests to inject mocks without starting a real server.

**Tech Stack:** Node.js 20, TypeScript 5, Express 4, firebase-admin 12, @google/generative-ai, Jest 29, Supertest, Docker, Google Cloud Run, Firestore, Secret Manager

---

## File Structure

```
backend/
├── src/
│   ├── index.ts                    # HTTP server: binds port, wires real services, starts app
│   ├── app.ts                      # Express app factory: accepts service deps, registers routes
│   ├── types.ts                    # All shared TypeScript interfaces
│   ├── firebase.ts                 # Firebase Admin SDK singleton (db, storage, admin)
│   ├── middleware/
│   │   └── auth.ts                 # Verifies Firebase ID token, sets req.userId
│   ├── routes/
│   │   ├── receipts.ts             # POST /receipts, PATCH /:id/confirm, GET /receipts, GET /:id
│   │   └── prices.ts               # GET /prices/:ean
│   └── services/
│       ├── gemini.ts               # GeminiService: call Gemini Vision, parse JSON, retry once
│       ├── receipts-store.ts       # ReceiptsStore: Firestore CRUD for receipts + items subcollection
│       └── price-index.ts          # PriceIndexService: atomic transaction to update price_index
├── tests/
│   ├── middleware/
│   │   └── auth.test.ts
│   ├── routes/
│   │   ├── receipts.test.ts
│   │   └── prices.test.ts
│   └── services/
│       ├── gemini.test.ts
│       ├── receipts-store.test.ts
│       └── price-index.test.ts
├── Dockerfile
├── .dockerignore
├── package.json
├── tsconfig.json
├── jest.config.js
└── .env.example

firestore.rules                     # Firestore security rules (project root)
firestore.indexes.json              # Composite indexes (project root)
```

---

## Chunk 1: Project Setup + Auth Middleware

### Task 1: Initialize backend project

**Files:**
- Create: `backend/package.json`
- Create: `backend/tsconfig.json`
- Create: `backend/jest.config.js`
- Create: `backend/.env.example`
- Create: `backend/src/app.ts`
- Create: `backend/src/index.ts`

- [ ] **Step 1: Create directory structure**

```bash
mkdir -p backend/src/middleware backend/src/routes backend/src/services \
         backend/tests/middleware backend/tests/routes backend/tests/services
```

- [ ] **Step 2: Create `backend/package.json`**

```json
{
  "name": "minha-inflacao-api",
  "version": "1.0.0",
  "main": "dist/index.js",
  "scripts": {
    "build": "tsc",
    "start": "node dist/index.js",
    "dev": "ts-node src/index.ts",
    "test": "jest",
    "test:watch": "jest --watch"
  },
  "dependencies": {
    "@google/generative-ai": "^0.21.0",
    "express": "^4.18.2",
    "firebase-admin": "^12.0.0"
  },
  "devDependencies": {
    "@types/express": "^4.17.21",
    "@types/jest": "^29.5.12",
    "@types/node": "^20.11.5",
    "@types/supertest": "^6.0.2",
    "jest": "^29.7.0",
    "supertest": "^6.3.4",
    "ts-jest": "^29.1.2",
    "ts-node": "^10.9.2",
    "typescript": "^5.3.3"
  }
}
```

- [ ] **Step 3: Install dependencies**

Run (from `backend/`): `npm install`
Expected: `node_modules/` created, no errors.

- [ ] **Step 4: Create `backend/tsconfig.json`**

```json
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "commonjs",
    "lib": ["ES2020"],
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist", "tests"]
}
```

- [ ] **Step 5: Create `backend/jest.config.js`**

```js
/** @type {import('jest').Config} */
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/tests'],
  testMatch: ['**/*.test.ts'],
  collectCoverageFrom: ['src/**/*.ts', '!src/index.ts'],
};
```

- [ ] **Step 6: Create `backend/.env.example`**

```
GEMINI_API_KEY=your_gemini_api_key_here
FIREBASE_PROJECT_ID=your_project_id
# For local dev only — set path to service account JSON
GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
PORT=8080
```

- [ ] **Step 7: Create `backend/src/app.ts`**

```typescript
import express from 'express';

export function createApp(): express.Application {
  const app = express();
  app.use(express.json());

  app.get('/health', (_req, res) => {
    res.json({ status: 'ok' });
  });

  return app;
}
```

- [ ] **Step 8: Create `backend/src/index.ts`**

```typescript
import { createApp } from './app';

const PORT = process.env.PORT ?? '8080';
const app = createApp();

app.listen(Number(PORT), () => {
  console.log(`Server running on port ${PORT}`);
});
```

- [ ] **Step 9: Verify it compiles**

Run (from `backend/`): `npx tsc --noEmit`
Expected: No errors.

- [ ] **Step 10: Commit**

```bash
git add backend/
git commit -m "feat: initialize Cloud Run backend project"
```

---

### Task 2: TypeScript types

**Files:**
- Create: `backend/src/types.ts`

- [ ] **Step 1: Create `backend/src/types.ts`**

```typescript
import type { Request } from 'express';
import type * as admin from 'firebase-admin';

export interface ReceiptItem {
  ean: string | null;
  rawName: string;
  quantity: number;
  unit: 'un' | 'kg' | 'L' | 'g' | 'ml';
  unitPrice: number;
  totalPrice: number;
  confidence: 'high' | 'medium' | 'low';
}

export interface ParsedReceipt {
  storeName: string;
  storeAddress: string;
  cep: string;
  receiptDate: string; // ISO 8601
  total: number;
  items: ReceiptItem[];
}

export interface Receipt {
  userId: string;
  storeName: string;
  storeAddress: string;
  cep5: string;
  date: admin.firestore.Timestamp;
  total: number;
  status: 'pending_review' | 'confirmed' | 'error';
  imageUrl: string;
  createdAt: admin.firestore.Timestamp;
}

export interface ReceiptWithId extends Receipt {
  id: string;
}

export interface PriceIndex {
  ean: string;
  cep5: string;
  avgPrice: number;
  minPrice: number;
  maxPrice: number;
  count: number;
  lastUpdated: admin.firestore.Timestamp;
}

export interface AuthenticatedRequest extends Request {
  userId: string;
}
```

- [ ] **Step 2: Verify types compile**

Run: `npx tsc --noEmit`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add backend/src/types.ts
git commit -m "feat: add shared TypeScript interfaces"
```

---

### Task 3: Firebase Admin initialization

**Files:**
- Create: `backend/src/firebase.ts`

- [ ] **Step 1: Create `backend/src/firebase.ts`**

```typescript
import * as admin from 'firebase-admin';

// Guard against double-initialization in hot-reload environments
if (!admin.apps.length) {
  admin.initializeApp();
}

export const db = admin.firestore();
export const storage = admin.storage();
export { admin };
```

> In Cloud Run, `initializeApp()` with no arguments uses Application Default Credentials automatically.
> For local dev, set `GOOGLE_APPLICATION_CREDENTIALS` env var to the path of your service account JSON.

- [ ] **Step 2: Verify compiles**

Run: `npx tsc --noEmit`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add backend/src/firebase.ts
git commit -m "feat: initialize Firebase Admin SDK"
```

---

### Task 4: Auth middleware (TDD)

**Files:**
- Create: `backend/tests/middleware/auth.test.ts`
- Create: `backend/src/middleware/auth.ts`

- [ ] **Step 1: Write the failing tests**

Create `backend/tests/middleware/auth.test.ts`:

```typescript
import { Request, Response, NextFunction } from 'express';

// Mock firebase module before importing middleware
jest.mock('../../src/firebase', () => ({
  admin: {
    auth: () => ({
      verifyIdToken: jest.fn(),
    }),
  },
}));

import { authMiddleware } from '../../src/middleware/auth';
import { admin } from '../../src/firebase';

describe('authMiddleware', () => {
  let mockReq: Partial<Request>;
  let mockRes: Partial<Response>;
  let mockNext: NextFunction;

  beforeEach(() => {
    mockReq = { headers: {} };
    mockRes = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn(),
    };
    mockNext = jest.fn();
    jest.clearAllMocks();
  });

  it('returns 401 when Authorization header is missing', async () => {
    await authMiddleware(mockReq as Request, mockRes as Response, mockNext);

    expect(mockRes.status).toHaveBeenCalledWith(401);
    expect(mockNext).not.toHaveBeenCalled();
  });

  it('returns 401 when Authorization header does not start with Bearer', async () => {
    mockReq.headers = { authorization: 'Basic some-token' };

    await authMiddleware(mockReq as Request, mockRes as Response, mockNext);

    expect(mockRes.status).toHaveBeenCalledWith(401);
    expect(mockNext).not.toHaveBeenCalled();
  });

  it('returns 401 when token verification fails', async () => {
    mockReq.headers = { authorization: 'Bearer invalid-token' };
    (admin.auth().verifyIdToken as jest.Mock).mockRejectedValue(new Error('Invalid token'));

    await authMiddleware(mockReq as Request, mockRes as Response, mockNext);

    expect(mockRes.status).toHaveBeenCalledWith(401);
    expect(mockNext).not.toHaveBeenCalled();
  });

  it('sets userId on request and calls next when token is valid', async () => {
    mockReq.headers = { authorization: 'Bearer valid-token' };
    (admin.auth().verifyIdToken as jest.Mock).mockResolvedValue({ uid: 'user-123' });

    await authMiddleware(mockReq as Request, mockRes as Response, mockNext);

    expect((mockReq as any).userId).toBe('user-123');
    expect(mockNext).toHaveBeenCalled();
    expect(mockRes.status).not.toHaveBeenCalled();
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npx jest tests/middleware/auth.test.ts --no-coverage`
Expected: FAIL — `Cannot find module '../../src/middleware/auth'`

- [ ] **Step 3: Implement auth middleware**

Create `backend/src/middleware/auth.ts`:

```typescript
import { Request, Response, NextFunction } from 'express';
import { admin } from '../firebase';

export async function authMiddleware(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  const authHeader = req.headers.authorization;

  if (!authHeader?.startsWith('Bearer ')) {
    res.status(401).json({ error: 'Missing or invalid Authorization header' });
    return;
  }

  const token = authHeader.slice(7);

  try {
    const decoded = await admin.auth().verifyIdToken(token);
    (req as any).userId = decoded.uid;
    next();
  } catch {
    res.status(401).json({ error: 'Invalid or expired token' });
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `npx jest tests/middleware/auth.test.ts --no-coverage`
Expected: PASS — 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add backend/src/middleware/auth.ts backend/tests/middleware/auth.test.ts
git commit -m "feat: add Firebase auth middleware with tests"
```

---

## Chunk 2: Services

### Task 5: Gemini service (TDD)

**Files:**
- Create: `backend/tests/services/gemini.test.ts`
- Create: `backend/src/services/gemini.ts`

- [ ] **Step 1: Write the failing tests**

Create `backend/tests/services/gemini.test.ts`:

```typescript
import { GeminiService } from '../../src/services/gemini';
import type { ParsedReceipt } from '../../src/types';

const validParsedReceipt: ParsedReceipt = {
  storeName: 'Supermercado Praça',
  storeAddress: 'Rua das Flores, 123',
  cep: '01310',
  receiptDate: '2024-03-15T00:00:00.000Z',
  total: 45.90,
  items: [
    {
      ean: '7891000315507',
      rawName: 'ARROZ TIO JOAO 5KG',
      quantity: 1,
      unit: 'un',
      unitPrice: 25.90,
      totalPrice: 25.90,
      confidence: 'high',
    },
  ],
};

describe('GeminiService', () => {
  const mockGenerateContent = jest.fn();
  const mockModel = { generateContent: mockGenerateContent } as any;
  let service: GeminiService;

  beforeEach(() => {
    service = new GeminiService(mockModel);
    jest.clearAllMocks();
  });

  it('returns parsed receipt from valid Gemini JSON response', async () => {
    mockGenerateContent.mockResolvedValue({
      response: { text: () => JSON.stringify(validParsedReceipt) },
    });

    const result = await service.parseReceipt('gs://bucket/image.jpg');

    expect(result).toEqual(validParsedReceipt);
    expect(mockGenerateContent).toHaveBeenCalledTimes(1);
  });

  it('strips markdown code fences before parsing', async () => {
    const withFences = '```json\n' + JSON.stringify(validParsedReceipt) + '\n```';
    mockGenerateContent.mockResolvedValue({
      response: { text: () => withFences },
    });

    const result = await service.parseReceipt('gs://bucket/image.jpg');

    expect(result).toEqual(validParsedReceipt);
  });

  it('retries once on invalid JSON and returns null after second failure', async () => {
    mockGenerateContent.mockResolvedValue({
      response: { text: () => 'not valid json {{' },
    });

    const result = await service.parseReceipt('gs://bucket/image.jpg');

    expect(result).toBeNull();
    expect(mockGenerateContent).toHaveBeenCalledTimes(2);
  });

  it('returns null immediately when Gemini throws an error', async () => {
    mockGenerateContent.mockRejectedValue(new Error('API unavailable'));

    const result = await service.parseReceipt('gs://bucket/image.jpg');

    expect(result).toBeNull();
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npx jest tests/services/gemini.test.ts --no-coverage`
Expected: FAIL — `Cannot find module '../../src/services/gemini'`

- [ ] **Step 3: Implement GeminiService**

Create `backend/src/services/gemini.ts`:

```typescript
import { GenerativeModel, Part } from '@google/generative-ai';
import type { ParsedReceipt } from '../types';

const RECEIPT_PROMPT = `You are a Brazilian fiscal receipt (nota fiscal) parser.
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
- Return ONLY the JSON object, no markdown, no explanation`;

function stripMarkdownFences(text: string): string {
  return text.replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/i, '').trim();
}

function tryParseJson(text: string): ParsedReceipt | null {
  try {
    return JSON.parse(stripMarkdownFences(text)) as ParsedReceipt;
  } catch {
    return null;
  }
}

export class GeminiService {
  constructor(private model: GenerativeModel) {}

  async parseReceipt(imageGcsUrl: string): Promise<ParsedReceipt | null> {
    const imagePart: Part = {
      fileData: { mimeType: 'image/jpeg', fileUri: imageGcsUrl },
    };

    for (let attempt = 0; attempt < 2; attempt++) {
      try {
        const result = await this.model.generateContent([RECEIPT_PROMPT, imagePart]);
        const parsed = tryParseJson(result.response.text());
        if (parsed) return parsed;
      } catch (err) {
        console.error(`Gemini attempt ${attempt + 1} failed:`, err);
        return null;
      }
    }

    return null;
  }
}

export function createGeminiService(): GeminiService {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const { GoogleGenerativeAI } = require('@google/generative-ai');
  const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY!);
  const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });
  return new GeminiService(model);
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `npx jest tests/services/gemini.test.ts --no-coverage`
Expected: PASS — 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add backend/src/services/gemini.ts backend/tests/services/gemini.test.ts
git commit -m "feat: add GeminiService with receipt parsing and retry logic"
```

---

### Task 6: Receipts store service (TDD)

**Files:**
- Create: `backend/tests/services/receipts-store.test.ts`
- Create: `backend/src/services/receipts-store.ts`

- [ ] **Step 1: Write the failing tests**

Create `backend/tests/services/receipts-store.test.ts`:

```typescript
import { ReceiptsStore } from '../../src/services/receipts-store';
import type { ParsedReceipt } from '../../src/types';

const sampleParsed: ParsedReceipt = {
  storeName: 'Supermercado',
  storeAddress: 'Rua A, 1',
  cep: '01310100',
  receiptDate: '2024-03-15T00:00:00.000Z',
  total: 100,
  items: [
    { ean: '123', rawName: 'PRODUTO', quantity: 1, unit: 'un', unitPrice: 100, totalPrice: 100, confidence: 'high' },
  ],
};

// Build a chainable Firestore mock
const mockItemsAdd = jest.fn().mockResolvedValue({});
const mockItemsCollection = { add: mockItemsAdd };

const mockDocRef = {
  id: 'receipt-123',
  get: jest.fn(),
  update: jest.fn(),
  collection: jest.fn().mockReturnValue(mockItemsCollection),
};

const mockCollectionRef = {
  doc: jest.fn().mockReturnValue(mockDocRef),
  add: jest.fn().mockResolvedValue({ id: 'receipt-123' }),
  where: jest.fn().mockReturnThis(),
  orderBy: jest.fn().mockReturnThis(),
  limit: jest.fn().mockReturnThis(),
  startAfter: jest.fn().mockReturnThis(),
  get: jest.fn(),
};

const mockDb = {
  collection: jest.fn().mockReturnValue(mockCollectionRef),
} as any;

describe('ReceiptsStore', () => {
  let store: ReceiptsStore;

  beforeEach(() => {
    store = new ReceiptsStore(mockDb);
    jest.clearAllMocks();
    mockDb.collection.mockReturnValue(mockCollectionRef);
    mockCollectionRef.doc.mockReturnValue(mockDocRef);
    mockCollectionRef.add.mockResolvedValue({ id: 'receipt-123' });
  });

  describe('createPendingReceipt', () => {
    it('creates a receipt with status pending_review and returns the id', async () => {
      const id = await store.createPendingReceipt('user-1', 'gs://bucket/img.jpg', sampleParsed);

      expect(mockCollectionRef.add).toHaveBeenCalledWith(
        expect.objectContaining({ userId: 'user-1', status: 'pending_review', imageUrl: 'gs://bucket/img.jpg' }),
      );
      expect(id).toBe('receipt-123');
    });

    it('extracts the first 5 CEP digits from the parsed receipt', async () => {
      await store.createPendingReceipt('user-1', 'gs://bucket/img.jpg', sampleParsed);

      expect(mockCollectionRef.add).toHaveBeenCalledWith(
        expect.objectContaining({ cep5: '01310' }),
      );
    });
  });

  describe('getReceipt', () => {
    it('returns null when the document does not exist', async () => {
      mockDocRef.get.mockResolvedValue({ exists: false });

      const result = await store.getReceipt('receipt-123');

      expect(result).toBeNull();
    });

    it('returns receipt with id when document exists', async () => {
      mockDocRef.get.mockResolvedValue({
        exists: true,
        id: 'receipt-123',
        data: () => ({ userId: 'user-1', storeName: 'Loja' }),
      });

      const result = await store.getReceipt('receipt-123');

      expect(result).toEqual(expect.objectContaining({ id: 'receipt-123', userId: 'user-1' }));
    });
  });

  describe('confirmReceipt', () => {
    it('updates status to confirmed and writes items to subcollection', async () => {
      await store.confirmReceipt('receipt-123', sampleParsed);

      expect(mockDocRef.update).toHaveBeenCalledWith(
        expect.objectContaining({ status: 'confirmed' }),
      );
      expect(mockItemsAdd).toHaveBeenCalledTimes(1);
      expect(mockItemsAdd).toHaveBeenCalledWith(
        expect.objectContaining({ ean: '123', rawName: 'PRODUTO' }),
      );
    });
  });

  describe('listReceipts', () => {
    it('returns items and null nextCursor when results fit within limit', async () => {
      mockCollectionRef.get.mockResolvedValue({
        docs: [{ id: 'r1', data: () => ({ userId: 'user-1' }) }],
      });

      const result = await store.listReceipts('user-1', 20);

      expect(result.items).toHaveLength(1);
      expect(result.nextCursor).toBeNull();
    });
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npx jest tests/services/receipts-store.test.ts --no-coverage`
Expected: FAIL — `Cannot find module '../../src/services/receipts-store'`

- [ ] **Step 3: Implement ReceiptsStore**

Create `backend/src/services/receipts-store.ts`:

```typescript
import * as admin from 'firebase-admin';
import type { ParsedReceipt, Receipt, ReceiptWithId } from '../types';

export class ReceiptsStore {
  constructor(private db: admin.firestore.Firestore) {}

  async createPendingReceipt(
    userId: string,
    imageUrl: string,
    parsed: ParsedReceipt,
  ): Promise<string> {
    const cep5 = parsed.cep.replace(/\D/g, '').slice(0, 5);
    const ref = await this.db.collection('receipts').add({
      userId,
      storeName: parsed.storeName,
      storeAddress: parsed.storeAddress,
      cep5,
      date: new Date(parsed.receiptDate),
      total: parsed.total,
      status: 'pending_review',
      imageUrl,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  async getReceipt(receiptId: string): Promise<ReceiptWithId | null> {
    const doc = await this.db.collection('receipts').doc(receiptId).get();
    if (!doc.exists) return null;
    return { id: doc.id, ...(doc.data() as Receipt) };
  }

  async listReceipts(
    userId: string,
    limit: number = 20,
    cursor?: string,
  ): Promise<{ items: ReceiptWithId[]; nextCursor: string | null }> {
    let query = this.db
      .collection('receipts')
      .where('userId', '==', userId)
      .orderBy('date', 'desc')
      .limit(limit + 1);

    if (cursor) {
      const cursorDoc = await this.db.collection('receipts').doc(cursor).get();
      if (cursorDoc.exists) query = (query as any).startAfter(cursorDoc);
    }

    const snapshot = await query.get();
    const docs = snapshot.docs;
    const hasMore = docs.length > limit;
    const items = docs
      .slice(0, limit)
      .map((d) => ({ id: d.id, ...(d.data() as Receipt) }));

    return { items, nextCursor: hasMore ? items[items.length - 1].id : null };
  }

  async confirmReceipt(receiptId: string, data: ParsedReceipt): Promise<void> {
    const cep5 = data.cep.replace(/\D/g, '').slice(0, 5);
    const ref = this.db.collection('receipts').doc(receiptId);

    await ref.update({
      storeName: data.storeName,
      storeAddress: data.storeAddress,
      cep5,
      date: new Date(data.receiptDate),
      total: data.total,
      status: 'confirmed',
    });

    const itemsRef = ref.collection('items');
    await Promise.all(data.items.map((item) => itemsRef.add(item)));
  }

  async getReceiptItems(receiptId: string): Promise<unknown[]> {
    const snapshot = await this.db
      .collection('receipts')
      .doc(receiptId)
      .collection('items')
      .get();
    return snapshot.docs.map((d) => ({ id: d.id, ...d.data() }));
  }

  async countReceiptsThisMonth(userId: string): Promise<number> {
    const now = new Date();
    const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
    const snapshot = await this.db
      .collection('receipts')
      .where('userId', '==', userId)
      .where('createdAt', '>=', startOfMonth)
      .get();
    return snapshot.size;
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `npx jest tests/services/receipts-store.test.ts --no-coverage`
Expected: PASS — 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add backend/src/services/receipts-store.ts backend/tests/services/receipts-store.test.ts
git commit -m "feat: add ReceiptsStore service with Firestore CRUD"
```

---

### Task 7: Price index service (TDD)

**Files:**
- Create: `backend/tests/services/price-index.test.ts`
- Create: `backend/src/services/price-index.ts`

- [ ] **Step 1: Write the failing tests**

Create `backend/tests/services/price-index.test.ts`:

```typescript
import { PriceIndexService } from '../../src/services/price-index';
import type { ReceiptItem } from '../../src/types';

const mockTransaction = {
  get: jest.fn(),
  set: jest.fn(),
  update: jest.fn(),
};

const mockDocRef = { id: 'doc-ref' };

const mockDb = {
  collection: jest.fn().mockReturnThis(),
  doc: jest.fn().mockReturnValue(mockDocRef),
  runTransaction: jest.fn(async (fn: (t: any) => Promise<void>) => fn(mockTransaction)),
} as any;

const item: ReceiptItem = {
  ean: '7891000315507',
  rawName: 'ARROZ',
  quantity: 1,
  unit: 'un',
  unitPrice: 25.90,
  totalPrice: 25.90,
  confidence: 'high',
};

describe('PriceIndexService', () => {
  let service: PriceIndexService;

  beforeEach(() => {
    service = new PriceIndexService(mockDb);
    jest.clearAllMocks();
    mockDb.collection.mockReturnThis();
    mockDb.doc.mockReturnValue(mockDocRef);
    mockDb.runTransaction.mockImplementation(
      async (fn: (t: any) => Promise<void>) => fn(mockTransaction),
    );
  });

  it('creates a new price_index entry when none exists', async () => {
    mockTransaction.get.mockResolvedValue({ exists: false });

    await service.updateForItem(item, '01310');

    expect(mockTransaction.set).toHaveBeenCalledWith(
      mockDocRef,
      expect.objectContaining({
        ean: '7891000315507',
        cep5: '01310',
        avgPrice: 25.90,
        minPrice: 25.90,
        maxPrice: 25.90,
        count: 1,
      }),
    );
  });

  it('updates existing entry with correct running average', async () => {
    mockTransaction.get.mockResolvedValue({
      exists: true,
      data: () => ({ avgPrice: 20.00, minPrice: 18.00, maxPrice: 22.00, count: 2 }),
    });

    await service.updateForItem(item, '01310');

    const expectedAvg = (20.00 * 2 + 25.90) / 3;
    expect(mockTransaction.update).toHaveBeenCalledWith(
      mockDocRef,
      expect.objectContaining({
        avgPrice: expect.closeTo(expectedAvg, 2),
        minPrice: 18.00,
        maxPrice: 25.90,
        count: 3,
      }),
    );
  });

  it('does not run a transaction when EAN is null', async () => {
    const itemNoEan = { ...item, ean: null };

    await service.updateForItem(itemNoEan, '01310');

    expect(mockDb.runTransaction).not.toHaveBeenCalled();
  });

  it('updates all items with EAN in updateForReceipt', async () => {
    mockTransaction.get.mockResolvedValue({ exists: false });
    const items = [item, { ...item, ean: null }, { ...item, ean: '9999' }];

    await service.updateForReceipt(items, '01310');

    // Only 2 items have EAN, so 2 transactions
    expect(mockDb.runTransaction).toHaveBeenCalledTimes(2);
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npx jest tests/services/price-index.test.ts --no-coverage`
Expected: FAIL — `Cannot find module '../../src/services/price-index'`

- [ ] **Step 3: Implement PriceIndexService**

Create `backend/src/services/price-index.ts`:

```typescript
import * as admin from 'firebase-admin';
import type { ReceiptItem } from '../types';

export class PriceIndexService {
  constructor(private db: admin.firestore.Firestore) {}

  async updateForItem(item: ReceiptItem, cep5: string): Promise<void> {
    if (!item.ean) return;

    const docId = `${item.ean}_${cep5}`;
    const ref = this.db.collection('price_index').doc(docId);

    await this.db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);

      if (!snap.exists) {
        tx.set(ref, {
          ean: item.ean,
          cep5,
          avgPrice: item.unitPrice,
          minPrice: item.unitPrice,
          maxPrice: item.unitPrice,
          count: 1,
          lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
        });
      } else {
        const data = snap.data()!;
        const newCount = data.count + 1;
        const newAvg = (data.avgPrice * data.count + item.unitPrice) / newCount;

        tx.update(ref, {
          avgPrice: newAvg,
          minPrice: Math.min(data.minPrice, item.unitPrice),
          maxPrice: Math.max(data.maxPrice, item.unitPrice),
          count: newCount,
          lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    });
  }

  async updateForReceipt(items: ReceiptItem[], cep5: string): Promise<void> {
    await Promise.all(items.map((item) => this.updateForItem(item, cep5)));
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `npx jest tests/services/price-index.test.ts --no-coverage`
Expected: PASS — 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add backend/src/services/price-index.ts backend/tests/services/price-index.test.ts
git commit -m "feat: add PriceIndexService with atomic Firestore transactions"
```

---

## Chunk 3: API Routes

### Task 8: Receipts routes (TDD)

**Files:**
- Create: `backend/tests/routes/receipts.test.ts`
- Create: `backend/src/routes/receipts.ts`
- Modify: `backend/src/app.ts`
- Create: `backend/src/routes/prices.ts` (stub, needed by app.ts)

- [ ] **Step 1: Write the failing tests**

Create `backend/tests/routes/receipts.test.ts`:

```typescript
import request from 'supertest';
import { createApp } from '../../src/app';
import type { GeminiService } from '../../src/services/gemini';
import type { ReceiptsStore } from '../../src/services/receipts-store';
import type { PriceIndexService } from '../../src/services/price-index';

// Bypass auth middleware in route tests
jest.mock('../../src/middleware/auth', () => ({
  authMiddleware: (req: any, _res: any, next: any) => {
    req.userId = 'user-123';
    next();
  },
}));

// Stable mock reference for user consent lookup
const mockUserGet = jest.fn();

jest.mock('../../src/firebase', () => ({
  admin: { auth: () => ({ verifyIdToken: jest.fn() }) },
  db: {
    collection: jest.fn().mockReturnValue({
      doc: jest.fn().mockReturnValue({ get: mockUserGet }),
    }),
  },
}));

// Import db AFTER jest.mock so we get the mocked version
import { db } from '../../src/firebase';

const mockGemini: jest.Mocked<Pick<GeminiService, 'parseReceipt'>> = {
  parseReceipt: jest.fn(),
};

const mockStore: jest.Mocked<Pick<ReceiptsStore, 'createPendingReceipt' | 'getReceipt' | 'listReceipts' | 'confirmReceipt' | 'getReceiptItems' | 'countReceiptsThisMonth'>> = {
  createPendingReceipt: jest.fn(),
  getReceipt: jest.fn(),
  listReceipts: jest.fn(),
  confirmReceipt: jest.fn(),
  getReceiptItems: jest.fn(),
  countReceiptsThisMonth: jest.fn(),
};

const mockPriceIndex: jest.Mocked<Pick<PriceIndexService, 'updateForReceipt'>> = {
  updateForReceipt: jest.fn(),
};

const parsedReceipt = {
  storeName: 'Supermercado',
  storeAddress: 'Rua A',
  cep: '01310',
  receiptDate: '2024-03-15T00:00:00.000Z',
  total: 100,
  items: [{ ean: '123', rawName: 'PROD', quantity: 1, unit: 'un', unitPrice: 100, totalPrice: 100, confidence: 'high' }],
};

describe('POST /receipts', () => {
  let app: ReturnType<typeof createApp>;

  beforeEach(() => {
    app = createApp({ gemini: mockGemini as any, store: mockStore as any, priceIndex: mockPriceIndex as any });
    jest.clearAllMocks();
    mockStore.countReceiptsThisMonth.mockResolvedValue(0);
  });

  it('returns 400 when storageImagePath is missing', async () => {
    const res = await request(app)
      .post('/receipts')
      .set('Authorization', 'Bearer token')
      .send({});
    expect(res.status).toBe(400);
  });

  it('returns 429 when user has reached the 50-receipt monthly limit', async () => {
    mockStore.countReceiptsThisMonth.mockResolvedValue(50);

    const res = await request(app)
      .post('/receipts')
      .set('Authorization', 'Bearer token')
      .send({ storageImagePath: 'gs://bucket/img.jpg' });

    expect(res.status).toBe(429);
    expect(res.body).toMatchObject({ error: 'monthly_limit_reached', limit: 50 });
  });

  it('returns 422 when Gemini fails to parse the receipt', async () => {
    mockGemini.parseReceipt.mockResolvedValue(null);

    const res = await request(app)
      .post('/receipts')
      .set('Authorization', 'Bearer token')
      .send({ storageImagePath: 'gs://bucket/img.jpg' });

    expect(res.status).toBe(422);
  });

  it('returns 200 with receiptId and parsedData on success', async () => {
    mockGemini.parseReceipt.mockResolvedValue(parsedReceipt);
    mockStore.createPendingReceipt.mockResolvedValue('receipt-123');

    const res = await request(app)
      .post('/receipts')
      .set('Authorization', 'Bearer token')
      .send({ storageImagePath: 'gs://bucket/img.jpg' });

    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({ receiptId: 'receipt-123', status: 'pending_review' });
    expect(res.body.parsedData).toBeDefined();
  });
});

describe('PATCH /receipts/:id/confirm', () => {
  let app: ReturnType<typeof createApp>;

  beforeEach(() => {
    app = createApp({ gemini: mockGemini as any, store: mockStore as any, priceIndex: mockPriceIndex as any });
    jest.clearAllMocks();
  });

  it('returns 404 when receipt is not found', async () => {
    mockStore.getReceipt.mockResolvedValue(null);

    const res = await request(app)
      .patch('/receipts/receipt-123/confirm')
      .set('Authorization', 'Bearer token')
      .send(parsedReceipt);

    expect(res.status).toBe(404);
  });

  it('returns 403 when receipt belongs to another user', async () => {
    mockStore.getReceipt.mockResolvedValue({ id: 'receipt-123', userId: 'other-user' } as any);

    const res = await request(app)
      .patch('/receipts/receipt-123/confirm')
      .set('Authorization', 'Bearer token')
      .send(parsedReceipt);

    expect(res.status).toBe(403);
  });

  it('confirms receipt and updates price_index when consentSharing is true', async () => {
    mockStore.getReceipt.mockResolvedValue({ id: 'receipt-123', userId: 'user-123' } as any);
    mockUserGet.mockResolvedValue({ data: () => ({ consentSharing: true }) });
    mockStore.confirmReceipt.mockResolvedValue(undefined);
    mockPriceIndex.updateForReceipt.mockResolvedValue(undefined);

    const res = await request(app)
      .patch('/receipts/receipt-123/confirm')
      .set('Authorization', 'Bearer token')
      .send(parsedReceipt);

    expect(res.status).toBe(200);
    expect(mockPriceIndex.updateForReceipt).toHaveBeenCalled();
  });

  it('does NOT update price_index when consentSharing is false', async () => {
    mockStore.getReceipt.mockResolvedValue({ id: 'receipt-123', userId: 'user-123' } as any);
    mockUserGet.mockResolvedValue({ data: () => ({ consentSharing: false }) });
    mockStore.confirmReceipt.mockResolvedValue(undefined);

    const res = await request(app)
      .patch('/receipts/receipt-123/confirm')
      .set('Authorization', 'Bearer token')
      .send(parsedReceipt);

    expect(res.status).toBe(200);
    expect(mockPriceIndex.updateForReceipt).not.toHaveBeenCalled();
  });
});

describe('GET /receipts', () => {
  let app: ReturnType<typeof createApp>;

  beforeEach(() => {
    app = createApp({ gemini: mockGemini as any, store: mockStore as any, priceIndex: mockPriceIndex as any });
    jest.clearAllMocks();
  });

  it('returns paginated receipts for authenticated user', async () => {
    mockStore.listReceipts.mockResolvedValue({ items: [{ id: 'r1' } as any], nextCursor: null });

    const res = await request(app)
      .get('/receipts')
      .set('Authorization', 'Bearer token');

    expect(res.status).toBe(200);
    expect(res.body.items).toHaveLength(1);
  });
});

describe('GET /receipts/:id', () => {
  let app: ReturnType<typeof createApp>;

  beforeEach(() => {
    app = createApp({ gemini: mockGemini as any, store: mockStore as any, priceIndex: mockPriceIndex as any });
    jest.clearAllMocks();
  });

  it('returns 404 when receipt not found', async () => {
    mockStore.getReceipt.mockResolvedValue(null);

    const res = await request(app)
      .get('/receipts/receipt-123')
      .set('Authorization', 'Bearer token');

    expect(res.status).toBe(404);
  });

  it('returns 403 when receipt belongs to another user', async () => {
    mockStore.getReceipt.mockResolvedValue({ id: 'receipt-123', userId: 'other-user' } as any);

    const res = await request(app)
      .get('/receipts/receipt-123')
      .set('Authorization', 'Bearer token');

    expect(res.status).toBe(403);
  });

  it('returns receipt with items', async () => {
    mockStore.getReceipt.mockResolvedValue({ id: 'receipt-123', userId: 'user-123' } as any);
    mockStore.getReceiptItems.mockResolvedValue([{ ean: '123' }]);

    const res = await request(app)
      .get('/receipts/receipt-123')
      .set('Authorization', 'Bearer token');

    expect(res.status).toBe(200);
    expect(res.body.receipt).toBeDefined();
    expect(res.body.items).toHaveLength(1);
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npx jest tests/routes/receipts.test.ts --no-coverage`
Expected: FAIL — module not found errors

- [ ] **Step 3: Update `backend/src/app.ts` to accept service dependencies**

```typescript
import express from 'express';
import { authMiddleware } from './middleware/auth';
import type { GeminiService } from './services/gemini';
import type { ReceiptsStore } from './services/receipts-store';
import type { PriceIndexService } from './services/price-index';
import { createReceiptsRouter } from './routes/receipts';
import { createPricesRouter } from './routes/prices';

export interface AppDeps {
  gemini: GeminiService;
  store: ReceiptsStore;
  priceIndex: PriceIndexService;
}

export function createApp(deps?: AppDeps): express.Application {
  const app = express();
  app.use(express.json());

  app.get('/health', (_req, res) => {
    res.json({ status: 'ok' });
  });

  if (deps) {
    app.use('/receipts', authMiddleware, createReceiptsRouter(deps));
    app.use('/prices', authMiddleware, createPricesRouter());
  }

  return app;
}
```

- [ ] **Step 4: Create `backend/src/routes/receipts.ts`**

```typescript
import { Router } from 'express';
import { db } from '../firebase';
import type { AppDeps } from '../app';
import type { ParsedReceipt } from '../types';

const MONTHLY_RECEIPT_LIMIT = 50;

export function createReceiptsRouter(deps: AppDeps): Router {
  const router = Router();

  // POST /receipts — process a new receipt
  router.post('/', async (req, res) => {
    const userId = (req as any).userId as string;
    const { storageImagePath } = req.body;

    if (!storageImagePath) {
      res.status(400).json({ error: 'storageImagePath is required' });
      return;
    }

    // Rate limit: count receipts uploaded this calendar month
    const monthCount = await deps.store.countReceiptsThisMonth(userId);
    if (monthCount >= MONTHLY_RECEIPT_LIMIT) {
      res.status(429).json({ error: 'monthly_limit_reached', limit: MONTHLY_RECEIPT_LIMIT });
      return;
    }

    const parsedData = await deps.gemini.parseReceipt(storageImagePath);
    if (!parsedData) {
      res.status(422).json({ error: 'Could not parse receipt. Please try again with a clearer photo.' });
      return;
    }

    const receiptId = await deps.store.createPendingReceipt(userId, storageImagePath, parsedData);
    res.json({ receiptId, status: 'pending_review', parsedData });
  });

  // GET /receipts — list receipts for authenticated user
  router.get('/', async (req, res) => {
    const userId = (req as any).userId as string;
    const limit = Math.min(Number(req.query.limit) || 20, 50);
    const cursor = req.query.cursor as string | undefined;

    const result = await deps.store.listReceipts(userId, limit, cursor);
    res.json(result);
  });

  // GET /receipts/:id — get one receipt with its items
  router.get('/:id', async (req, res) => {
    const userId = (req as any).userId as string;
    const receipt = await deps.store.getReceipt(req.params.id);

    if (!receipt) {
      res.status(404).json({ error: 'Receipt not found' });
      return;
    }
    if (receipt.userId !== userId) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    const items = await deps.store.getReceiptItems(req.params.id);
    res.json({ receipt, items });
  });

  // PATCH /receipts/:id/confirm — confirm receipt after manual review
  router.patch('/:id/confirm', async (req, res) => {
    const userId = (req as any).userId as string;
    const receipt = await deps.store.getReceipt(req.params.id);

    if (!receipt) {
      res.status(404).json({ error: 'Receipt not found' });
      return;
    }
    if (receipt.userId !== userId) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    const data = req.body as ParsedReceipt;
    await deps.store.confirmReceipt(req.params.id, data);

    // Update price index only for users who opted in to data sharing
    const userDoc = await db.collection('users').doc(userId).get();
    if (userDoc.data()?.consentSharing === true) {
      const cep5 = data.cep.replace(/\D/g, '').slice(0, 5);
      await deps.priceIndex.updateForReceipt(data.items, cep5);
    }

    res.json({ receiptId: req.params.id, status: 'confirmed' });
  });

  return router;
}
```

- [ ] **Step 5: Create stub `backend/src/routes/prices.ts`** (needed for app.ts to compile)

```typescript
import { Router } from 'express';

export function createPricesRouter(): Router {
  return Router(); // implemented in next task
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `npx jest tests/routes/receipts.test.ts --no-coverage`
Expected: PASS — 10 tests pass.

- [ ] **Step 7: Commit**

```bash
git add backend/src/app.ts backend/src/routes/receipts.ts backend/src/routes/prices.ts \
        backend/tests/routes/receipts.test.ts
git commit -m "feat: add receipts API routes with rate limiting and ownership checks"
```

---

### Task 9: Prices route (TDD)

**Files:**
- Create: `backend/tests/routes/prices.test.ts`
- Modify: `backend/src/routes/prices.ts`

- [ ] **Step 1: Write the failing tests**

Create `backend/tests/routes/prices.test.ts`:

```typescript
import request from 'supertest';
import { createApp } from '../../src/app';

jest.mock('../../src/middleware/auth', () => ({
  authMiddleware: (req: any, _res: any, next: any) => {
    req.userId = 'user-123';
    next();
  },
}));

const mockGet = jest.fn();
const mockDoc = jest.fn().mockReturnValue({ get: mockGet });
const mockCollection = jest.fn().mockReturnValue({ doc: mockDoc });

jest.mock('../../src/firebase', () => ({
  admin: { auth: () => ({ verifyIdToken: jest.fn() }) },
  db: {
    collection: mockCollection,
  },
}));

// Minimal deps — prices route doesn't use these services
const deps = { gemini: {} as any, store: {} as any, priceIndex: {} as any };

describe('GET /prices/:ean', () => {
  let app: ReturnType<typeof createApp>;

  beforeEach(() => {
    app = createApp(deps);
    jest.clearAllMocks();
  });

  it('returns 400 when region query param is missing', async () => {
    const res = await request(app)
      .get('/prices/7891000315507')
      .set('Authorization', 'Bearer token');
    expect(res.status).toBe(400);
  });

  it('returns 404 when price_index document does not exist', async () => {
    mockGet.mockResolvedValue({ exists: false });

    const res = await request(app)
      .get('/prices/7891000315507?region=01310')
      .set('Authorization', 'Bearer token');
    expect(res.status).toBe(404);
  });

  it('returns 404 when count is less than 3 (privacy protection)', async () => {
    mockGet.mockResolvedValue({
      exists: true,
      data: () => ({ ean: '7891000315507', cep5: '01310', avgPrice: 25.90, count: 2 }),
    });

    const res = await request(app)
      .get('/prices/7891000315507?region=01310')
      .set('Authorization', 'Bearer token');
    expect(res.status).toBe(404);
  });

  it('returns price data when count is 3 or more', async () => {
    mockGet.mockResolvedValue({
      exists: true,
      data: () => ({ ean: '7891000315507', cep5: '01310', avgPrice: 25.90, minPrice: 22.00, maxPrice: 28.00, count: 5 }),
    });

    const res = await request(app)
      .get('/prices/7891000315507?region=01310')
      .set('Authorization', 'Bearer token');
    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({ ean: '7891000315507', avgPrice: 25.90, count: 5 });
  });

  it('strips non-digit characters from region param and uses first 5 digits for lookup', async () => {
    mockGet.mockResolvedValue({
      exists: true,
      data: () => ({ ean: '123', cep5: '01310', avgPrice: 10, count: 5 }),
    });

    // Region with a dash — should be stripped to "01310"
    await request(app)
      .get('/prices/123?region=01310-100')
      .set('Authorization', 'Bearer token');

    // mockDoc captures the docId passed to .doc()
    expect(mockDoc).toHaveBeenCalledWith('123_01310');
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npx jest tests/routes/prices.test.ts --no-coverage`
Expected: FAIL

- [ ] **Step 3: Implement prices route**

Update `backend/src/routes/prices.ts`:

```typescript
import { Router } from 'express';
import { db } from '../firebase';

const MINIMUM_COUNT_FOR_PRIVACY = 3;

export function createPricesRouter(): Router {
  const router = Router();

  router.get('/:ean', async (req, res) => {
    const { ean } = req.params;
    const region = req.query.region as string | undefined;

    if (!region) {
      res.status(400).json({ error: 'region query parameter is required' });
      return;
    }

    const cep5 = region.replace(/\D/g, '').slice(0, 5);
    const docId = `${ean}_${cep5}`;
    const snap = await db.collection('price_index').doc(docId).get();

    if (!snap.exists) {
      res.status(404).json({ error: 'No price data for this product in your region' });
      return;
    }

    const data = snap.data()!;
    if (data.count < MINIMUM_COUNT_FOR_PRIVACY) {
      res.status(404).json({ error: 'Not enough data in your region yet' });
      return;
    }

    res.json(data);
  });

  return router;
}
```

- [ ] **Step 4: Run full test suite**

Run: `npx jest --no-coverage`
Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add backend/src/routes/prices.ts backend/tests/routes/prices.test.ts
git commit -m "feat: add prices API route with k-anonymity privacy guard"
```

---

## Chunk 4: Wiring + Firestore Rules + Deployment

### Task 10: Wire production services into the server

**Files:**
- Modify: `backend/src/index.ts`

- [ ] **Step 1: Update `backend/src/index.ts` to wire real services**

```typescript
import { createApp } from './app';
import { db } from './firebase';
import { createGeminiService } from './services/gemini';
import { ReceiptsStore } from './services/receipts-store';
import { PriceIndexService } from './services/price-index';

const PORT = process.env.PORT ?? '8080';

const gemini = createGeminiService();
const store = new ReceiptsStore(db);
const priceIndex = new PriceIndexService(db);

const app = createApp({ gemini, store, priceIndex });

app.listen(Number(PORT), () => {
  console.log(`Server running on port ${PORT}`);
});
```

- [ ] **Step 2: Verify full build succeeds**

Run: `npx tsc --noEmit`
Expected: No errors.

- [ ] **Step 3: Run all tests one more time**

Run: `npx jest --no-coverage`
Expected: All tests pass.

- [ ] **Step 4: Commit**

```bash
git add backend/src/index.ts
git commit -m "feat: wire production services into Express app"
```

---

### Task 11: Firestore security rules + indexes

**Files:**
- Create: `firestore.rules`
- Create: `firestore.indexes.json`

- [ ] **Step 1: Create `firestore.rules`**

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Users: read/write own document only
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    // Receipts: user owns their receipts
    match /receipts/{receiptId} {
      allow read: if request.auth != null
        && request.auth.uid == resource.data.userId;
      allow create: if request.auth != null
        && request.auth.uid == request.resource.data.userId;
      allow update: if request.auth != null
        && request.auth.uid == resource.data.userId;
      allow delete: if false;

      // Items subcollection: readable by owner, never writable by client
      match /items/{itemId} {
        allow read: if request.auth != null
          && request.auth.uid ==
             get(/databases/$(database)/documents/receipts/$(receiptId)).data.userId;
        allow write: if false;
      }
    }

    // Products: authenticated read only, no client writes
    match /products/{ean} {
      allow read: if request.auth != null;
      allow write: if false;
    }

    // Price index: authenticated read only, no client writes
    match /price_index/{docId} {
      allow read: if request.auth != null;
      allow write: if false;
    }
  }
}
```

- [ ] **Step 2: Create `firestore.indexes.json`**

```json
{
  "indexes": [
    {
      "collectionGroup": "receipts",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "userId", "order": "ASCENDING" },
        { "fieldPath": "date", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "receipts",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "userId", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "ASCENDING" }
      ]
    }
  ],
  "fieldOverrides": []
}
```

- [ ] **Step 3: Install Firebase CLI and deploy rules**

Run from project root:
```bash
npm install -g firebase-tools
firebase login
firebase use YOUR_PROJECT_ID
firebase deploy --only firestore:rules,firestore:indexes
```
Expected: `Deploy complete!`

- [ ] **Step 4: Commit**

```bash
git add firestore.rules firestore.indexes.json
git commit -m "feat: add Firestore security rules and composite indexes"
```

---

### Task 12: Dockerfile and Cloud Run deployment

**Files:**
- Create: `backend/Dockerfile`
- Create: `backend/.dockerignore`

- [ ] **Step 1: Create `backend/Dockerfile`**

```dockerfile
FROM node:20-slim AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY tsconfig.json ./
COPY src/ ./src/
RUN npm run build

FROM node:20-slim AS runner
WORKDIR /app
ENV NODE_ENV=production
COPY package*.json ./
RUN npm ci --omit=dev
COPY --from=builder /app/dist ./dist
EXPOSE 8080
CMD ["node", "dist/index.js"]
```

- [ ] **Step 2: Create `backend/.dockerignore`**

```
node_modules
dist
tests
*.test.ts
.env
.env.*
```

- [ ] **Step 3: Build Docker image locally to verify**

Run (from `backend/`): `docker build -t minha-inflacao-api .`
Expected: Image builds with no errors, final image is slim.

- [ ] **Step 4: Enable required GCP APIs**

```bash
gcloud services enable \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  secretmanager.googleapis.com \
  artifactregistry.googleapis.com
```

- [ ] **Step 5: Store Gemini API key in Secret Manager**

```bash
echo -n "YOUR_GEMINI_API_KEY" | \
  gcloud secrets create gemini-api-key --data-file=-
```

- [ ] **Step 6: Create a service account for Cloud Run**

```bash
gcloud iam service-accounts create minha-inflacao-api \
  --display-name="Minha Inflacao API"

# Grant Firestore access
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:minha-inflacao-api@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/datastore.user"

# Grant Storage access
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:minha-inflacao-api@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/storage.objectViewer"

# Grant Secret Manager access
gcloud secrets add-iam-policy-binding gemini-api-key \
  --member="serviceAccount:minha-inflacao-api@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

- [ ] **Step 7: Deploy to Cloud Run**

```bash
gcloud run deploy minha-inflacao-api \
  --source ./backend \
  --region us-central1 \
  --allow-unauthenticated \
  --set-secrets=GEMINI_API_KEY=gemini-api-key:latest \
  --set-env-vars=FIREBASE_PROJECT_ID=YOUR_PROJECT_ID \
  --service-account=minha-inflacao-api@YOUR_PROJECT_ID.iam.gserviceaccount.com
```

Expected: Service deployed with a URL like `https://minha-inflacao-api-XXXXX-uc.a.run.app`

> Note: `--allow-unauthenticated` allows the Flutter app to reach the service over HTTPS. Application-level authentication is handled entirely by the Firebase ID token middleware (`auth.ts`) — every endpoint requires a valid token. Cloud Run IAM is not used as a second authentication gate.

- [ ] **Step 8: Test health endpoint with a Firebase token**

```bash
TOKEN=$(gcloud auth print-identity-token)
curl -H "Authorization: Bearer $TOKEN" \
  https://YOUR_CLOUD_RUN_URL/health
```
Expected: `{"status":"ok"}`

- [ ] **Step 9: Commit**

```bash
git add backend/Dockerfile backend/.dockerignore
git commit -m "feat: add Dockerfile and Cloud Run deployment config"
```

---

*Backend complete. Proceed to Flutter plan: `2026-03-15-minha-inflacao-flutter.md`*
