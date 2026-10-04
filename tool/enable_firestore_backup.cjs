/**
 * Enable Firestore scheduled backups + run a safe export/import drill.
 * Uses the existing Firebase CLI login (no API keys, no gcloud required).
 *
 * Usage: node tool/enable_firestore_backup.mjs
 */
const auth = require(
  'C:/Users/SPEED/AppData/Roaming/npm/node_modules/firebase-tools/lib/auth.js',
);

const PROJECT = 'acadegate-new';
const DATABASE = '(default)';
const BUCKET = `${PROJECT}-firestore-backups`;
const DRILL_DB = `backup-drill-${new Date().toISOString().slice(0, 10).replace(/-/g, '')}`;

async function token() {
  const account = auth.getGlobalDefaultAccount();
  if (!account?.tokens?.refresh_token) {
    throw new Error('Firebase CLI not logged in. Run: firebase login');
  }
  // Use only cloud-platform — matches firebase login scopes.
  // Extra scopes (datastore/storage) can make refresh fail with invalid_scope.
  const scopes = require(
    'C:/Users/SPEED/AppData/Roaming/npm/node_modules/firebase-tools/lib/scopes.js',
  );
  const t = await auth.getAccessToken(account.tokens.refresh_token, [
    scopes.CLOUD_PLATFORM,
  ]);
  const access = t.access_token || t.accessToken;
  if (!access) throw new Error('Could not refresh access token');
  return access;
}

