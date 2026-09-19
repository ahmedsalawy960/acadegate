const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { getFirestore, FieldValue, Timestamp } = require("firebase-admin/firestore");

async function userHasAdminRole(db, uid) {
  const snap = await db.collection("users").doc(uid).get();
  return snap.exists && snap.data()?.role === "admin";
}

/** ISO week id like 2026-W38 and Monday 00:00 UTC start. */
function weekBounds(at = new Date()) {
  const d = new Date(
    Date.UTC(at.getUTCFullYear(), at.getUTCMonth(), at.getUTCDate()),
  );
  const day = d.getUTCDay() || 7; // Mon=1 … Sun=7
  if (day !== 1) d.setUTCDate(d.getUTCDate() - (day - 1));
  d.setUTCHours(0, 0, 0, 0);
  const weekStart = new Date(d);
  const weekEnd = new Date(d);
  weekEnd.setUTCDate(weekEnd.getUTCDate() + 7);

  const thursday = new Date(weekStart);
  thursday.setUTCDate(thursday.getUTCDate() + 3);
  const week1 = new Date(Date.UTC(thursday.getUTCFullYear(), 0, 4));
  const week1Day = week1.getUTCDay() || 7;
  week1.setUTCDate(week1.getUTCDate() - (week1Day - 1));
  const weekNo =
    1 + Math.round((weekStart - week1) / (7 * 24 * 60 * 60 * 1000));
  const year = thursday.getUTCFullYear();
  const weekId = `${year}-W${String(weekNo).padStart(2, "0")}`;
  return { weekId, weekStart, weekEnd };
}

function parseWeekId(weekId) {
  const m = String(weekId || "").match(/^(\d{4})-W(\d{2})$/);
  if (!m) return weekBounds();
  const year = Number(m[1]);
  const weekNo = Number(m[2]);
  const week1 = new Date(Date.UTC(year, 0, 4));
  const week1Day = week1.getUTCDay() || 7;
  week1.setUTCDate(week1.getUTCDate() - (week1Day - 1));
  const weekStart = new Date(week1);
  weekStart.setUTCDate(weekStart.getUTCDate() + (weekNo - 1) * 7);
  weekStart.setUTCHours(0, 0, 0, 0);
  const weekEnd = new Date(weekStart);
  weekEnd.setUTCDate(weekEnd.getUTCDate() + 7);
  return { weekId: `${year}-W${String(weekNo).padStart(2, "0")}`, weekStart, weekEnd };
}

function inRange(ts, start, end) {
  if (!ts) return false;
  const t = ts.toDate ? ts.toDate() : new Date(ts);
  return t >= start && t < end;
}

