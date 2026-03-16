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
