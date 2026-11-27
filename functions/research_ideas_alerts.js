const { onSchedule } = require("firebase-functions/v2/scheduler");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

// تنبيهات الأفكار البحثية الجديدة + تتبع أحدث التطورات على الورقة المصدر.
// New-idea alerts (in-app + FCM push) and a weekly "latest developments"
// scan over grounded ideas. Server-side only: clients never write the
// notifications collection (rules), these jobs use the Admin SDK.

const OPENALEX_MAILTO = "mailto:acadegate@acadegate.app";

const DEVELOPMENTS_WINDOW_DAYS = 60;
const DEVELOPMENTS_MAX_IDEAS = 50;
const DEVELOPMENTS_PER_IDEA = 3;

const ALERTS_MAX_IDEAS_PER_RUN = 20;
const ALERTS_MAX_NOTIFICATIONS_PER_RUN = 200;
const FCM_MULTICAST_LIMIT = 500;

const FACULTY_TITLES_AR = {
  Engineering: "الهندسة",
  Science: "العلوم",
  Medicine: "الطب",
  Dentistry: "طب الأسنان",
  Pharmacy: "الصيدلة",
  Nursing: "التمريض",
  Veterinary: "الطب البيطري",
  Law: "الحقوق",
  CS: "الحاسبات والمعلومات",
  Agriculture: "الزراعة",
  Business: "التجارة",
  Education: "التربية",
  Arts: "الآداب",
  Architecture: "العمارة",
  MassCommunication: "الإعلام",
  Tourism: "السياحة والفنادق",
  PhysicalEducation: "التربية الرياضية",
  FineArts: "الفنون الجميلة",
  ProfessionalStudies: "الدراسات المهنية",
};

async function fetchOpenAlexCitations(openAlexId, perPage) {
  const params = new URLSearchParams({
    filter: `cites:${openAlexId},is_oa:true`,
    sort: "publication_date:desc",
    "per-page": String(perPage),
    mailto: OPENALEX_MAILTO,
  });
  const res = await fetch(`https://api.openalex.org/works?${params}`, {
    headers: {
      Accept: "application/json",
      "User-Agent": `AcadeGateResearchIdeasAlerts ${OPENALEX_MAILTO}`,
    },
  }).catch(() => null);
  if (!res || !res.ok) return [];
  const data = await res.json().catch(() => null);
  const results = Array.isArray(data?.results) ? data.results : [];
  return results
    .map((work) => {
      const ids = work?.ids || {};
      const doi = String(ids.doi || work?.doi || "").replace(
        /^https?:\/\/doi\.org\//i,
        "",
      );
      const best = work?.best_oa_location || work?.primary_location || {};
      return {
        title: String(work?.display_name || "").trim(),
        year: work?.publication_year || null,
        url:
          best.landing_page_url ||
          (doi ? `https://doi.org/${doi}` : ""),
        doi,
        publishedDate: String(work?.publication_date || ""),
      };
    })
    .filter((w) => w.title);
}

