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
