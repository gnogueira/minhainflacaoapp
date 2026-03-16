import express from 'express';
import { authMiddleware } from './middleware/auth';
import type { GeminiService } from './services/gemini';
import type { ReceiptsStore } from './services/receipts-store';
import type { PriceIndexService } from './services/price-index';
import { createReceiptsRouter } from './routes/receipts';
import { createPricesRouter } from './routes/prices';

export interface AppDeps {
  gemini: GeminiService;
  store: ReceiptsStore;
  priceIndex: PriceIndexService;
}

export function createApp(deps?: AppDeps): express.Application {
  const app = express();
  app.use(express.json());

  app.get('/health', (_req, res) => {
    res.json({ status: 'ok' });
  });

  if (deps) {
    app.use('/receipts', authMiddleware, createReceiptsRouter(deps));
    app.use('/prices', authMiddleware, createPricesRouter());
  }

  return app;
}
