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
