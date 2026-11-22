// تعيين أو سحب أدمن من جهاز موثوق فقط. لا يُستدعى من التطبيق.
//
// الاستخدام:
//   npm install firebase-admin
//   gcloud auth application-default login
//   export GOOGLE_CLOUD_PROJECT=acadegate-new
//   node scripts/make-admin.mjs <uid-or-email>
//   node scripts/make-admin.mjs --revoke <uid-or-email>
import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';

const args = process.argv.slice(2).filter((arg) => arg !== '--');
const revoke = args.includes('--revoke');
const target = args.find((arg) => !arg.startsWith('--'));

if (!target) {
  console.error(
    'Usage: node scripts/make-admin.mjs [--revoke] <uid-or-email>',
  );
  process.exit(1);
}

initializeApp({ credential: applicationDefault() });
const db = getFirestore();

let uid = target;
if (target.includes('@')) {
  const snap = await db
    .collection('users')
    .where('email', '==', target)
    .limit(2)
    .get();
  if (snap.empty) {
    console.error(`No user with email ${target}`);
    process.exit(1);
  }
  if (snap.size > 1) {
    console.error(`More than one user with email ${target}`);
    process.exit(1);
  }
  uid = snap.docs[0].id;
}

const role = revoke ? 'student' : 'admin';
await db.collection('users').doc(uid).set(
  {
    role,
    updatedAt: FieldValue.serverTimestamp(),
  },
  { merge: true },
);

console.log(`${revoke ? 'Revoked admin' : 'Granted admin'}: ${uid} (${role})`);
