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
