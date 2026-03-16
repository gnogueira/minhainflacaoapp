import { Request, Response, NextFunction } from 'express';

// Mock firebase module before importing middleware
const mockVerifyIdToken = jest.fn();
jest.mock('../../src/firebase', () => ({
  admin: {
    auth: () => ({
      verifyIdToken: mockVerifyIdToken,
    }),
  },
}));

import { authMiddleware } from '../../src/middleware/auth';
import { admin } from '../../src/firebase';

describe('authMiddleware', () => {
  let mockReq: Partial<Request>;
  let mockRes: Partial<Response>;
  let mockNext: NextFunction;

  beforeEach(() => {
    mockReq = { headers: {} };
    mockRes = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn(),
    };
    mockNext = jest.fn();
    jest.clearAllMocks();
  });

  it('returns 401 when Authorization header is missing', async () => {
    await authMiddleware(mockReq as Request, mockRes as Response, mockNext);

    expect(mockRes.status).toHaveBeenCalledWith(401);
    expect(mockNext).not.toHaveBeenCalled();
  });

  it('returns 401 when Authorization header does not start with Bearer', async () => {
    mockReq.headers = { authorization: 'Basic some-token' };

    await authMiddleware(mockReq as Request, mockRes as Response, mockNext);

    expect(mockRes.status).toHaveBeenCalledWith(401);
    expect(mockNext).not.toHaveBeenCalled();
  });

  it('returns 401 when token verification fails', async () => {
    mockReq.headers = { authorization: 'Bearer invalid-token' };
    (admin.auth().verifyIdToken as jest.Mock).mockRejectedValue(new Error('Invalid token'));

    await authMiddleware(mockReq as Request, mockRes as Response, mockNext);

    expect(mockRes.status).toHaveBeenCalledWith(401);
    expect(mockNext).not.toHaveBeenCalled();
  });

  it('sets userId on request and calls next when token is valid', async () => {
    mockReq.headers = { authorization: 'Bearer valid-token' };
    (admin.auth().verifyIdToken as jest.Mock).mockResolvedValue({ uid: 'user-123' });

    await authMiddleware(mockReq as Request, mockRes as Response, mockNext);

    expect((mockReq as any).userId).toBe('user-123');
    expect(mockNext).toHaveBeenCalled();
    expect(mockRes.status).not.toHaveBeenCalled();
  });
});
