"use strict";

// Separate functions codebase for community trust. It shares no files with the
// main functions folder, so deploying it never touches the other functions.

const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp, getApps } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getAuth } = require("firebase-admin/auth");
const { createTrustHandlers } = require("./trust");

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