/** أحدث التطورات: أوراق حديثة تستشهد بالورقة المصدر لكل فكرة مؤصلة. */
async function runDevelopmentsScan() {
  const db = getFirestore();
  const cutoffMs = Date.now() - DEVELOPMENTS_WINDOW_DAYS * 24 * 3600 * 1000;
  const snap = await db
    .collection("research_ideas")
    .where("generationMode", "==", "oa_fulltext")
    .get();
  const candidates = snap.docs
    .map((d) => ({ id: d.id, data: d.data() }))
    .filter(({ data }) => {
      const openAlexId = String(data?.sourcePaper?.openAlexId || "");
      if (!openAlexId) return false;
      const createdAt = data?.createdAt;
      const createdMs =
        createdAt && typeof createdAt.toMillis === "function"
          ? createdAt.toMillis()
          : 0;
      return createdMs >= cutoffMs;
    })
    .sort((a, b) => {
      const am = a.data.createdAt?.toMillis?.() || 0;
      const bm = b.data.createdAt?.toMillis?.() || 0;
      return bm - am;
    })
    .slice(0, DEVELOPMENTS_MAX_IDEAS);

  let batch = db.batch();
  let ops = 0;
  let updated = 0;
  for (const { id, data } of candidates) {
    const openAlexId = String(data?.sourcePaper?.openAlexId || "");
    const developments = await fetchOpenAlexCitations(
      openAlexId,
      DEVELOPMENTS_PER_IDEA,
    );
    batch.set(
      db.collection("research_ideas").doc(id),
      {
        latestDevelopments: developments.slice(0, DEVELOPMENTS_PER_IDEA),
        developmentsCheckedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    ops += 1;
    updated += 1;
    if (ops >= 400) {
      await batch.commit();
      batch = db.batch();
      ops = 0;
    }
  }
  if (ops > 0) await batch.commit();
  return { scanned: candidates.length, updated };
}

/**
 * تنبيهات الأفكار الجديدة: إشعار داخل التطبيق + Push حقيقي (FCM) للمشتركين
 * في كلية الفكرة. الرموز الميتة تُزال حتى لا تضيع حصة الإرسال.
 */
async function runNewIdeaAlerts() {
  const db = getFirestore();
  const metaRef = db.doc("app_meta/research_ideas_alerts");
  const metaSnap = await metaRef.get();
  const lastChecked = metaSnap.exists ? metaSnap.get("lastCheckedAt") : null;
  const cursor =
    lastChecked && typeof lastChecked.toDate === "function"
      ? lastChecked.toDate()
      : new Date(Date.now() - 24 * 3600 * 1000);

  const ideasSnap = await db
    .collection("research_ideas")
    .where("createdAt", ">", cursor)
    .orderBy("createdAt", "asc")
    .limit(ALERTS_MAX_IDEAS_PER_RUN)
    .get();

  if (ideasSnap.empty) {
    await metaRef.set(
      { lastCheckedAt: FieldValue.serverTimestamp() },
      { merge: true },
    );
    return { ideas: 0, notified: 0, pushed: 0 };
  }

  const subsSnap = await db.collection("idea_alert_subscriptions").get();
  const subs = subsSnap.docs.map((d) => ({
    uid: d.id,
    faculties: Array.isArray(d.get("faculties"))
      ? d.get("faculties").map(String)
      : [],
  }));

  let notified = 0;
  let pushed = 0;
  let lastSeen = cursor;

  for (const ideaDoc of ideasSnap.docs) {
    const idea = ideaDoc.data();
    const createdAt =
      idea.createdAt && typeof idea.createdAt.toDate === "function"
        ? idea.createdAt.toDate()
        : null;
    if (createdAt && createdAt > lastSeen) lastSeen = createdAt;

    const category = String(idea.category || "");
    const targets = subs
      .filter(
        (s) =>
          s.faculties.includes("all") ||
          (category && s.faculties.includes(category)),
      )
      .map((s) => s.uid);
    if (!targets.length) continue;
    if (notified + targets.length > ALERTS_MAX_NOTIFICATIONS_PER_RUN) break;

    const categoryAr = FACULTY_TITLES_AR[category] || category || "البحث العلمي";
    const title = `فكرة بحثية جديدة في ${categoryAr}`;
    const body = String(idea.title || "").slice(0, 180);

    let batch = db.batch();
    for (const uid of targets) {
      batch.set(db.collection("notifications").doc(), {
        userId: uid,
        title,
        body,
        type: "new_research_idea",
        senderId: "system_ideas_alerts",
        read: false,
        contextId: ideaDoc.id,
        contextType: "research_idea",
        createdAt: FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    notified += targets.length;

    // Push (FCM): الرمز محفوظ في users/{uid}.fcmToken من التطبيق.
    const userDocs = await db.getAll(
      ...targets.map((uid) => db.collection("users").doc(uid)),
    );
    const tokenByUid = new Map();
    for (const userDoc of userDocs) {
      const token = String(userDoc.get("fcmToken") || "").trim();
      if (token) tokenByUid.set(userDoc.id, token);
    }
    const tokens = [...tokenByUid.values()].slice(0, FCM_MULTICAST_LIMIT);
    if (!tokens.length) continue;

    const res = await getMessaging().sendEachForMulticast({
      tokens,
      notification: { title, body },
      data: {
        type: "new_research_idea",
        contextType: "research_idea",
        contextId: ideaDoc.id,
      },
      android: { priority: "high" },
      apns: { payload: { aps: { sound: "default" } } },
    });
    pushed += res.successCount;

    const deadTokens = [];
    res.responses.forEach((resp, idx) => {
      const code = resp.error ? String(resp.error.code || "") : "";
      if (
        code === "messaging/registration-token-not-registered" ||
        code === "messaging/invalid-registration-token"
      ) {
        deadTokens.push(tokens[idx]);
      }
    });
    if (deadTokens.length) {
      const prune = db.batch();
      for (const [uid, token] of tokenByUid) {
        if (deadTokens.includes(token)) {
          prune.set(
            db.collection("users").doc(uid),
            { fcmToken: "" },
            { merge: true },
          );
        }
      }
      await prune.commit();
    }
  }

  await metaRef.set(
    { lastCheckedAt: lastSeen, lastRunAt: FieldValue.serverTimestamp() },
    { merge: true },
  );
  return { ideas: ideasSnap.size, notified, pushed };
}

function createResearchIdeasAlertHandlers() {
  const researchIdeasDevelopmentsWeekly = onSchedule(
    {
      schedule: "every monday 05:30",
      timeZone: "Africa/Cairo",
      timeoutSeconds: 540,
      memory: "512MiB",
    },
    async () => {
      await runDevelopmentsScan();
    },
  );

  const researchIdeasNewIdeaAlertsDaily = onSchedule(
    {
      schedule: "every day 04:30",
      timeZone: "Africa/Cairo",
      timeoutSeconds: 540,
      memory: "512MiB",
    },
    async () => {
      await runNewIdeaAlerts();
    },
  );

  return { researchIdeasDevelopmentsWeekly, researchIdeasNewIdeaAlertsDaily };
}

module.exports = {
  createResearchIdeasAlertHandlers,
  runDevelopmentsScan,
  runNewIdeaAlerts,
};
