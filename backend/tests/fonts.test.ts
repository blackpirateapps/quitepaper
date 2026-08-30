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

    const sf = res.body.fonts.find((f: any) => f.family === 'San Francisco');
    expect(sf).toBeDefined();
    expect(sf.category).toBe('Sans-serif');
    expect(sf.variants.length).toBe(6);

    const quattro = res.body.fonts.find((f: any) => f.family === 'iA Writer Quattro');
    expect(quattro).toBeDefined();
    expect(quattro.category).toBe('Hybrid');
    expect(quattro.variants.length).toBe(4);
    expect(quattro.variants.map((v: any) => v.variant)).toContain('regular');
    expect(quattro.variants.map((v: any) => v.variant)).toContain('italic');
    expect(quattro.variants.map((v: any) => v.variant)).toContain('bold');
    expect(quattro.variants.map((v: any) => v.variant)).toContain('boldItalic');
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
