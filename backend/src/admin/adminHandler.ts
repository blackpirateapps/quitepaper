import { Client } from '@libsql/client';
import { RequestLike, ResponseLike } from '../api/handler.js';
import {
  getAdminPassword,
  verifyAdminPassword,
  createAdminSession,
  isAuthenticatedAdmin,
  getSetSessionCookieHeader,
  getClearSessionCookieHeader,
} from './adminAuth.js';
import {
  getAdminOverview,
  getAdminUsers,
  getAdminUserDetail,
  triggerUserGC,
  getAdminStorageDetails,
  retryDestructionJob,
  deleteDestructionJob,
} from './adminService.js';
import {
  renderLoginPage,
  renderDashboardPage,
  renderUsersPage,
  renderUserDetailPage,
  renderStoragePage,
  formatBytes,
} from './adminViews.js';

export async function handleAdminRequest(req: RequestLike, db: Client): Promise<ResponseLike> {
  const method = (req.method || 'GET').toUpperCase();
  const rawUrl = req.url || '/admin';
  const urlObj = new URL(rawUrl, 'http://localhost');
  const pathname = urlObj.pathname;
  const flash = urlObj.searchParams.get('flash') || undefined;

  const adminPassword = getAdminPassword();

  // 1. If ADMIN_PASSWORD is not configured in Vercel / environment
  if (!adminPassword) {
    if (pathname.startsWith('/api/admin')) {
      return {
        statusCode: 503,
        headers: { 'Content-Type': 'application/json' },
        body: { error: { code: 'ADMIN_DISABLED', message: 'ADMIN_PASSWORD environment variable is not configured.' } },
      };
    }
    return {
      statusCode: 503,
      headers: { 'Content-Type': 'text/html; charset=utf-8' },
      body: renderLoginPage(undefined, false),
    };
  }

  // 2. Login route (GET /admin/login)
  if (pathname === '/admin/login' && method === 'GET') {
    if (isAuthenticatedAdmin(req.headers)) {
      return {
        statusCode: 302,
        headers: { Location: '/admin' },
        body: '',
      };
    }
    return {
      statusCode: 200,
      headers: { 'Content-Type': 'text/html; charset=utf-8' },
      body: renderLoginPage(),
    };
  }

  // 3. Login submit (POST /admin/login)
  if (pathname === '/admin/login' && method === 'POST') {
    const password = req.body?.password;
    if (verifyAdminPassword(password)) {
      const sessionToken = createAdminSession();
      return {
        statusCode: 302,
        headers: {
          Location: '/admin',
          'Set-Cookie': getSetSessionCookieHeader(sessionToken),
        },
        body: '',
      };
    }
    return {
      statusCode: 401,
      headers: { 'Content-Type': 'text/html; charset=utf-8' },
      body: renderLoginPage('Invalid administrator password.'),
    };
  }

  // 4. Logout route (POST /admin/logout or GET /admin/logout)
  if (pathname === '/admin/logout') {
    return {
      statusCode: 302,
      headers: {
        Location: '/admin/login',
        'Set-Cookie': getClearSessionCookieHeader(),
      },
      body: '',
    };
  }

  // 5. Require Authentication for all remaining admin routes
  if (!isAuthenticatedAdmin(req.headers)) {
    if (pathname.startsWith('/api/admin')) {
      return {
        statusCode: 401,
        headers: { 'Content-Type': 'application/json' },
        body: { error: { code: 'UNAUTHORIZED', message: 'Admin authentication required.' } },
      };
    }
    return {
      statusCode: 302,
      headers: { Location: `/admin/login` },
      body: '',
    };
  }

  // 6. JSON API endpoint: GET /api/admin/stats
  if (pathname === '/api/admin/stats' && method === 'GET') {
    const overview = await getAdminOverview(db);
    return {
      statusCode: 200,
      headers: { 'Content-Type': 'application/json' },
      body: overview,
    };
  }

  // 7. Overview Dashboard: GET /admin or GET /admin/overview
  if ((pathname === '/admin' || pathname === '/admin/' || pathname === '/admin/overview') && method === 'GET') {
    const overview = await getAdminOverview(db);
    return {
      statusCode: 200,
      headers: { 'Content-Type': 'text/html; charset=utf-8' },
      body: renderDashboardPage(overview, flash),
    };
  }

  // 8. Users List: GET /admin/users
  if (pathname === '/admin/users' && method === 'GET') {
    const page = parseInt(urlObj.searchParams.get('page') || '1', 10);
    const q = urlObj.searchParams.get('q') || undefined;
    const usersResult = await getAdminUsers(db, { search: q, page, limit: 20 });
    return {
      statusCode: 200,
      headers: { 'Content-Type': 'text/html; charset=utf-8' },
      body: renderUsersPage(usersResult, q, flash),
    };
  }

  // 9. User Detail: GET /admin/users/:id
  const userDetailMatch = pathname.match(/^\/admin\/users\/([0-9a-fA-F-]{36})$/);
  if (userDetailMatch && method === 'GET') {
    const userId = userDetailMatch[1];
    const detail = await getAdminUserDetail(db, userId);
    if (!detail) {
      return {
        statusCode: 404,
        headers: { 'Content-Type': 'text/html; charset=utf-8' },
        body: `<h1>User not found</h1><p><a href="/admin/users">Back to Users</a></p>`,
      };
    }
    return {
      statusCode: 200,
      headers: { 'Content-Type': 'text/html; charset=utf-8' },
      body: renderUserDetailPage(detail, flash),
    };
  }

  // 10. Trigger User GC: POST /admin/users/:id/gc
  const userGcMatch = pathname.match(/^\/admin\/users\/([0-9a-fA-F-]{36})\/gc$/);
  if (userGcMatch && method === 'POST') {
    const userId = userGcMatch[1];
    const dryRun = req.body?.dryRun === 'true' || req.body?.dryRun === true;
    const gcResult = await triggerUserGC(db, userId, dryRun);
    const prefix = dryRun ? '[Dry Run Simulation]' : '[GC Complete]';
    const flashMsg = `${prefix} Reclaimable: ${formatBytes(gcResult.estimatedBytesReclaimed)}, Pruned Changes: ${gcResult.syncChangesDeleted}, Orphan Attachments: ${gcResult.orphanedAttachmentsIdentified}.`;

    return {
      statusCode: 302,
      headers: { Location: `/admin/users/${userId}?flash=${encodeURIComponent(flashMsg)}` },
      body: '',
    };
  }

  // 11. Storage & Jobs: GET /admin/storage
  if (pathname === '/admin/storage' && method === 'GET') {
    const storageDetails = await getAdminStorageDetails(db);
    return {
      statusCode: 200,
      headers: { 'Content-Type': 'text/html; charset=utf-8' },
      body: renderStoragePage(storageDetails, flash),
    };
  }

  // 12. Retry Destruction Job: POST /admin/jobs/:id/retry
  const retryJobMatch = pathname.match(/^\/admin\/jobs\/([0-9a-fA-F-]{36})\/retry$/);
  if (retryJobMatch && method === 'POST') {
    const jobId = retryJobMatch[1];
    await retryDestructionJob(db, jobId);
    return {
      statusCode: 302,
      headers: { Location: '/admin/storage?flash=Destruction+job+reset+to+pending+for+re-execution.' },
      body: '',
    };
  }

  // 13. Delete Destruction Job: POST /admin/jobs/:id/delete
  const deleteJobMatch = pathname.match(/^\/admin\/jobs\/([0-9a-fA-F-]{36})\/delete$/);
  if (deleteJobMatch && method === 'POST') {
    const jobId = deleteJobMatch[1];
    await deleteDestructionJob(db, jobId);
    return {
      statusCode: 302,
      headers: { Location: '/admin/storage?flash=Destruction+job+record+deleted.' },
      body: '',
    };
  }

  // Admin 404
  return {
    statusCode: 404,
    headers: { 'Content-Type': 'text/html; charset=utf-8' },
    body: `<h1>Admin Page Not Found</h1><p><a href="/admin">Return to Overview</a></p>`,
  };
}
