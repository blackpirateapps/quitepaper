import * as dotenv from 'dotenv';
dotenv.config();

import { getDbClient } from '../db/client.js';
import { runMigrations } from '../db/migrate.js';
import { backfillMissingUserEmails } from '../auth/emailSyncService.js';

async function main() {
  const args = process.argv.slice(2);
  const dryRun = args.includes('--dry-run');
  const force = args.includes('--force');
  const batchSizeArg = args.find((a) => a.startsWith('--batch-size='));
  const batchSize = batchSizeArg ? parseInt(batchSizeArg.split('=')[1], 10) : 100;

  console.log('====================================================');
  console.log(' Quiet Paper — Firebase Auth Email Backfill Script');
  console.log('====================================================');
  console.log(` Mode: ${dryRun ? 'DRY RUN (No database writes)' : 'LIVE EXECUTION'}`);
  console.log(` Force Refresh: ${force ? 'YES (All users)' : 'NO (Only users with empty emails)'}`);
  console.log(` Batch Size: ${batchSize}`);
  console.log('----------------------------------------------------');

  const db = getDbClient();

  try {
    // Ensure migrations are up to date
    console.log('[1/2] Verifying database schema...');
    await runMigrations(db);

    console.log('[2/2] Running email synchronization...');
    const result = await backfillMissingUserEmails(db, {
      dryRun,
      force,
      batchSize,
      onProgress: (msg) => console.log(`  > ${msg}`),
    });

    console.log('----------------------------------------------------');
    console.log(' Summary Results:');
    console.log(`  Total Users Checked: ${result.totalChecked}`);
    console.log(`  ${dryRun ? 'Would Update' : 'Updated'}: ${result.updated}`);
    console.log(`  Skipped / Up-to-Date: ${result.skipped}`);
    console.log(`  Errors: ${result.errors.length}`);
    if (result.errors.length > 0) {
      console.log(' Error Details:');
      result.errors.forEach((err) => console.error(`    - ${err}`));
    }
    console.log('====================================================');

    process.exit(result.errors.length > 0 ? 1 : 0);
  } catch (err: any) {
    console.error('[FATAL ERROR] Backfill script failed:', err.message || err);
    process.exit(1);
  }
}

main();