async function computeWeeklyKpis(db, weekIdInput) {
  const { weekId, weekStart, weekEnd } = weekIdInput
    ? parseWeekId(weekIdInput)
    : weekBounds();

  const startTs = Timestamp.fromDate(weekStart);
  const endTs = Timestamp.fromDate(weekEnd);

  const usersSnap = await db.collection("users").get();
  let registeredUsers = 0;
  let activeUsers = 0;
  let firstSearchResearchers = 0;

  const d7Start = new Date(weekEnd);
  d7Start.setUTCDate(d7Start.getUTCDate() - 14);
  const d7End = new Date(weekEnd);
  d7End.setUTCDate(d7End.getUTCDate() - 7);
  let cohortD7 = 0;
  let returnedD7 = 0;

  const d30Start = new Date(weekEnd);
  d30Start.setUTCDate(d30Start.getUTCDate() - 37);
  const d30End = new Date(weekEnd);
  d30End.setUTCDate(d30End.getUTCDate() - 30);
  let cohortD30 = 0;
  let returnedD30 = 0;

  const partnerUids = new Set();
  const activePartnerUids = new Set();

  for (const doc of usersSnap.docs) {
    const data = doc.data() || {};
    const role = String(data.role || "");
    const createdAt = data.createdAt;
    const lastActiveAt = data.lastActiveAt;
    const firstSearchAt = data.firstSearchAt;

    if (inRange(createdAt, weekStart, weekEnd)) registeredUsers += 1;
    if (inRange(lastActiveAt, weekStart, weekEnd)) activeUsers += 1;
    const isResearcherRole =
      !role ||
      role === "student" ||
      role === "researcher" ||
      role === "user";
    if (inRange(firstSearchAt, weekStart, weekEnd) && isResearcherRole) {
      firstSearchResearchers += 1;
    }

    if (inRange(createdAt, d7Start, d7End)) {
      cohortD7 += 1;
      if (lastActiveAt && lastActiveAt.toDate && lastActiveAt.toDate() >= d7End) {
        returnedD7 += 1;
      }
    }
    if (inRange(createdAt, d30Start, d30End)) {
      cohortD30 += 1;
      if (lastActiveAt && lastActiveAt.toDate && lastActiveAt.toDate() >= d30End) {
        returnedD30 += 1;
      }
    }

    const isProvider =
      role === "merchant" ||
      role === "lab_manager" ||
      role === "supervisor" ||
      role === "writer" ||
      role === "idea_publisher";
    if (isProvider || data.providerApprovalStatus === "approved") {
      partnerUids.add(doc.id);
      if (inRange(lastActiveAt, weekStart, weekEnd)) {
        activePartnerUids.add(doc.id);
      }
    }
  }

  // Partners flagged on directory listings who were active this week.
  const suppliersSnap = await db
    .collection("store_suppliers")
    .where("isPartner", "==", true)
    .limit(500)
    .get()
    .catch(() => null);
  if (suppliersSnap) {
    for (const doc of suppliersSnap.docs) {
      const uid = String(doc.data().claimedByUid || "");
      if (!uid) continue;
      partnerUids.add(uid);
      const user = usersSnap.docs.find((d) => d.id === uid);
      const lastActiveAt = user?.data()?.lastActiveAt;
      if (inRange(lastActiveAt, weekStart, weekEnd)) {
        activePartnerUids.add(uid);
      }
    }
  }

  let searches = 0;
  let contactRequests = 0;
  let profileClaims = 0;
  let profileVerified = 0;
  let criticalErrors = 0;
  let partnerActivityEvents = 0;

  const eventsSnap = await db
    .collection("kpi_events")
    .where("weekId", "==", weekId)
    .get()
    .catch(async () => {
      // Fallback if weekId index missing: scan by createdAt.
      return db
        .collection("kpi_events")
        .where("createdAt", ">=", startTs)
        .where("createdAt", "<", endTs)
        .get();
    });

  for (const doc of eventsSnap.docs) {
    const type = String(doc.data().type || "");
    if (type === "search") searches += 1;
    else if (type === "contact_request") contactRequests += 1;
    else if (type === "profile_claim") profileClaims += 1;
    else if (type === "profile_verified") profileVerified += 1;
    else if (type === "critical_error") criticalErrors += 1;
    else if (type === "partner_activity") {
      partnerActivityEvents += 1;
      const uid = String(doc.data().uid || "");
      if (uid) activePartnerUids.add(uid);
    }
  }

  const searchesPerActiveUser =
    activeUsers > 0 ? Number((searches / activeUsers).toFixed(2)) : 0;
  const retentionD7 =
    cohortD7 > 0 ? Number(((returnedD7 / cohortD7) * 100).toFixed(1)) : null;
  const retentionD30 =
    cohortD30 > 0 ? Number(((returnedD30 / cohortD30) * 100).toFixed(1)) : null;

  const existing = await db.collection("kpi_weekly").doc(weekId).get();
  const adSpend =
    typeof existing.data()?.adSpend === "number"
      ? existing.data().adSpend
      : 0;
  const cac =
    registeredUsers > 0 && adSpend > 0
      ? Number((adSpend / registeredUsers).toFixed(2))
      : null;

  const payload = {
    weekId,
    weekStart: Timestamp.fromDate(weekStart),
    weekEnd: Timestamp.fromDate(weekEnd),
    registeredUsers,
    activeUsers,
    firstSearchResearchers,
    searches,
    searchesPerActiveUser,
    profileClaims,
    profileVerified,
    contactRequests,
    retentionD7Pct: retentionD7,
    retentionD7Cohort: cohortD7,
    retentionD7Returned: returnedD7,
    retentionD30Pct: retentionD30,
    retentionD30Cohort: cohortD30,
    retentionD30Returned: returnedD30,
    criticalErrors,
    partnersInDb: partnerUids.size,
    activePartners: activePartnerUids.size,
    partnerActivityEvents,
    adSpend,
    cac,
    computedAt: FieldValue.serverTimestamp(),
  };

  await db.collection("kpi_weekly").doc(weekId).set(payload, { merge: true });
  return payload;
}

function createKpiWeeklyHandlers() {
  const adminComputeWeeklyKpis = onCall(
    {
      cors: true,
      serviceAccount: "acadegate-new@appspot.gserviceaccount.com",
      timeoutSeconds: 300,
    },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Sign in required");
      }
      const db = getFirestore();
      if (!(await userHasAdminRole(db, request.auth.uid))) {
        throw new HttpsError("permission-denied", "Admin only");
      }
      const weekId = String((request.data || {}).weekId || "").trim();
      const result = await computeWeeklyKpis(db, weekId || null);
      return { ok: true, kpi: result };
    },
  );

  const adminSetWeeklyAdSpend = onCall(
    {
      cors: true,
      serviceAccount: "acadegate-new@appspot.gserviceaccount.com",
    },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Sign in required");
      }
      const db = getFirestore();
      if (!(await userHasAdminRole(db, request.auth.uid))) {
        throw new HttpsError("permission-denied", "Admin only");
      }
      const weekId =
        String((request.data || {}).weekId || "").trim() ||
        weekBounds().weekId;
      const adSpend = Number((request.data || {}).adSpend);
      if (!Number.isFinite(adSpend) || adSpend < 0) {
        throw new HttpsError("invalid-argument", "adSpend must be >= 0");
      }
      await db.collection("kpi_weekly").doc(weekId).set(
        {
          weekId,
          adSpend,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      const kpi = await computeWeeklyKpis(db, weekId);
      return { ok: true, kpi };
    },
  );

  const kpiWeeklyScheduled = onSchedule(
    {
      schedule: "every monday 06:00",
      timeZone: "Africa/Cairo",
      serviceAccount: "acadegate-new@appspot.gserviceaccount.com",
    },
    async () => {
      const db = getFirestore();
      // Previous ISO week (just closed).
      const prev = new Date();
      prev.setUTCDate(prev.getUTCDate() - 7);
      await computeWeeklyKpis(db, weekBounds(prev).weekId);
      await computeWeeklyKpis(db, weekBounds().weekId);
    },
  );

  return { adminComputeWeeklyKpis, adminSetWeeklyAdSpend, kpiWeeklyScheduled };
}

module.exports = { createKpiWeeklyHandlers, computeWeeklyKpis, weekBounds };
