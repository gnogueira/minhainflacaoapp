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
