'use strict';

const admin = require("firebase-admin");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { onRequest } = require("firebase-functions/v2/https");
const {
  consumeQuota,
  quotaExceededHttpPayload,
} = require("./usage_quota");

/** Shared key budget until config/quotas.consensusMonthly is raised. */
const DEFAULT_MONTHLY_CAP = 25;

/**
 * Consensus paper search.
 * GET ?q=...&num=8&year_min=1990
 * Requires: Authorization: Bearer <Firebase ID token>
 * Secret: CONSENSUS_API_KEY
 */
function createConsensusSearchHandler(consensusKey) {
  return onRequest(
    {
      cors: true,
      timeoutSeconds: 60,
      secrets: [consensusKey],
    },
    async (req, res) => {
      if (req.method === "OPTIONS") {
        res.status(204).send("");
        return;
      }

      const authHeader = String(req.get("Authorization") || "");
      const match = authHeader.match(/^Bearer\s+(.+)$/i);
      if (!match) {
        res.status(401).json({
          error: "سجّل الدخول لاستخدام بحث Consensus.",
          errorEn: "Sign in to use Consensus search.",
          code: "unauthenticated",
          papers: [],
        });
        return;
      }

      let decoded;
      try {
        decoded = await admin.auth().verifyIdToken(match[1].trim());
      } catch (_) {
        res.status(401).json({
          error: "جلسة غير صالحة. سجّل الدخول مجدداً.",
          errorEn: "Invalid session. Sign in again.",
          code: "unauthenticated",
          papers: [],
        });
        return;
      }

      const q = String(req.query.q || "").trim();
      if (q.length < 3) {
        res.status(400).json({ error: "Missing q", papers: [] });
        return;
      }

      const key = (consensusKey.value() || "").trim();
      if (!key) {
        res.status(503).json({
          error: "CONSENSUS_API_KEY not configured",
          papers: [],
        });
        return;
      }

      const quota = await consumeQuota({ uid: decoded.uid, kind: "consensus" });
      if (!quota.ok) {
        const status = quota.code === "resource-exhausted" ? 429 : 500;
        res.status(status).json({
          ...quotaExceededHttpPayload(quota, "consensus"),
          papers: [],
        });
        return;
      }

      const month = await consumeConsensusMonth();
      if (!month.ok) {
        res.status(429).json({
          error: "وصل حد Consensus الشهري المشترك. يمكن رفعه من إعدادات الحصة.",
          errorEn: "Shared monthly Consensus limit reached.",
          code: "quota_exceeded",
          papers: [],
        });
        return;
      }

      try {
        const num = Math.min(
          20,
          Math.max(1, parseInt(String(req.query.num || "8"), 10) || 8),
        );
        const yearMin = String(req.query.year_min || "").trim();
        const target = new URL("https://api.consensus.app/v1/search");
        target.searchParams.set("query", q);
        target.searchParams.set("page_size", String(num));
        if (/^\d{4}$/.test(yearMin)) {
          target.searchParams.set("year_min", yearMin);
        }

        const response = await fetch(target.toString(), {
          headers: {
            Accept: "application/json",
            "x-api-key": key,
          },
        });
        const body = await response.text();
        if (!response.ok) {
          res.status(502).json({
            error: `Consensus ${response.status}`,
            detail: body.slice(0, 400),
            papers: [],
          });
          return;
        }

        let data;
        try {
          data = JSON.parse(body);
        } catch (_) {
          res.status(502).json({ error: "Invalid Consensus JSON", papers: [] });
          return;
        }

        const rows = Array.isArray(data.results) ? data.results : [];
        const papers = [];
        const seen = new Set();
        for (const row of rows) {
          const title = String(row.title || "").trim();
          if (!title) continue;
          const doi = String(row.doi || "")
            .replace(/^https?:\/\/(dx\.)?doi\.org\//i, "")
            .trim();
          const dedupe = (doi || title).toLowerCase();
          if (seen.has(dedupe)) continue;
          seen.add(dedupe);
          const authors = Array.isArray(row.authors)
            ? row.authors.map((name) => String(name || "").trim()).filter(Boolean)
            : [];
          papers.push({
            title,
            doi,
            year: Number.isFinite(Number(row.publish_year))
              ? Number(row.publish_year)
              : null,
            authors: authors.join(", "),
            journal: String(row.journal_name || "").trim(),
            abstract: String(row.abstract || "").trim(),
            takeaway: String(row.takeaway || "").trim(),
            url: String(row.url || "").trim(),
          });
        }

        res.status(200).json({
          source: "consensus",
          query: q,
          papers: papers.slice(0, num),
          quota: {
            used: quota.used,
            limit: quota.limit,
            remaining: quota.remaining,
            tier: quota.tier,
          },
        });
      } catch (e) {
        res.status(502).json({
          error: e.message || "Consensus search failed",
          papers: [],
        });
      }
    },
  );
}

async function consensusMonthlyCap() {
  try {
    const snap = await getFirestore().collection("config").doc("quotas").get();
    const n = Number(snap.exists ? snap.data()?.consensusMonthly : NaN);
    if (Number.isFinite(n) && n >= 0) return Math.floor(n);
  } catch (e) {
    console.warn("consensus monthly cap read failed", e.message || e);
  }
  return DEFAULT_MONTHLY_CAP;
}

async function consumeConsensusMonth() {
  const cap = await consensusMonthlyCap();
  const month = new Date().toISOString().slice(0, 7);
  const ref = getFirestore().collection("usage_global").doc("consensus");
  try {
    return await getFirestore().runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const data = snap.exists ? snap.data() || {} : {};
      const sameMonth = data.month === month;
      const used = sameMonth ? Math.max(0, Number(data.used || 0) || 0) : 0;
      if (used >= cap) return { ok: false, used, cap };
      tx.set(
        ref,
        {
          month,
          used: used + 1,
          cap,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      return { ok: true, used: used + 1, cap };
    });
  } catch (e) {
    console.error("consensus monthly quota failed", e);
    return { ok: false, used: cap, cap };
  }
}

module.exports = { createConsensusSearchHandler };
