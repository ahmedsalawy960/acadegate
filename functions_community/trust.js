"use strict";

// Pure trust logic for the community. The Firebase handlers in index.js are
// thin wrappers, so everything here can be tested with a fake database.

const REPORT_HIDE_THRESHOLD = 3;
const DEFAULT_NAME = "طالب";

function cleanName(value) {
  return typeof value === "string" ? value.trim().slice(0, 100) : "";
}

/** Name shown next to a post or reply. Comes from the server, never the client. */
function resolveAuthorName(profile, authUser) {
  const fromProfile = cleanName(profile && profile.displayName);
  if (fromProfile) return fromProfile;
  const fromAuth = cleanName(authUser && authUser.displayName);
  if (fromAuth) return fromAuth;
  const email = authUser && typeof authUser.email === "string" ? authUser.email : "";
  const local = cleanName(email.split("@")[0]);
  return local || DEFAULT_NAME;
}

/** Badge from the account's role. Only roles the platform itself assigns. */
function badgeForProfile(profile) {
  const role = profile && profile.role;
  if (role === "admin") return "team";
  if (role === "supervisor") return "supervisor";
  return "";
}

function createTrustHandlers({ db, auth, FieldValue, threshold = REPORT_HIDE_THRESHOLD }) {
  async function stampAuthor(ref, data) {
    // Team starter content carries its own fixed author line.
    if (!data || data.isStarterContent === true) return { changed: false };
    const uid = typeof data.authorId === "string" ? data.authorId : "";
    if (!uid) return { changed: false };

    const snap = await db.collection("users").doc(uid).get();
    const profile = snap.exists ? snap.data() : {};
    let authUser = null;
    try {
      authUser = await auth.getUser(uid);
    } catch (_) {
      authUser = null;
    }
    const authorName = resolveAuthorName(profile, authUser);
    const badge = badgeForProfile(profile);

    const update = { authorName };
    if (badge) update.authorBadge = badge;
    else if ("authorBadge" in data) update.authorBadge = FieldValue.delete();
    await ref.update(update);
    return { changed: true, authorName, badge };
  }

  /** Called for every new report. Hides the content once enough members reported it. */
  async function handleReport(report) {
    const postId = report && report.postId;
    const replyId = (report && report.replyId) || "";
    if (!postId) return { hidden: false, reason: "no-post" };

    const postRef = db.collection("community_posts").doc(postId);
    const targetRef = replyId ? postRef.collection("replies").doc(replyId) : postRef;
    const target = await targetRef.get();
    if (!target.exists) return { hidden: false, reason: "missing" };
    const targetData = target.data();

    const open = await db
      .collection("community_reports")
      .where("postId", "==", postId)
      .where("replyId", "==", replyId)
      .where("status", "==", "open")
      .get();

    // One document per reporter. Self-reports do not count.
    const reporters = new Set();
    open.forEach((doc) => {
      const reporterId = doc.data().reporterId;
      if (reporterId && reporterId !== targetData.authorId) reporters.add(reporterId);
    });
    if (reporters.size < threshold) return { hidden: false, reason: "below", count: reporters.size };

    if (replyId) {
      if (targetData.hiddenByReports === true) return { hidden: false, reason: "already" };
      await targetRef.update({ hiddenByReports: true, hiddenAt: FieldValue.serverTimestamp() });
      return { hidden: true, kind: "reply", count: reporters.size };
    }

    const status = targetData.approvalStatus;
    if (status !== undefined && status !== "approved") return { hidden: false, reason: "not-public" };
    await targetRef.update({
      approvalStatus: "suspended",
      hiddenByReports: true,
      hiddenAt: FieldValue.serverTimestamp(),
    });
    return { hidden: true, kind: "post", count: reporters.size };
  }

  return { stampAuthor, handleReport };
}

module.exports = {
  REPORT_HIDE_THRESHOLD,
  resolveAuthorName,
  badgeForProfile,
  createTrustHandlers,
};
