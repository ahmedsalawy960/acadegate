"use strict";

// Separate functions codebase for community trust. It shares no files with the
// main functions folder, so deploying it never touches the other functions.

const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { initializeApp, getApps } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getAuth } = require("firebase-admin/auth");
const { createTrustHandlers, resolveAuthorName } = require("./trust");
const { createNotifyHandlers } = require("./notify");

if (getApps().length === 0) initializeApp();

// Must match the Firestore database location (see the deploy notes).
const REGION = "europe-west1";

function handlers() {
  return createTrustHandlers({ db: getFirestore(), auth: getAuth(), FieldValue });
}

exports.communityStampPostAuthor = onDocumentCreated(
  { document: "community_posts/{postId}", region: REGION },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    await handlers().stampAuthor(snap.ref, snap.data());
  },
);

exports.communityStampReplyAuthor = onDocumentCreated(
  { document: "community_posts/{postId}/replies/{replyId}", region: REGION },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    await handlers().stampAuthor(snap.ref, snap.data());
  },
);

exports.communityAutoHideReported = onDocumentCreated(
  { document: "community_reports/{reportId}", region: REGION },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    await handlers().handleReport(snap.data());
  },
);

async function nameFor(uid) {
  const snap = await getFirestore().collection("users").doc(uid).get();
  let authUser = null;
  try {
    authUser = await getAuth().getUser(uid);
  } catch (_) {
    authUser = null;
  }
  return resolveAuthorName(snap.exists ? snap.data() : {}, authUser);
}

function notifier() {
  return createNotifyHandlers({ db: getFirestore(), FieldValue, nameFor });
}

exports.communityNotifyReply = onDocumentCreated(
  { document: "community_posts/{postId}/replies/{replyId}", region: REGION },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    await notifier().handleReply(event.params.postId, snap.data());
  },
);

exports.communityNotifyPostApproved = onDocumentUpdated(
  { document: "community_posts/{postId}", region: REGION },
  async (event) => {
    const change = event.data;
    if (!change) return;
    await notifier().handlePostStatus(
      event.params.postId,
      change.before.data(),
      change.after.data(),
    );
  },
);
