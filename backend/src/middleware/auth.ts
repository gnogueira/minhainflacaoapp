import { Request, Response, NextFunction } from 'express';
import { admin } from '../firebase';

export async function authMiddleware(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  const authHeader = req.headers.authorization;

  if (!authHeader?.startsWith('Bearer ')) {
    res.status(401).json({ error: 'Missing or invalid Authorization header' });
    return;
  }

  const token = authHeader.slice(7);

  try {
    const decoded = await admin.auth().verifyIdToken(token);
    (req as any).userId = decoded.uid;
    next();
  } catch {
    res.status(401).json({ error: 'Invalid or expired token' });
  }
}
