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
