import request from 'supertest';
import { createApp } from '../../src/app';

jest.mock('../../src/middleware/auth', () => ({
  authMiddleware: (req: any, _res: any, next: any) => {
    req.userId = 'user-123';
    next();
  },
}));

// eslint-disable-next-line no-var
var mockGet = jest.fn();
// eslint-disable-next-line no-var
var mockDoc = jest.fn().mockReturnValue({ get: (...args: any[]) => mockGet(...args) });

jest.mock('../../src/firebase', () => ({
  admin: { auth: () => ({ verifyIdToken: jest.fn() }) },
  db: {
    collection: jest.fn().mockReturnValue({ doc: (...args: any[]) => mockDoc(...args) }),
  },
}));

// Minimal deps — prices route doesn't use these services
const deps = { gemini: {} as any, store: {} as any, priceIndex: {} as any };

describe('GET /prices/:ean', () => {
  let app: ReturnType<typeof createApp>;

  beforeEach(() => {
    app = createApp(deps);
    jest.clearAllMocks();
    mockDoc.mockReturnValue({ get: (...args: any[]) => mockGet(...args) });
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
