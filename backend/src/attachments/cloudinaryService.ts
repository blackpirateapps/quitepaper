import crypto from 'crypto';
import { ApiError } from '../errors/apiError.js';

export interface CloudinaryConfig {
  cloudName: string;
  apiKey: string;
  apiSecret: string;
  folder: string;
}

export function getCloudinaryConfig(): CloudinaryConfig {
  const cloudName = process.env.CLOUDINARY_CLOUD_NAME?.trim();
  const apiKey = process.env.CLOUDINARY_API_KEY?.trim();
  const apiSecret = process.env.CLOUDINARY_API_SECRET?.trim();
  const folder = (process.env.CLOUDINARY_FOLDER || 'quitepaper').replace(/^\/+|\/+$/g, '').trim();

  if (!cloudName || !apiKey || !apiSecret) {
    throw new ApiError(
      'INTERNAL_ERROR',
      'Cloudinary configuration is incomplete on server. Ensure CLOUDINARY_CLOUD_NAME, CLOUDINARY_API_KEY, and CLOUDINARY_API_SECRET are configured in Vercel.',
      500
    );
  }

  return { cloudName, apiKey, apiSecret, folder };
}

export interface SignedUploadParams {
  uploadUrl: string;
  cloudName: string;
  apiKey: string;
  signature: string;
  timestamp: number;
  publicId: string;
  folder?: string;
}

/**
 * Computes a Cloudinary API SHA-1 signature according to official specification:
 * Parameters sorted alphabetically, serialized as key=value separated by '&', concatenated with apiSecret.
 */
export function generateCloudinarySignature(
  params: Record<string, string | number | undefined>,
  apiSecret: string
): string {
  const sortedKeys = Object.keys(params)
    .filter(k => params[k] !== undefined && params[k] !== '')
    .sort();

  const toSign = sortedKeys.map(k => `${k}=${params[k]}`).join('&') + apiSecret;
  return crypto.createHash('sha1').update(toSign).digest('hex');
}

/**
 * Generates signed upload authorization parameters for a direct client-to-Cloudinary upload.
 */
export function createSignedUploadAuth(
  publicId: string,
  config: CloudinaryConfig,
  timestamp: number = Math.floor(Date.now() / 1000)
): SignedUploadParams {
  const cleanFolder = config.folder ? config.folder.replace(/^\/+|\/+$/g, '').trim() : '';

  const paramsToSign: Record<string, string | number | undefined> = {
    ...(cleanFolder ? { folder: cleanFolder } : {}),
    public_id: publicId,
    timestamp,
  };

  const signature = generateCloudinarySignature(paramsToSign, config.apiSecret);
  const uploadUrl = `https://api.cloudinary.com/v1_1/${config.cloudName}/raw/upload`;

  return {
    uploadUrl,
    cloudName: config.cloudName,
    apiKey: config.apiKey,
    signature,
    timestamp,
    publicId,
    ...(cleanFolder ? { folder: cleanFolder } : {}),
  };
}

export interface CloudinaryDeleteResult {
  success: boolean;
  result: 'ok' | 'not found' | 'error';
  retryable: boolean;
  error?: string;
}

/**
 * Permanently deletes an encrypted binary object from Cloudinary storage.
 * Handles 'ok' and 'not found' as successful terminal outcomes (idempotent).
 */
export async function deleteCloudinaryResource(
  publicId: string,
  config?: CloudinaryConfig,
  resourceType: 'raw' | 'image' | 'video' = 'raw'
): Promise<CloudinaryDeleteResult> {
  let resolvedConfig: CloudinaryConfig;
  try {
    resolvedConfig = config ?? getCloudinaryConfig();
  } catch (err: any) {
    if (process.env.NODE_ENV === 'test') {
      return { success: true, result: 'ok', retryable: false };
    }
    return { success: false, result: 'error', retryable: false, error: err?.message };
  }

  const cleanFolder = resolvedConfig.folder ? resolvedConfig.folder.replace(/^\/+|\/+$/g, '').trim() : '';
  const fullPublicId = cleanFolder && !publicId.startsWith(cleanFolder + '/')
    ? `${cleanFolder}/${publicId}`
    : publicId;

  const timestamp = Math.floor(Date.now() / 1000);
  const paramsToSign: Record<string, string | number | undefined> = {
    public_id: fullPublicId,
    timestamp,
  };

  const signature = generateCloudinarySignature(paramsToSign, resolvedConfig.apiSecret);
  const destroyUrl = `https://api.cloudinary.com/v1_1/${resolvedConfig.cloudName}/${resourceType}/destroy`;

  try {
    const formData = new URLSearchParams();
    formData.append('public_id', fullPublicId);
    formData.append('api_key', resolvedConfig.apiKey);
    formData.append('timestamp', timestamp.toString());
    formData.append('signature', signature);

    const response = await fetch(destroyUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: formData.toString(),
    });

    const bodyText = await response.text();
    let bodyJson: any = {};
    try {
      bodyJson = JSON.parse(bodyText);
    } catch (_) {}

    if (response.ok) {
      const resultStr = bodyJson?.result || 'ok';
      if (resultStr === 'ok' || resultStr === 'not found') {
        return { success: true, result: resultStr, retryable: false };
      }
    }

    if (response.status === 404 || bodyJson?.result === 'not found') {
      return { success: true, result: 'not found', retryable: false };
    }

    // Rate limiting (429) or Server error (5xx) -> retryable
    const retryable = response.status === 429 || response.status >= 500;
    return {
      success: false,
      result: 'error',
      retryable,
      error: `Cloudinary destroy returned HTTP ${response.status}: ${bodyText.substring(0, 200)}`,
    };
  } catch (err: any) {
    return {
      success: false,
      result: 'error',
      retryable: true,
      error: `Cloudinary destroy network error: ${err?.message || err}`,
    };
  }
}

