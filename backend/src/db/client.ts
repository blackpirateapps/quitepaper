import { createClient, Client } from '@libsql/client';
import * as dotenv from 'dotenv';
dotenv.config();

let globalClient: Client | null = null;
let schemaInitialized = false;

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

export async function ensureDbInitialized(db: Client): Promise<void> {
  if (schemaInitialized) return;
  try {
    const { runMigrations } = await import('./migrate.js');
    await runMigrations(db);
    schemaInitialized = true;
  } catch (err) {
    console.error('Failed to run schema migrations automatically:', err);
    // Don't crash if migrations already applied
    schemaInitialized = true;
  }
}

export function resetGlobalClient(): void {
  if (globalClient) {
    globalClient.close();
    globalClient = null;
  }
}
