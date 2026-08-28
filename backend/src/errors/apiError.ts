export type ApiErrorCode =
  | 'UNAUTHORIZED'
  | 'FORBIDDEN'
  | 'BAD_REQUEST'
  | 'NOT_FOUND'
  | 'CONFLICT'
  | 'SYNC_CONFLICT'
  | 'SYNC_CURSOR_EXPIRED'
  | 'RESOURCE_NOT_FOUND'
  | 'RESOURCE_ALREADY_DELETED'
  | 'RESOURCE_NOT_OWNED'
  | 'DELETION_IN_PROGRESS'
  | 'GC_CURSOR_EXPIRED'
  | 'GC_NOT_ELIGIBLE'
  | 'CLOUD_STORAGE_DELETE_RETRYABLE'
  | 'CLOUD_STORAGE_DELETE_FAILED'
  | 'PAYLOAD_TOO_LARGE'
  | 'RATE_LIMITED'
  | 'INTERNAL_ERROR';

export class ApiError extends Error {
  constructor(
    public readonly code: ApiErrorCode,
    public readonly message: string,
    public readonly statusCode: number = 400,
    public readonly details?: unknown
  ) {
    super(message);
    this.name = 'ApiError';
  }

  toJSON() {
    return {
      error: {
        code: this.code,
        message: this.message,
        ...(this.details ? { details: this.details } : {})
      }
    };
  }
}
