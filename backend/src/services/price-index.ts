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
