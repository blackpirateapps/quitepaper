import { describe, it, expect } from 'vitest';
import { handleApiRequest } from '../src/api/handler.js';

describe('Fonts Manifest API', () => {
  it('returns 200 OK and valid font manifest from GET /api/v1/fonts', async () => {
    const res = await handleApiRequest({
      method: 'GET',
      url: '/api/v1/fonts',
      headers: {},
    });

    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('fonts');
    expect(Array.isArray(res.body.fonts)).toBe(true);
    expect(res.body.fonts.length).toBeGreaterThan(0);

    const inter = res.body.fonts.find((f: any) => f.family === 'Inter');
    expect(inter).toBeDefined();
    expect(inter.category).toBe('Sans-serif');
    expect(inter.variants.length).toBeGreaterThanOrEqual(2);
  });

  it('supports GET /fonts/manifest.json route', async () => {
    const res = await handleApiRequest({
      method: 'GET',
      url: '/fonts/manifest.json',
      headers: {},
    });

    expect(res.statusCode).toBe(200);
    expect(res.body.fonts).toBeDefined();
  });
});
