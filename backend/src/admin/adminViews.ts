import {
  AdminOverview,
  AdminUsersResult,
  AdminUserDetail,
  AdminStorageOverview,
} from './adminService.js';

export function escapeHtml(str: string | number | null | undefined): string {
  if (str === null || str === undefined) return '';
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

export function formatBytes(bytes: number): string {
  if (!bytes || bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  const k = 1000; // Decimal standard matching 1 GB = 1,000,000,000 bytes
  const i = Math.min(units.length - 1, Math.floor(Math.log(bytes) / Math.log(k)));
  const val = bytes / Math.pow(k, i);
  return `${val < 10 && i > 0 ? val.toFixed(2) : val.toFixed(1)} ${units[i]}`;
}

export function formatDate(isoStr: string | null | undefined): string {
  if (!isoStr) return 'Never';
  try {
    const d = new Date(isoStr);
    return d.toLocaleString('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  } catch {
    return isoStr;
  }
}

/**
 * Common HTML layout with warm editorial dark theme matching Quiet Paper.
 */
export function renderLayout({
  title,
  activeTab,
  content,
  dbPingMs,
  flash,
  isAuthed = true,
}: {
  title: string;
  activeTab?: 'overview' | 'users' | 'storage' | 'login';
  content: string;
  dbPingMs?: number;
  flash?: string;
  isAuthed?: boolean;
}): string {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${escapeHtml(title)} — Quiet Paper Admin</title>
  <style>
    :root {
      --bg: #161513;
      --card-bg: #211F1C;
      --card-hover: #292723;
      --card-subtle: #1C1A17;
      --border: #33302B;
      --border-subtle: #282622;
      --accent: #D05A3F;
      --accent-hover: #B84D35;
      --accent-subtle: rgba(208, 90, 63, 0.15);
      --amber: #D97706;
      --amber-subtle: rgba(217, 119, 6, 0.15);
      --green: #10B981;
      --green-subtle: rgba(16, 185, 129, 0.15);
      --red: #EF4444;
      --red-subtle: rgba(239, 68, 68, 0.15);
      --text-main: #F4F2ED;
      --text-muted: #A39E93;
      --text-dim: #716C62;
      --font-sans: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      --font-mono: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", monospace;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      background-color: var(--bg);
      color: var(--text-main);
      font-family: var(--font-sans);
      font-size: 14px;
      line-height: 1.5;
      min-height: 100vh;
      display: flex;
      flex-direction: column;
    }
    a { color: var(--accent); text-decoration: none; }
    a:hover { text-decoration: underline; }
    
    header {
      background: var(--card-bg);
      border-bottom: 1px solid var(--border);
      padding: 0 24px;
      position: sticky;
      top: 0;
      z-index: 100;
    }
    .header-inner {
      max-width: 1200px;
      margin: 0 auto;
      height: 60px;
      display: flex;
      align-items: center;
      justify-content: space-between;
    }
    .brand {
      display: flex;
      align-items: center;
      gap: 12px;
      font-weight: 600;
      font-size: 16px;
      letter-spacing: -0.2px;
      color: var(--text-main);
    }
    .brand-icon {
      width: 28px;
      height: 28px;
      background: var(--accent);
      border-radius: 6px;
      display: flex;
      align-items: center;
      justify-content: center;
      color: #FFF;
      font-size: 15px;
    }
    .badge-admin {
      background: var(--accent-subtle);
      color: var(--accent);
      border: 1px solid rgba(208, 90, 63, 0.3);
      padding: 2px 7px;
      border-radius: 4px;
      font-size: 11px;
      font-weight: 600;
      letter-spacing: 0.5px;
      text-transform: uppercase;
    }
    nav {
      display: flex;
      gap: 4px;
      align-items: center;
    }
    .nav-link {
      padding: 7px 14px;
      border-radius: 6px;
      color: var(--text-muted);
      font-weight: 500;
      transition: all 0.15s;
    }
    .nav-link:hover {
      color: var(--text-main);
      background: var(--card-hover);
      text-decoration: none;
    }
    .nav-link.active {
      color: var(--text-main);
      background: var(--border);
    }
    .header-actions {
      display: flex;
      align-items: center;
      gap: 14px;
    }
    .db-badge {
      display: flex;
      align-items: center;
      gap: 6px;
      background: var(--card-subtle);
      border: 1px solid var(--border-subtle);
      padding: 4px 9px;
      border-radius: 14px;
      font-size: 12px;
      color: var(--text-muted);
      font-family: var(--font-mono);
    }
    .status-dot {
      width: 7px;
      height: 7px;
      border-radius: 50%;
      background: var(--green);
    }
    
    main {
      flex: 1;
      max-width: 1200px;
      width: 100%;
      margin: 0 auto;
      padding: 28px 24px 64px 24px;
    }

    .flash-banner {
      background: var(--green-subtle);
      border: 1px solid rgba(16, 185, 129, 0.3);
      color: #A7F3D0;
      padding: 12px 18px;
      border-radius: 8px;
      margin-bottom: 24px;
      display: flex;
      align-items: center;
      justify-content: space-between;
    }
    .flash-banner.error {
      background: var(--red-subtle);
      border-color: rgba(239, 68, 68, 0.3);
      color: #FECACA;
    }

    .card {
      background: var(--card-bg);
      border: 1px solid var(--border);
      border-radius: 10px;
      padding: 20px;
      margin-bottom: 24px;
    }
    .card-header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      margin-bottom: 16px;
    }
    .card-title {
      font-size: 16px;
      font-weight: 600;
      letter-spacing: -0.2px;
      color: var(--text-main);
    }

    .grid-2 { display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 16px; }
    .grid-3 { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 16px; }
    .grid-4 { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 16px; }

    .stat-card {
      background: var(--card-bg);
      border: 1px solid var(--border);
      border-radius: 8px;
      padding: 16px;
    }
    .stat-label {
      color: var(--text-muted);
      font-size: 12px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      font-weight: 600;
      margin-bottom: 6px;
    }
    .stat-value {
      font-size: 26px;
      font-weight: 700;
      color: var(--text-main);
      font-family: var(--font-sans);
      letter-spacing: -0.5px;
    }
    .stat-meta {
      margin-top: 6px;
      font-size: 12px;
      color: var(--text-dim);
    }

    .badge {
      display: inline-flex;
      align-items: center;
      padding: 2px 8px;
      border-radius: 4px;
      font-size: 11px;
      font-weight: 600;
      font-family: var(--font-mono);
      text-transform: uppercase;
    }
    .badge-green { background: var(--green-subtle); color: #34D399; border: 1px solid rgba(16, 185, 129, 0.2); }
    .badge-amber { background: var(--amber-subtle); color: #FBBF24; border: 1px solid rgba(217, 119, 6, 0.2); }
    .badge-red { background: var(--red-subtle); color: #F87171; border: 1px solid rgba(239, 68, 68, 0.2); }
    .badge-gray { background: var(--card-subtle); color: var(--text-muted); border: 1px solid var(--border-subtle); }
    .badge-accent { background: var(--accent-subtle); color: var(--accent); border: 1px solid rgba(208, 90, 63, 0.3); }

    table {
      width: 100%;
      border-collapse: collapse;
      text-align: left;
    }
    th {
      padding: 12px 14px;
      font-size: 11.5px;
      text-transform: uppercase;
      letter-spacing: 0.6px;
      color: var(--text-dim);
      border-bottom: 1px solid var(--border);
      font-weight: 600;
    }
    td {
      padding: 14px;
      border-bottom: 1px solid var(--border-subtle);
      color: var(--text-main);
      vertical-align: middle;
    }
    tr:last-child td { border-bottom: none; }
    tbody tr:hover { background: var(--card-hover); }

    .btn {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      padding: 8px 14px;
      border-radius: 6px;
      font-size: 13px;
      font-weight: 500;
      border: 1px solid transparent;
      cursor: pointer;
      transition: all 0.15s;
      font-family: var(--font-sans);
    }
    .btn-primary {
      background: var(--accent);
      color: #FFF;
    }
    .btn-primary:hover {
      background: var(--accent-hover);
    }
    .btn-secondary {
      background: var(--card-subtle);
      border-color: var(--border);
      color: var(--text-main);
    }
    .btn-secondary:hover {
      background: var(--card-hover);
    }
    .btn-sm {
      padding: 4px 10px;
      font-size: 12px;
    }
    .btn-danger {
      background: var(--red-subtle);
      color: #F87171;
      border-color: rgba(239, 68, 68, 0.3);
    }
    .btn-danger:hover {
      background: rgba(239, 68, 68, 0.25);
    }

    input[type="text"], input[type="password"], select {
      background: var(--card-subtle);
      border: 1px solid var(--border);
      color: var(--text-main);
      padding: 8px 12px;
      border-radius: 6px;
      font-size: 13px;
      font-family: var(--font-sans);
      outline: none;
    }
    input[type="text"]:focus, input[type="password"]:focus {
      border-color: var(--accent);
    }

    .zk-banner {
      background: linear-gradient(135deg, #24211D 0%, #1E1C19 100%);
      border: 1px solid #443F36;
      border-left: 4px solid var(--amber);
      padding: 16px 20px;
      border-radius: 8px;
      margin-bottom: 24px;
      display: flex;
      align-items: flex-start;
      gap: 14px;
    }
    .zk-banner p { color: var(--text-muted); font-size: 13px; line-height: 1.5; }
    .zk-banner strong { color: #FCD34D; }

    .code-mono {
      font-family: var(--font-mono);
      font-size: 12px;
      background: var(--card-subtle);
      padding: 2px 6px;
      border-radius: 4px;
      border: 1px solid var(--border-subtle);
      color: var(--text-main);
    }

    .progress-bar-bg {
      background: var(--card-subtle);
      border: 1px solid var(--border-subtle);
      border-radius: 6px;
      height: 10px;
      width: 100%;
      overflow: hidden;
      margin: 8px 0;
    }
    .progress-bar-fill {
      height: 100%;
      border-radius: 6px;
      transition: width 0.3s ease;
    }

    .pagination {
      display: flex;
      align-items: center;
      justify-content: space-between;
      margin-top: 16px;
      color: var(--text-muted);
      font-size: 13px;
    }
  </style>
</head>
<body>
  ${
    isAuthed
      ? `
  <header>
    <div class="header-inner">
      <div class="brand">
        <div class="brand-icon">Q</div>
        <span>Quiet Paper</span>
        <span class="badge-admin">Admin</span>
      </div>
      <nav>
        <a href="/admin" class="nav-link ${activeTab === 'overview' ? 'active' : ''}">Overview</a>
        <a href="/admin/users" class="nav-link ${activeTab === 'users' ? 'active' : ''}">Users</a>
        <a href="/admin/storage" class="nav-link ${activeTab === 'storage' ? 'active' : ''}">Storage & GC</a>
      </nav>
      <div class="header-actions">
        ${
          dbPingMs !== undefined
            ? `
          <div class="db-badge" title="Turso libSQL Round-Trip Latency">
            <span class="status-dot"></span>
            <span>DB ${dbPingMs}ms</span>
          </div>`
            : ''
        }
        <form action="/admin/logout" method="POST" style="margin:0;">
          <button type="submit" class="btn btn-secondary btn-sm">Sign Out</button>
        </form>
      </div>
    </div>
  </header>`
      : ''
  }

  <main>
    ${flash ? `<div class="flash-banner">${escapeHtml(flash)}</div>` : ''}
    ${content}
  </main>
</body>
</html>`;
}

/**
 * Render Login Form view.
 */
export function renderLoginPage(error?: string, isConfigured: boolean = true): string {
  const content = `
    <div style="max-width: 420px; margin: 80px auto; width: 100%;">
      <div style="text-align: center; margin-bottom: 28px;">
        <div style="width: 44px; height: 44px; background: var(--accent); border-radius: 10px; display: inline-flex; align-items: center; justify-content: center; font-size: 24px; font-weight: bold; color: white; margin-bottom: 12px;">Q</div>
        <h1 style="font-size: 22px; font-weight: 700; letter-spacing: -0.4px;">Quiet Paper Admin</h1>
        <p style="color: var(--text-muted); font-size: 13px; margin-top: 4px;">Zero-knowledge cloud sync & infrastructure control</p>
      </div>

      ${
        !isConfigured
          ? `
        <div class="card" style="border-color: var(--amber); background: var(--amber-subtle);">
          <h3 style="color: #FBBF24; font-size: 15px; margin-bottom: 8px;">Admin Panel Not Configured</h3>
          <p style="color: var(--text-main); font-size: 13px; line-height: 1.5;">
            To enable this administration panel, set the <code>ADMIN_PASSWORD</code> environment variable in your Vercel project settings or <code>.env</code> file.
          </p>
        </div>`
          : `
        <div class="card">
          ${error ? `<div class="flash-banner error" style="margin-bottom: 16px; padding: 10px 14px;">${escapeHtml(error)}</div>` : ''}
          <form action="/admin/login" method="POST">
            <div style="margin-bottom: 18px;">
              <label style="display: block; font-size: 12px; font-weight: 600; text-transform: uppercase; color: var(--text-muted); margin-bottom: 6px;">Admin Password</label>
              <input type="password" name="password" required autofocus style="width: 100%; box-sizing: border-box; padding: 10px 12px;" placeholder="Enter ADMIN_PASSWORD">
            </div>
            <button type="submit" class="btn btn-primary" style="width: 100%; padding: 10px;">Sign In to Dashboard</button>
          </form>
          <div style="margin-top: 16px; text-align: center; font-size: 11px; color: var(--text-dim);">
            Protected by timing-safe constant-time verification & HMAC-SHA256 session cookies.
          </div>
        </div>`
      }
    </div>
  `;

  return renderLayout({
    title: 'Login',
    activeTab: 'login',
    content,
    isAuthed: false,
  });
}

/**
 * Render Overview Dashboard view.
 */
export function renderDashboardPage(overview: AdminOverview, flash?: string): string {
  const content = `
    <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 24px;">
      <div>
        <h1 style="font-size: 24px; font-weight: 700; letter-spacing: -0.5px;">Platform Overview</h1>
        <p style="color: var(--text-muted); font-size: 13px;">Live statistics from Turso libSQL database</p>
      </div>
      <div>
        <a href="/admin/storage" class="btn btn-secondary btn-sm">Manage Storage & GC →</a>
      </div>
    </div>

    <div class="zk-banner">
      <div style="font-size: 22px;">🔒</div>
      <div>
        <strong>Zero-Knowledge Architecture Strictly Preserved</strong>
        <p>
          All note titles, note bodies, and hashtags are encrypted client-side using Argon2id and XChaCha20-Poly1305.
          The database and admin console store only crypto-blind ciphertexts, nonces, and metadata.
        </p>
      </div>
    </div>

    <!-- Core Metrics Grid -->
    <div class="grid-4" style="margin-bottom: 24px;">
      <div class="stat-card">
        <div class="stat-label">Total Users</div>
        <div class="stat-value">${overview.users.total}</div>
        <div class="stat-meta">${overview.users.free} Free · <strong style="color: var(--accent);">${overview.users.premium} Premium</strong></div>
      </div>
      <div class="stat-card">
        <div class="stat-label">Total Cloud Storage</div>
        <div class="stat-value">${formatBytes(overview.storageQuota.totalCloudStorageUsed)}</div>
        <div class="stat-meta">${formatBytes(overview.storageQuota.freeStorageUsed)} Free · ${formatBytes(overview.storageQuota.premiumStorageUsed)} Premium</div>
      </div>
      <div class="stat-card">
        <div class="stat-label">Active Notes</div>
        <div class="stat-value">${overview.notes.active}</div>
        <div class="stat-meta">${overview.notes.total} total notes (${overview.notes.archived} archived, ${overview.notes.trashed} trash)</div>
      </div>
      <div class="stat-card">
        <div class="stat-label">Cloudinary Files</div>
        <div class="stat-value">${overview.attachments.total + overview.documents.total}</div>
        <div class="stat-meta">${overview.attachments.total} media attachments · ${overview.documents.total} PDFs</div>
      </div>
    </div>

    <!-- Second Row (Quota Health, Sync Activity & Jobs) -->
    <div class="grid-3" style="margin-bottom: 24px;">
      <div class="stat-card">
        <div class="stat-label">Quota Exceptions</div>
        <div class="stat-value" style="color: ${overview.storageQuota.usersOverQuota > 0 ? 'var(--red)' : 'var(--text-main)'};">
          ${overview.storageQuota.usersOverQuota}
        </div>
        <div class="stat-meta">
          <span style="color: ${overview.storageQuota.usersOverQuota > 0 ? 'var(--red)' : 'inherit'}; font-weight: 600;">
            ${overview.storageQuota.usersOverQuota} over quota
          </span> · ${overview.storageQuota.usersNearQuota} near quota (&ge;80%)
        </div>
      </div>
      <div class="stat-card">
        <div class="stat-label">Sync Volume (24h)</div>
        <div class="stat-value">${overview.syncActivity.changesLast24Hours}</div>
        <div class="stat-meta">${overview.syncActivity.changesLast7Days} changes past 7 days</div>
      </div>
      <div class="stat-card">
        <div class="stat-label">Connected Devices</div>
        <div class="stat-value">${overview.devices.total}</div>
        <div class="stat-meta">${overview.devices.activeLast30Days} active within 30 days</div>
      </div>
    </div>

    <!-- Detailed Breakdowns -->
    <div class="grid-2">
      <div class="card">
        <div class="card-header">
          <div class="card-title">Database Storage &amp; Infrastructure</div>
        </div>
        <table style="margin-top: -8px;">
          <tbody>
            <tr>
              <td>Notes Encrypted Ciphertext</td>
              <td style="text-align: right; font-family: var(--font-mono);">${formatBytes(overview.notes.totalEncryptedBytes)}</td>
            </tr>
            <tr>
              <td>Cloudinary Media Storage</td>
              <td style="text-align: right; font-family: var(--font-mono);">${formatBytes(overview.attachments.totalBytes)}</td>
            </tr>
            <tr>
              <td>PDF Document Storage</td>
              <td style="text-align: right; font-family: var(--font-mono);">${formatBytes(overview.documents.totalBytes)}</td>
            </tr>
            <tr>
              <td>Global Tags Count</td>
              <td style="text-align: right; font-family: var(--font-mono);">${overview.tags.total}</td>
            </tr>
            <tr>
              <td>Turso LibSQL Ping Latency</td>
              <td style="text-align: right; font-family: var(--font-mono); color: var(--green);">${overview.dbPingMs} ms</td>
            </tr>
          </tbody>
        </table>
      </div>

      <div class="card">
        <div class="card-header">
          <div class="card-title">Quick Actions & Shortcuts</div>
        </div>
        <div style="display: flex; flex-direction: column; gap: 10px;">
          <a href="/admin/users" class="btn btn-secondary" style="justify-content: flex-start; padding: 12px 16px;">
            👥 &nbsp;<strong>Browse &amp; Inspect Users</strong> &nbsp;<span style="color: var(--text-dim); margin-left: auto;">${overview.users.total} accounts (${overview.users.premium} premium)</span>
          </a>
          <a href="/admin/storage" class="btn btn-secondary" style="justify-content: flex-start; padding: 12px 16px;">
            🗑️ &nbsp;<strong>Inspect Cloudinary Storage &amp; GC</strong> &nbsp;<span style="color: var(--text-dim); margin-left: auto;">${formatBytes(overview.storageQuota.totalCloudStorageUsed)}</span>
          </a>
          <a href="/api/v1/health" target="_blank" class="btn btn-secondary" style="justify-content: flex-start; padding: 12px 16px;">
            💓 &nbsp;<strong>API Healthcheck Endpoint</strong> &nbsp;<span style="color: var(--text-dim); margin-left: auto;">/api/v1/health ↗</span>
          </a>
        </div>
      </div>
    </div>
  `;

  return renderLayout({
    title: 'Overview',
    activeTab: 'overview',
    content,
    dbPingMs: overview.dbPingMs,
    flash,
  });
}

/**
 * Render Users list page with Email, Plan, Storage Used / Limit, Notes, and Devices.
 */
export function renderUsersPage(result: AdminUsersResult, search?: string, flash?: string): string {
  const content = `
    <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 20px; flex-wrap: wrap; gap: 12px;">
      <div>
        <h1 style="font-size: 24px; font-weight: 700; letter-spacing: -0.5px;">User Accounts</h1>
        <p style="color: var(--text-muted); font-size: 13px;">${result.total} total registered users</p>
      </div>
      <div style="display: flex; align-items: center; gap: 12px; flex-wrap: wrap;">
        <form action="/admin/users/sync-emails" method="POST" style="margin: 0;" onsubmit="return confirm('Sync missing user emails from Firebase Auth across all registered accounts?');">
          <button type="submit" class="btn btn-secondary btn-sm" title="Populate missing user emails from Firebase Auth">🔄 Sync Missing Emails</button>
        </form>
        <form action="/admin/users" method="GET" style="display: flex; gap: 8px; margin: 0;">
          <input type="text" name="q" value="${escapeHtml(search || '')}" placeholder="Search Email, UID, or ID..." style="width: 260px;">
          <button type="submit" class="btn btn-secondary btn-sm">Search</button>
          ${search ? `<a href="/admin/users" class="btn btn-secondary btn-sm" style="line-height:20px;">Clear</a>` : ''}
        </form>
      </div>
    </div>

    <div class="card" style="padding: 0; overflow: hidden;">
      <table>
        <thead>
          <tr>
            <th>Email</th>
            <th>Plan</th>
            <th>Storage Used / Quota</th>
            <th>Notes</th>
            <th>Devices</th>
            <th>Registered</th>
            <th style="text-align: right;">Action</th>
          </tr>
        </thead>
        <tbody>
          ${
            result.users.length === 0
              ? `<tr><td colspan="7" style="text-align: center; color: var(--text-muted); padding: 32px;">No users found matching your search.</td></tr>`
              : result.users
                  .map((u) => {
                    let planBadge = 'badge-gray';
                    let planLabel = 'Free';
                    if (u.plan === 'premium') {
                      planBadge = 'badge-accent';
                      planLabel = 'Premium';
                    }
                    if (u.isOverQuota) {
                      planBadge = 'badge-red';
                      planLabel = `${planLabel} (Over Quota)`;
                    }

                    return `
              <tr>
                <td>
                  <strong>${escapeHtml(u.email || '—')}</strong>
                  <div style="font-size: 11px; color: var(--text-dim); margin-top: 2px;">
                    <span class="code-mono" title="${escapeHtml(u.id)}">${escapeHtml(u.id.substring(0, 8))}...</span>
                  </div>
                </td>
                <td><span class="badge ${planBadge}">${planLabel}</span></td>
                <td>
                  <span style="font-family: var(--font-mono); font-size: 12.5px; ${u.isOverQuota ? 'color: var(--red); font-weight: bold;' : ''}">
                    ${formatBytes(u.storageUsedBytes)} / ${formatBytes(u.storageLimitBytes)}
                  </span>
                </td>
                <td><span class="badge badge-gray">${u.notesCount} notes</span></td>
                <td><span class="badge badge-gray">${u.devicesCount} devices</span></td>
                <td style="font-size: 12px; color: var(--text-muted);">${formatDate(u.createdAt)}</td>
                <td style="text-align: right;">
                  <a href="/admin/users/${encodeURIComponent(u.id)}" class="btn btn-secondary btn-sm">Inspect →</a>
                </td>
              </tr>
            `;
                  })
                  .join('')
          }
        </tbody>
      </table>
    </div>

    <!-- Pagination -->
    <div class="pagination">
      <div>Showing Page ${result.page} of ${result.totalPages}</div>
      <div style="display: flex; gap: 8px;">
        ${
          result.page > 1
            ? `<a href="/admin/users?page=${result.page - 1}${search ? `&q=${encodeURIComponent(search)}` : ''}" class="btn btn-secondary btn-sm">← Previous</a>`
            : ''
        }
        ${
          result.page < result.totalPages
            ? `<a href="/admin/users?page=${result.page + 1}${search ? `&q=${encodeURIComponent(search)}` : ''}" class="btn btn-secondary btn-sm">Next →</a>`
            : ''
        }
      </div>
    </div>
  `;

  return renderLayout({
    title: 'Users',
    activeTab: 'users',
    content,
    flash,
  });
}

/**
 * Render User Detail page with Storage Quota control, Plan management, and Audit history.
 */
export function renderUserDetailPage(detail: AdminUserDetail, flash?: string): string {
  const percentUsed = Math.min(100, (detail.quota.usedBytes / detail.quota.limitBytes) * 100);
  let progressColor = 'var(--green)';
  if (percentUsed >= 80) progressColor = 'var(--amber)';
  if (detail.quota.isOverQuota) progressColor = 'var(--red)';

  const content = `
    <div style="margin-bottom: 16px;">
      <a href="/admin/users" style="color: var(--text-muted); font-size: 13px;">← Back to Users list</a>
    </div>

    <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 24px;">
      <div>
        <h1 style="font-size: 24px; font-weight: 700; letter-spacing: -0.5px;">User Audit &amp; Control</h1>
        <p style="color: var(--text-muted); font-size: 13px;">
          ${escapeHtml(detail.user.email || 'No email')} · Internal ID: <span class="code-mono">${escapeHtml(detail.user.id)}</span>
        </p>
      </div>
      <div>
        ${
          detail.quota.plan === 'premium'
            ? '<span class="badge badge-accent" style="font-size: 13px; padding: 4px 10px;">★ Premium User</span>'
            : '<span class="badge badge-gray" style="font-size: 13px; padding: 4px 10px;">Free User</span>'
        }
      </div>
    </div>

    <div class="card" style="border-left: 4px solid var(--accent); margin-bottom: 24px; background: var(--card-subtle);">
      <div style="font-size: 13px; color: var(--text-main); line-height: 1.5;">
        🔒 <strong>End-to-End Encryption Guarantee</strong>: User payloads, notes, attachments, and encryption keys are strictly zero-knowledge encrypted client-side. The server and administrative dashboard store and handle only ciphertext blobs, authentication records, and storage metadata.
      </div>
    </div>

    ${
      detail.quota.isOverQuota
        ? `
      <div class="card" style="border-color: var(--red); background: var(--red-subtle); margin-bottom: 24px;">
        <h3 style="color: #F87171; font-size: 15px; margin-bottom: 4px;">Account is Over Storage Quota</h3>
        <p style="color: var(--text-main); font-size: 13px; line-height: 1.5;">
          This user currently consumes <strong>${formatBytes(detail.quota.usedBytes)}</strong> which exceeds their ${detail.quota.plan} allowance of <strong>${formatBytes(detail.quota.limitBytes)}</strong> by <strong>${formatBytes(detail.quota.overQuotaBytes)}</strong>.
          Existing data is safely preserved. New uploads are blocked until usage is reduced or account is upgraded.
        </p>
      </div>`
        : ''
    }

    <div class="grid-2">
      <!-- Identity & Security -->
      <div class="card">
        <div class="card-header">
          <div class="card-title">Identity &amp; Encryption Setup</div>
        </div>
        <table>
          <tbody>
            <tr>
              <td>Email Address</td>
              <td>
                <div style="display: flex; align-items: center; justify-content: space-between; gap: 8px;">
                  <strong>${escapeHtml(detail.user.email || '—')}</strong>
                  <form action="/admin/users/${encodeURIComponent(detail.user.id)}/sync-email" method="POST" style="margin: 0;">
                    <button type="submit" class="btn btn-secondary btn-sm" style="font-size: 11px; padding: 2px 8px;" title="Refresh email from Firebase Auth">🔄 Sync</button>
                  </form>
                </div>
              </td>
            </tr>
            <tr>
              <td>Firebase UID</td>
              <td style="font-family: var(--font-mono); font-size: 12px;">${escapeHtml(detail.user.firebaseUid)}</td>
            </tr>
            <tr>
              <td>Account Created</td>
              <td>${formatDate(detail.user.createdAt)}</td>
            </tr>
            <tr>
              <td>Last Active / Updated</td>
              <td>${formatDate(detail.user.updatedAt)}</td>
            </tr>
            <tr>
              <td>Encryption Key Status</td>
              <td>
                ${
                  detail.encryptionKey.configured
                    ? `<span class="badge badge-green">Configured (v${detail.encryptionKey.keyVersion})</span>`
                    : `<span class="badge badge-amber">Not Configured</span>`
                }
              </td>
            </tr>
            ${
              detail.encryptionKey.configured
                ? `
            <tr>
              <td>KDF Algorithm</td>
              <td><span class="code-mono">${escapeHtml(detail.encryptionKey.kdfAlgorithm || 'argon2id')}</span></td>
            </tr>
            <tr>
              <td>Recovery Key Saved?</td>
              <td>${detail.encryptionKey.hasRecoveryKey ? '<span class="badge badge-green">Yes</span>' : '<span class="badge badge-gray">No</span>'}</td>
            </tr>`
                : ''
            }
          </tbody>
        </table>
      </div>

      <!-- Plan Management & Storage Quota Control -->
      <div class="card">
        <div class="card-header">
          <div class="card-title">Plan &amp; Storage Quota Control</div>
          <span class="badge ${detail.quota.plan === 'premium' ? 'badge-accent' : 'badge-gray'}">${escapeHtml(detail.quota.plan.toUpperCase())}</span>
        </div>

        <div style="margin-bottom: 16px;">
          <div style="display: flex; justify-content: space-between; font-size: 12px; margin-bottom: 4px;">
            <span style="color: var(--text-muted); font-weight: 600;">Cloud Storage Consumption</span>
            <span style="font-family: var(--font-mono); font-weight: 600;">
              ${formatBytes(detail.quota.usedBytes)} / ${formatBytes(detail.quota.limitBytes)} (${percentUsed.toFixed(1)}%)
            </span>
          </div>
          <div class="progress-bar-bg">
            <div class="progress-bar-fill" style="width: ${percentUsed}%; background: ${progressColor};"></div>
          </div>
          <div style="display: flex; justify-content: space-between; font-size: 11px; color: var(--text-dim); margin-top: 4px;">
            <span>Remaining: ${formatBytes(detail.quota.remainingBytes)}</span>
            <span>Reserved in-flight: ${formatBytes(detail.quota.reservedBytes)}</span>
          </div>
        </div>

        <div style="background: var(--card-subtle); border: 1px solid var(--border-subtle); border-radius: 8px; padding: 14px; margin-bottom: 16px;">
          <div style="font-size: 12.5px; font-weight: 600; margin-bottom: 6px;">Manage Subscription Entitlement</div>
          <p style="color: var(--text-muted); font-size: 12px; line-height: 1.4; margin-bottom: 12px;">
            ${
              detail.quota.plan === 'free'
                ? 'Upgrade user to Premium to increase cloud storage allowance from 1 GB to 10 GB. 10 MB per-file limit remains unchanged.'
                : 'Downgrade user to Free (1 GB limit). Existing stored files will not be deleted, but new uploads will be blocked if over 1 GB.'
            }
          </p>

          <form action="/admin/users/${encodeURIComponent(detail.user.id)}/plan" method="POST" onsubmit="return confirm('${detail.quota.plan === 'free' ? 'Make this user Premium? Their cloud storage allowance will increase from 1 GB to 10 GB.' : 'Downgrade this user to Free? Their existing files will not be deleted, but uploads will be blocked if they exceed 1 GB.'}');">
            <input type="hidden" name="plan" value="${detail.quota.plan === 'free' ? 'premium' : 'free'}">
            ${
              detail.quota.plan === 'free'
                ? `<button type="submit" class="btn btn-primary btn-sm" style="width: 100%;">★ Make Premium (10 GB)</button>`
                : `<button type="submit" class="btn btn-danger btn-sm" style="width: 100%;">Downgrade to Free (1 GB)</button>`
            }
          </form>
        </div>

        <form action="/admin/users/${encodeURIComponent(detail.user.id)}/reconcile" method="POST" style="display: flex; justify-content: flex-end;">
          <button type="submit" class="btn btn-secondary btn-sm" title="Recompute storage from database records to repair counters">
            🔄 Reconcile Storage Counter
          </button>
        </form>
      </div>
    </div>

    <!-- Administrative Audit History -->
    ${
      detail.auditLogs.length > 0
        ? `
      <div class="card">
        <div class="card-header">
          <div class="card-title">Administrative Audit Log (${detail.auditLogs.length})</div>
        </div>
        <table>
          <thead>
            <tr>
              <th>Timestamp</th>
              <th>Action</th>
              <th>Admin Identifier</th>
              <th>Previous Value</th>
              <th>New Value</th>
            </tr>
          </thead>
          <tbody>
            ${detail.auditLogs
              .map(
                (log) => `
              <tr>
                <td style="color: var(--text-muted); font-size: 12px;">${formatDate(log.createdAt)}</td>
                <td><span class="badge badge-accent">${escapeHtml(log.action)}</span></td>
                <td><span class="code-mono">${escapeHtml(log.adminIdentifier || 'admin')}</span></td>
                <td><span class="code-mono">${escapeHtml(log.oldValue || '—')}</span></td>
                <td><span class="code-mono" style="color: #FCD34D;">${escapeHtml(log.newValue || '—')}</span></td>
              </tr>
            `
              )
              .join('')}
          </tbody>
        </table>
      </div>`
        : ''
    }

    <!-- Storage Lifecycle & Garbage Collection Trigger -->
    <div class="card">
      <div class="card-header">
        <div class="card-title">Storage Lifecycle &amp; Garbage Collection</div>
      </div>
      <p style="color: var(--text-muted); font-size: 13px; margin-bottom: 16px;">
        Safe sync boundary: revision <strong>${detail.storageProfile.safeSyncBoundaryRevision}</strong>.
        Prunes orphaned attachments, expired idempotency keys, and safe historical changes beyond active device checkpoints.
      </p>
      
      <form action="/admin/users/${encodeURIComponent(detail.user.id)}/gc" method="POST" style="margin-top: 12px;">
        <div style="margin-bottom: 14px; display: flex; align-items: center; gap: 8px;">
          <input type="checkbox" id="dryRun" name="dryRun" value="true" checked>
          <label for="dryRun" style="font-size: 13px; color: var(--text-main); cursor: pointer;">
            Dry Run only (Simulate and preview reclaimable bytes without deleting)
          </label>
        </div>
        <button type="submit" class="btn btn-primary btn-sm">Trigger Garbage Collection</button>
      </form>
    </div>

    <!-- Registered Devices -->
    <div class="card">
      <div class="card-header">
        <div class="card-title">Registered Sync Devices (${detail.devices.length})</div>
      </div>
      ${
        detail.devices.length === 0
          ? `<p style="color: var(--text-muted); font-size: 13px;">No devices registered yet.</p>`
          : `
        <table>
          <thead>
            <tr>
              <th>Device Name</th>
              <th>Client Version</th>
              <th>Last Acknowledged Rev</th>
              <th>Last Seen</th>
              <th>Registered</th>
            </tr>
          </thead>
          <tbody>
            ${detail.devices
              .map(
                (d) => `
              <tr>
                <td><strong>${escapeHtml(d.deviceName || 'Unknown Device')}</strong></td>
                <td><span class="badge badge-gray">${escapeHtml(d.clientVersion || 'N/A')}</span></td>
                <td><span class="code-mono">rev ${d.lastAcknowledgedRevision}</span></td>
                <td>${formatDate(d.lastSeenAt)}</td>
                <td style="color: var(--text-muted); font-size: 12px;">${formatDate(d.createdAt)}</td>
              </tr>
            `
              )
              .join('')}
          </tbody>
        </table>`
      }
    </div>

    <!-- Recent Sync Changes -->
    <div class="card">
      <div class="card-header">
        <div class="card-title">Recent Sync Revision Log (Last 15)</div>
      </div>
      ${
        detail.recentChanges.length === 0
          ? `<p style="color: var(--text-muted); font-size: 13px;">No sync revision history found.</p>`
          : `
        <table>
          <thead>
            <tr>
              <th>Revision</th>
              <th>Note ID</th>
              <th>Change Type</th>
              <th>Timestamp</th>
            </tr>
          </thead>
          <tbody>
            ${detail.recentChanges
              .map(
                (c) => `
              <tr>
                <td><span class="badge badge-accent">r${c.revision}</span></td>
                <td><span class="code-mono">${escapeHtml(c.noteId)}</span></td>
                <td>
                  <span class="badge ${c.changeType === 'delete' ? 'badge-red' : 'badge-green'}">
                    ${escapeHtml(c.changeType)}
                  </span>
                </td>
                <td style="color: var(--text-muted); font-size: 12px;">${formatDate(c.timestamp)}</td>
              </tr>
            `
              )
              .join('')}
          </tbody>
        </table>`
      }
    </div>
  `;

  return renderLayout({
    title: `User ${detail.user.email || detail.user.id.substring(0, 8)}`,
    activeTab: 'users',
    content,
    flash,
  });
}

/**
 * Render Storage & Destruction Jobs view with Quota & Tier Breakdown.
 */
export function renderStoragePage(storage: AdminStorageOverview, flash?: string): string {
  const content = `
    <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 24px;">
      <div>
        <h1 style="font-size: 24px; font-weight: 700; letter-spacing: -0.5px;">Cloud Storage &amp; Destruction Jobs</h1>
        <p style="color: var(--text-muted); font-size: 13px;">Monitor Cloudinary media, storage quotas, and asynchronous deletion queue</p>
      </div>
    </div>

    <!-- Quota & Storage Breakdown Grid -->
    <div class="grid-4" style="margin-bottom: 24px;">
      <div class="stat-card">
        <div class="stat-label">Cloudinary Attachments</div>
        <div class="stat-value">${storage.attachmentsCount}</div>
        <div class="stat-meta">${formatBytes(storage.totalAttachmentBytes)} total storage</div>
      </div>
      <div class="stat-card">
        <div class="stat-label">PDF Documents</div>
        <div class="stat-value">${storage.documentsCount}</div>
        <div class="stat-meta">${formatBytes(storage.totalDocumentBytes)} total storage</div>
      </div>
      <div class="stat-card">
        <div class="stat-label">Free Tier Storage</div>
        <div class="stat-value">${formatBytes(storage.aggregateFreeUsage)}</div>
        <div class="stat-meta">${storage.freeUsers} users (1 GB limit each)</div>
      </div>
      <div class="stat-card">
        <div class="stat-label">Premium Tier Storage</div>
        <div class="stat-value">${formatBytes(storage.aggregatePremiumUsage)}</div>
        <div class="stat-meta">${storage.premiumUsers} users (10 GB limit each)</div>
      </div>
    </div>

    <!-- Destruction Jobs Queue -->
    <div class="card">
      <div class="card-header">
        <div class="card-title">Asynchronous Destruction Jobs (${storage.destructionJobs.length})</div>
      </div>
      <p style="color: var(--text-muted); font-size: 13px; margin-bottom: 16px;">
        Destruction jobs reliably purge deleted blobs from Cloudinary and clean up relational references.
      </p>

      ${
        storage.destructionJobs.length === 0
          ? `<p style="color: var(--text-dim); padding: 16px 0;">No queued destruction jobs currently in the database.</p>`
          : `
        <table>
          <thead>
            <tr>
              <th>State</th>
              <th>Operation</th>
              <th>Resource Type</th>
              <th>Cloudinary Public ID</th>
              <th>Attempts</th>
              <th>Last Error</th>
              <th>Created</th>
              <th style="text-align: right;">Action</th>
            </tr>
          </thead>
          <tbody>
            ${storage.destructionJobs
              .map((job) => {
                let stateBadge = 'badge-gray';
                if (job.state === 'completed') stateBadge = 'badge-green';
                if (job.state === 'failed') stateBadge = 'badge-red';
                if (job.state === 'pending' || job.state === 'processing' || job.state === 'retrying')
                  stateBadge = 'badge-amber';

                return `
              <tr>
                <td><span class="badge ${stateBadge}">${escapeHtml(job.state)}</span></td>
                <td><span class="code-mono">${escapeHtml(job.operation)}</span></td>
                <td>${escapeHtml(job.resourceType)}</td>
                <td><span class="code-mono">${escapeHtml(job.cloudinaryPublicId || 'N/A')}</span></td>
                <td>${job.attemptCount}</td>
                <td style="max-width: 200px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; color: var(--red); font-size: 12px;">
                  ${escapeHtml(job.lastError || '—')}
                </td>
                <td style="color: var(--text-muted); font-size: 12px;">${formatDate(job.createdAt)}</td>
                <td style="text-align: right;">
                  <form action="/admin/jobs/${encodeURIComponent(job.id)}/retry" method="POST" style="display:inline;">
                    <button type="submit" class="btn btn-secondary btn-sm" title="Reset state to pending">Retry</button>
                  </form>
                </td>
              </tr>
            `;
              })
              .join('')}
          </tbody>
        </table>`
      }
    </div>
  `;

  return renderLayout({
    title: 'Storage & GC',
    activeTab: 'storage',
    content,
    flash,
  });
}