async function api(access, method, url, body) {
  const res = await fetch(url, {
    method,
    headers: {
      Authorization: `Bearer ${access}`,
      'Content-Type': 'application/json',
      'x-goog-user-project': PROJECT,
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let json = null;
  try {
    json = text ? JSON.parse(text) : null;
  } catch {
    json = { raw: text };
  }
  if (!res.ok) {
    const err = new Error(
      `${method} ${url} -> ${res.status}: ${json?.error?.message || text}`,
    );
    err.status = res.status;
    err.body = json;
    throw err;
  }
  return json;
}

async function waitOp(access, name, label) {
  console.log(`Waiting for: ${label}`);
  for (let i = 0; i < 90; i++) {
    const op = await api(
      access,
      'GET',
      `https://firestore.googleapis.com/v1/${name}`,
    );
    if (op.done) {
      if (op.error) throw new Error(`${label} failed: ${JSON.stringify(op.error)}`);
      console.log(`OK: ${label}`);
      return op;
    }
    await new Promise((r) => setTimeout(r, 10000));
  }
  throw new Error(`Timeout waiting for ${label}`);
}

async function ensureBucket(access) {
  try {
    await api(
      access,
      'GET',
      `https://storage.googleapis.com/storage/v1/b/${BUCKET}`,
    );
    console.log(`Bucket exists: gs://${BUCKET}`);
  } catch (e) {
    if (e.status !== 404) throw e;
    console.log(`Creating bucket gs://${BUCKET} ...`);
    // Prefer same location as Firestore when known; fallback multi-region.
    await api(
      access,
      'POST',
      `https://storage.googleapis.com/storage/v1/b?project=${PROJECT}`,
      {
        name: BUCKET,
        location: 'EU',
        storageClass: 'STANDARD',
        iamConfiguration: {
          uniformBucketLevelAccess: { enabled: true },
          publicAccessPrevention: 'enforced',
        },
      },
    );
    console.log(`Created gs://${BUCKET}`);
  }
}

async function main() {
  console.log(`Project: ${PROJECT}`);
  const access = await token();
  console.log(`Signed in as Firebase CLI user`);

  // 1) Describe database
  const db = await api(
    access,
    'GET',
    `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/${encodeURIComponent(DATABASE)}`,
  );
  console.log(`Database location: ${db.locationId || '(unknown)'} type=${db.type}`);

  // 2) List / create daily backup schedule
  const schedulesUrl = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/${encodeURIComponent(DATABASE)}/backupSchedules`;
  let schedules = await api(access, 'GET', schedulesUrl);
  const existing = (schedules.backupSchedules || []).filter(
    (s) => s.dailyRecurrence,
  );
  if (existing.length) {
    console.log('Daily backup schedule already exists:');
    for (const s of existing) {
      console.log(`  - ${s.name} retention=${s.retention}`);
    }
  } else {
    console.log('Creating daily backup schedule (retention 14 days)...');
    const created = await api(access, 'POST', schedulesUrl, {
      retention: '1209600s', // 14 days
      dailyRecurrence: {},
    });
    console.log(`Created schedule: ${created.name}`);
  }

  // Also ensure weekly schedule (Sunday) if missing
  schedules = await api(access, 'GET', schedulesUrl);
  const weekly = (schedules.backupSchedules || []).filter(
    (s) => s.weeklyRecurrence,
  );
  if (!weekly.length) {
    console.log('Creating weekly backup schedule (Sunday, retention 14 weeks)...');
    try {
      const created = await api(access, 'POST', schedulesUrl, {
        retention: '8467200s', // 14 weeks
        weeklyRecurrence: { day: 'SUNDAY' },
      });
      console.log(`Created weekly schedule: ${created.name}`);
    } catch (e) {
      console.warn(`Weekly schedule skipped: ${e.message}`);
    }
  } else {
    console.log(`Weekly schedule OK: ${weekly[0].name}`);
  }

  // 3) Manual export drill (immediate)
  await ensureBucket(access);
  const stamp = new Date()
    .toISOString()
    .replace(/[:.]/g, '-')
    .slice(0, 19);
  const exportPrefix = `gs://${BUCKET}/manual-${stamp}`;
  console.log(`Starting export -> ${exportPrefix}`);
  const exportOp = await api(
    access,
    'POST',
    `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/${encodeURIComponent(DATABASE)}:exportDocuments`,
    { outputUriPrefix: exportPrefix },
  );
  await waitOp(access, exportOp.name, 'Firestore export');

  // 4) Create drill database + import (does NOT touch production default DB)
  console.log(`Creating drill database: ${DRILL_DB}`);
  let createOp;
  try {
    createOp = await api(
      access,
      'POST',
      `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases?databaseId=${DRILL_DB}`,
      {
        type: 'FIRESTORE_NATIVE',
        locationId: db.locationId || 'eur3',
        concurrencyMode: 'PESSIMISTIC',
      },
    );
  } catch (e) {
    if (String(e.message).includes('already exists')) {
      console.log('Drill database already exists, continuing import...');
    } else {
      throw e;
    }
  }
  if (createOp?.name) {
    await waitOp(access, createOp.name, `Create database ${DRILL_DB}`);
  }

  console.log(`Importing export into ${DRILL_DB} ...`);
  const importOp = await api(
    access,
    'POST',
    `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/${DRILL_DB}:importDocuments`,
    { inputUriPrefix: exportPrefix },
  );
  await waitOp(access, importOp.name, 'Firestore import (restore drill)');

  // 5) Spot-check: list a few documents from users if present
  let verified = 'import completed';
  try {
    const listed = await api(
      access,
      'POST',
      `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/${DRILL_DB}/documents:runQuery`,
      {
        structuredQuery: {
          from: [{ collectionId: 'users' }],
          limit: 1,
        },
      },
    );
    const hasDoc = Array.isArray(listed) && listed.some((r) => r.document);
    verified = hasDoc
      ? 'users collection readable on drill DB'
      : 'import OK (users empty or missing — still valid)';
    console.log(`Verify: ${verified}`);
  } catch (e) {
    verified = `import OK; spot-check skipped (${e.message})`;
    console.warn(verified);
  }

  console.log('\n=== RESULT ===');
  console.log(JSON.stringify({
    project: PROJECT,
    dailyBackupSchedule: true,
    exportUri: exportPrefix,
    drillDatabase: DRILL_DB,
    verified,
  }, null, 2));
}

main().catch((e) => {
  console.error('\nFAILED:', e.message);
  if (e.body) console.error(JSON.stringify(e.body, null, 2));
  process.exit(1);
});
