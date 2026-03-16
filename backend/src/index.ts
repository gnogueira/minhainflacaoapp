import { createApp } from './app';

const PORT = process.env.PORT ?? '8080';
const app = createApp();

app.listen(Number(PORT), () => {
  console.log(`Server running on port ${PORT}`);
});
