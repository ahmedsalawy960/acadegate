/**
 * Seed QA accounts via Identity Toolkit REST (no Admin ADC required).
 * Creates Auth users + Firestore users docs using the signed-in ID token.
 *
 * Usage: node tool/seed_qa_accounts_rest.js
 */
const https = require('https');

const API_KEY = process.env.FIREBASE_WEB_API_KEY || '';
if (!API_KEY) {
  console.error(
    'Set FIREBASE_WEB_API_KEY (Firebase Console → Project settings → Web API key)',
  );
  process.exit(1);
}
const QA_PASSWORD = 'AcadeGateQA2026!';
const PROJECT_ID = 'acadegate-new';

const accounts = [
  {
    email: 'qa.student@acadegate.test',
    displayName: 'QA Student',
    role: 'student',
    activePortal: 'researcher',
  },
  {
    email: 'qa.merchant@acadegate.test',
    displayName: 'QA Merchant',
    role: 'merchant',
    activePortal: 'provider',
  },
  {
    email: 'qa.lab@acadegate.test',
    displayName: 'QA Lab Manager',
    role: 'lab_manager',
    activePortal: 'provider',
  },
  {
    email: 'qa.supervisor@acadegate.test',
    displayName: 'QA Supervisor',
    role: 'supervisor',
    activePortal: 'provider',
  },
];

function requestJson(method, url, body, headers = {}) {
  return new Promise((resolve, reject) => {
    const data = body == null ? null : JSON.stringify(body);
    const u = new URL(url);
    const req = https.request(
      {
        hostname: u.hostname,
        path: u.pathname + u.search,
        method,
        headers: {
          ...(data
            ? {
                'Content-Type': 'application/json',
                'Content-Length': Buffer.byteLength(data),
              }
            : {}),
          ...headers,
        },
      },
      (res) => {
        let raw = '';
        res.on('data', (c) => (raw += c));
        res.on('end', () => {
          let parsed;
          try {
            parsed = JSON.parse(raw || '{}');
          } catch {
            parsed = { raw };
          }
          if (res.statusCode && res.statusCode >= 400) {
            const err = new Error(
              parsed.error?.message || parsed.error?.status || raw || String(res.statusCode),
            );
            err.status = res.statusCode;
            err.body = parsed;
            reject(err);
            return;
          }
          resolve(parsed);
        });
      },
    );
    req.on('error', reject);
    if (data) req.write(data);
    req.end();
  });
}

async function signUpOrSignIn(email, password) {
  try {
    return await requestJson(
      'POST',
      `https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${API_KEY}`,
      { email, password, returnSecureToken: true },
    );
  } catch (e) {
    if (String(e.message || e).includes('EMAIL_EXISTS')) {
      return requestJson(
        'POST',
        `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${API_KEY}`,
        { email, password, returnSecureToken: true },
      );
    }
    throw e;
  }
}

function firestoreFields(a) {
  return {
    email: { stringValue: a.email },
    displayName: { stringValue: a.displayName },
    role: { stringValue: a.role },
    activePortal: { stringValue: a.activePortal },
    subscription: { stringValue: 'free' },
    qaSeed: { booleanValue: true },
  };
}

async function upsertUserDoc(idToken, uid, a) {
  const name = `projects/${PROJECT_ID}/databases/(default)/documents/users/${uid}`;
  const authHeader = { Authorization: `Bearer ${idToken}` };
  // PATCH to the document path creates or updates (merge via updateMask when present).
  await requestJson(
    'PATCH',
    `https://firestore.googleapis.com/v1/${name}?updateMask.fieldPaths=email&updateMask.fieldPaths=displayName&updateMask.fieldPaths=role&updateMask.fieldPaths=activePortal&updateMask.fieldPaths=subscription&updateMask.fieldPaths=qaSeed`,
    { fields: firestoreFields(a) },
    authHeader,
  );
}

async function main() {
  for (const a of accounts) {
    const auth = await signUpOrSignIn(a.email, QA_PASSWORD);
    console.log('auth ok', a.email, auth.localId);
    await upsertUserDoc(auth.idToken, auth.localId, a);
    console.log('firestore ok', a.email, '→', a.role);
  }
  console.log('\nQA password:', QA_PASSWORD);
  console.log('Emails: qa.student / qa.merchant / qa.lab / qa.supervisor @acadegate.test');
  console.log('Note: @acadegate.test bypasses email verification in debug/beta only.');
}

main().catch((e) => {
  console.error(e.message || e);
  if (e.body) console.error(JSON.stringify(e.body, null, 2));
  process.exit(1);
});
