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
