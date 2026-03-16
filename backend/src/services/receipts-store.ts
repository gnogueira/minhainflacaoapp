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
