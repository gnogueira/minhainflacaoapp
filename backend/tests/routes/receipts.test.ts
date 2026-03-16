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
// eslint-disable-next-line no-var
var mockUserGet = jest.fn();

jest.mock('../../src/firebase', () => ({
  admin: { auth: () => ({ verifyIdToken: jest.fn() }) },
  db: {
    collection: jest.fn().mockReturnValue({
      doc: jest.fn().mockReturnValue({
        get: (...args: any[]) => mockUserGet(...args),
      }),
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
  items: [{ ean: '123', rawName: 'PROD', quantity: 1, unit: 'un' as const, unitPrice: 100, totalPrice: 100, confidence: 'high' as const }],
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
