import { Router } from 'express';
import { db } from '../firebase';

const MINIMUM_COUNT_FOR_PRIVACY = 3;

export function createPricesRouter(): Router {
  const router = Router();

  router.get('/:ean', async (req, res) => {
    const { ean } = req.params;
    const region = req.query.region as string | undefined;

    if (!region) {
      res.status(400).json({ error: 'region query parameter is required' });
      return;
    }

    const cep5 = region.replace(/\D/g, '').slice(0, 5);
    const docId = `${ean}_${cep5}`;
    const snap = await db.collection('price_index').doc(docId).get();

    if (!snap.exists) {
      res.status(404).json({ error: 'No price data for this product in your region' });
      return;
    }

    const data = snap.data()!;
    if (data.count < MINIMUM_COUNT_FOR_PRIVACY) {
      res.status(404).json({ error: 'Not enough data in your region yet' });
      return;
    }

    res.json(data);
  });

  return router;
}
