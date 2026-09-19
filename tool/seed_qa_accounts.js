/**
 * Seed closed-beta QA accounts (Auth + Firestore users docs).
 * Usage (from repo root):
 *   node tool/seed_qa_accounts.js
 * Requires Firebase CLI login / Application Default Credentials for project acadegate-new.
 */
const path = require('path');
const admin = require(path.join(__dirname, '..', 'functions', 'node_modules', 'firebase-admin'));

if (!admin.apps.length) {
  admin.initializeApp({ projectId: 'acadegate-new' });
}

const auth = admin.auth();
const db = admin.firestore();

/** Shared QA password — change after first login in real outreach. */
const QA_PASSWORD = 'AcadeGateQA2026!';

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

async function upsertAccount(spec) {
  let user;
  try {
    user = await auth.getUserByEmail(spec.email);
    await auth.updateUser(user.uid, {
      password: QA_PASSWORD,
      displayName: spec.displayName,
      emailVerified: true,
    });
    console.log('updated auth', spec.email);
  } catch (e) {
    if (e.code !== 'auth/user-not-found') throw e;
    user = await auth.createUser({
      email: spec.email,
      password: QA_PASSWORD,
      displayName: spec.displayName,
      emailVerified: true,
    });
    console.log('created auth', spec.email);
  }

  await db.collection('users').doc(user.uid).set(
    {
      email: spec.email,
      displayName: spec.displayName,
      role: spec.role,
      activePortal: spec.activePortal,
      subscription: 'free',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      qaSeed: true,
    },
    { merge: true },
  );
  console.log('upserted firestore', spec.email, '→', spec.role, user.uid);
}

async function main() {
  for (const a of accounts) {
    await upsertAccount(a);
  }
  console.log('\nQA password for all:', QA_PASSWORD);
  console.log('Emails:');
  for (const a of accounts) console.log(' -', a.email, `(${a.role})`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
