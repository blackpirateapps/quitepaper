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

/**
 * Resolves the Cloudinary "resource type" segment used for a public share upload/delivery,
 * based on the app-level attachment kind. Images are delivered as `image` (viewable/transformable),
 * everything else as `raw` (arbitrary bytes).
 */
export function shareResourceTypeForKind(kind: string | undefined): 'image' | 'raw' {
  return kind === 'image' ? 'image' : 'raw';
}

/**
 * Generates signed upload authorization for a PUBLIC (unencrypted) share attachment.
 * These plaintext copies live in a separate public folder from the E2E-encrypted attachments
 * and are delivered directly to anonymous viewers of a shared note page.
 */
export function createPublicShareUploadAuth(
  publicId: string,
  kind: string | undefined,
  config?: CloudinaryConfig,
  timestamp: number = Math.floor(Date.now() / 1000)
): SignedUploadParams & { resourceType: 'image' | 'raw' } {
  const resolvedConfig = config ?? getCloudinaryConfig();
  const publicFolder = (process.env.CLOUDINARY_PUBLIC_FOLDER || 'quietpaper_public')
    .replace(/^\/+|\/+$/g, '')
    .trim();
  const resourceType = shareResourceTypeForKind(kind);

  const paramsToSign: Record<string, string | number | undefined> = {
    ...(publicFolder ? { folder: publicFolder } : {}),
    public_id: publicId,
    timestamp,
  };

  const signature = generateCloudinarySignature(paramsToSign, resolvedConfig.apiSecret);
  const uploadUrl = `https://api.cloudinary.com/v1_1/${resolvedConfig.cloudName}/${resourceType}/upload`;

  return {
    uploadUrl,
    cloudName: resolvedConfig.cloudName,
    apiKey: resolvedConfig.apiKey,
    signature,
    timestamp,
    publicId,
    resourceType,
    ...(publicFolder ? { folder: publicFolder } : {}),
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
  resourceType: 'raw' | 'image' | 'video' = 'raw',
  skipFolderPrefix: boolean = false
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
  // Share attachments live in the public folder and are stored fully-qualified, so
  // skip the E2E-folder prefixing that ordinary attachment/document deletions need.
  const fullPublicId = skipFolderPrefix || (cleanFolder && publicId.startsWith(cleanFolder + '/'))
    ? publicId
    : cleanFolder
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

