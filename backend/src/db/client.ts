import { createClient, Client } from '@libsql/client';
import * as dotenv from 'dotenv';
dotenv.config();

let globalClient: Client | null = null;

export function getDbClient(overrideUrl?: string, overrideAuthToken?: string): Client {
  if (overrideUrl) {
    return createClient({
      url: overrideUrl,
      authToken: overrideAuthToken,
    });
  }

  if (!globalClient) {
    const url = process.env.TURSO_DATABASE_URL || 'file::memory:';
    const authToken = process.env.TURSO_AUTH_TOKEN;
    globalClient = createClient({
      url,
      authToken,
    });
  }

  return globalClient;
}

export function resetGlobalClient(): void {
  if (globalClient) {
    globalClient.close();
    globalClient = null;
  }
}
