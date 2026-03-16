import { createApp } from './app';
import { db } from './firebase';
import { createGeminiService } from './services/gemini';
import { ReceiptsStore } from './services/receipts-store';
import { PriceIndexService } from './services/price-index';

const PORT = process.env.PORT ?? '8080';

const gemini = createGeminiService();
const store = new ReceiptsStore(db);
const priceIndex = new PriceIndexService(db);

const app = createApp({ gemini, store, priceIndex });

app.listen(Number(PORT), () => {
  console.log(`Server running on port ${PORT}`);
});
