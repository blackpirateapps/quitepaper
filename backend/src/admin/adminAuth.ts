import crypto from 'crypto';

export const ADMIN_COOKIE_NAME = 'qp_admin_session';
export const SESSION_MAX_AGE_SECONDS = 24 * 60 * 60; // 24 hours

export interface SessionPayload {
  exp: number;
  nonce: string;
}

/**
 * Retrieves the configured admin password/secret from environment variables.
 */
export function getAdminPassword(): string | undefined {
  return process.env.ADMIN_PASSWORD || process.env.ADMIN_SECRET;
}

/**
 * Securely verifies if input password matches the configured ADMIN_PASSWORD.
 * Uses SHA-256 pre-hashing to ensure fixed-length buffers for crypto.timingSafeEqual.
 */
export function verifyAdminPassword(inputPassword: string | undefined): boolean {
  const adminPassword = getAdminPassword();
  if (!adminPassword || !inputPassword) {
    return false;
  }

  const inputHash = crypto.createHash('sha256').update(String(inputPassword)).digest();
  const expectedHash = crypto.createHash('sha256').update(adminPassword).digest();

  return crypto.timingSafeEqual(inputHash, expectedHash);
}

/**
 * Creates an HMAC-SHA256 signed session cookie value.
 */
export function createAdminSession(): string {
  const adminSecret = getAdminPassword();
  if (!adminSecret) {
    throw new Error('ADMIN_PASSWORD is not configured');
  }

  const payload: SessionPayload = {
    exp: Date.now() + SESSION_MAX_AGE_SECONDS * 1000,
    nonce: crypto.randomBytes(16).toString('hex'),
  };

  const payloadBase64 = Buffer.from(JSON.stringify(payload)).toString('base64url');
  const signature = crypto
    .createHmac('sha256', adminSecret)
    .update(payloadBase64)
    .digest('base64url');

  return `${payloadBase64}.${signature}`;
}

/**
 * Verifies the admin session token extracted from cookies or headers.
 */
export function verifyAdminSessionToken(token: string | undefined): boolean {
  const adminSecret = getAdminPassword();
  if (!adminSecret || !token) {
    return false;
  }

  const parts = token.split('.');
  if (parts.length !== 2) {
    return false;
  }

  const [payloadBase64, providedSig] = parts;

  const expectedSig = crypto
    .createHmac('sha256', adminSecret)
    .update(payloadBase64)
    .digest('base64url');

  const providedSigBuf = Buffer.from(providedSig, 'utf-8');
  const expectedSigBuf = Buffer.from(expectedSig, 'utf-8');

  if (providedSigBuf.length !== expectedSigBuf.length) {
    return false;
  }

  if (!crypto.timingSafeEqual(providedSigBuf, expectedSigBuf)) {
    return false;
  }

  try {
    const payloadStr = Buffer.from(payloadBase64, 'base64url').toString('utf-8');
    const payload: SessionPayload = JSON.parse(payloadStr);

    if (typeof payload.exp !== 'number' || Date.now() > payload.exp) {
      return false;
    }

    return true;
  } catch {
    return false;
  }
}

/**
 * Parses cookies from HTTP Cookie header string.
 */
export function parseCookies(cookieHeader: string | undefined): Record<string, string> {
  const cookies: Record<string, string> = {};
  if (!cookieHeader) {
    return cookies;
  }

  const pairs = cookieHeader.split(';');
  for (const pair of pairs) {
    const idx = pair.indexOf('=');
    if (idx > -1) {
      const key = pair.substring(0, idx).trim();
      const val = pair.substring(idx + 1).trim();
      cookies[key] = decodeURIComponent(val);
    }
  }

  return cookies;
}

/**
 * Validates session from Cookie header or Bearer authorization header.
 */
export function isAuthenticatedAdmin(
  headers: Record<string, string | string[] | undefined>
): boolean {
  // 1. Check Bearer Authorization header (for API / curl usage)
  const authHeader = Array.isArray(headers['authorization'])
    ? headers['authorization'][0]
    : headers['authorization'] || (headers['Authorization'] as string | undefined);

  if (authHeader && authHeader.startsWith('Bearer ')) {
    const token = authHeader.substring(7).trim();
    if (verifyAdminPassword(token) || verifyAdminSessionToken(token)) {
      return true;
    }
  }

  // 2. Check Cookie header
  const cookieHeader = Array.isArray(headers['cookie'])
    ? headers['cookie'][0]
    : headers['cookie'] || (headers['Cookie'] as string | undefined);

  const cookies = parseCookies(cookieHeader);
  const sessionToken = cookies[ADMIN_COOKIE_NAME];

  return verifyAdminSessionToken(sessionToken);
}

/**
 * Generates the Set-Cookie header for logging in.
 */
export function getSetSessionCookieHeader(sessionToken: string): string {
  // In production (Vercel), Secure is mandatory.
  const isProd = process.env.NODE_ENV === 'production' || !!process.env.VERCEL;
  const secureFlag = isProd ? '; Secure' : '';
  return `${ADMIN_COOKIE_NAME}=${encodeURIComponent(sessionToken)}; HttpOnly; Path=/; SameSite=Lax; Max-Age=${SESSION_MAX_AGE_SECONDS}${secureFlag}`;
}

/**
 * Generates the Set-Cookie header for logging out.
 */
export function getClearSessionCookieHeader(): string {
  const isProd = process.env.NODE_ENV === 'production' || !!process.env.VERCEL;
  const secureFlag = isProd ? '; Secure' : '';
  return `${ADMIN_COOKIE_NAME}=; HttpOnly; Path=/; SameSite=Lax; Max-Age=0; Expires=Thu, 01 Jan 1970 00:00:00 GMT${secureFlag}`;
}
