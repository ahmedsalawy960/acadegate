'use strict';

const admin = require("firebase-admin");
const { onRequest } = require("firebase-functions/v2/https");
const {
  consumeQuota,
  quotaExceededHttpPayload,
} = require("./usage_quota");

/**
 * Google Scholar via SerpAPI (paid intermediary — Scholar has no public API).
 * ResearchGate has no public search API; Scholar results often surface RG links.
 *
 * GET ?q=...&num=40
 * Requires: Authorization: Bearer <Firebase ID token>
 * Secret: SERPAPI_API_KEY
 */
function createGoogleScholarSearchHandler(serpapiKey) {
  return onRequest(
    {
      cors: true,
      timeoutSeconds: 60,
      secrets: [serpapiKey],
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
          error: "سجّل الدخول لاستخدام بحث Google Scholar.",
          errorEn: "Sign in to use Google Scholar search.",
          code: "unauthenticated",
          organic_results: [],
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
          organic_results: [],
        });
        return;
      }

      const uid = decoded.uid;
      const quota = await consumeQuota({ uid, kind: "scholar" });
      if (!quota.ok) {
        const status = quota.code === "resource-exhausted" ? 429 : 500;
        res.status(status).json({
          ...quotaExceededHttpPayload(quota, "scholar"),
          organic_results: [],
        });
        return;
      }

      const q = String(req.query.q || "").trim();
      if (q.length < 3) {
        res.status(400).json({ error: "Missing q", organic_results: [] });
        return;
      }

      const key = (serpapiKey.value() || "").trim();
      if (!key) {
        res.status(503).json({
          error: "SERPAPI_API_KEY not configured",
          organic_results: [],
        });
        return;
      }

      try {
        const num = Math.min(
          60,
          Math.max(1, parseInt(String(req.query.num || "20"), 10) || 20),
        );
        const asYlo = String(req.query.as_ylo || "").trim();
        const pages = Math.ceil(num / 20);
        const slim = [];
        const seen = new Set();

        for (let page = 0; page < pages; page++) {
          const start = page * 20;
          const pageNum = Math.min(20, num - start);
          const target = new URL("https://serpapi.com/search.json");
          target.searchParams.set("engine", "google_scholar");
          target.searchParams.set("q", q);
          target.searchParams.set("api_key", key);
          target.searchParams.set("num", String(pageNum));
          target.searchParams.set("start", String(start));
          target.searchParams.set("hl", "en");
          if (/^\d{4}$/.test(asYlo)) target.searchParams.set("as_ylo", asYlo);

          const response = await fetch(target.toString(), {
            headers: { Accept: "application/json" },
          });
          const body = await response.text();
          if (!response.ok) {
            if (slim.length > 0) break;
            res.status(502).json({
              error: `SerpAPI ${response.status}`,
              detail: body.slice(0, 400),
              organic_results: [],
            });
            return;
          }
          let data;
          try {
            data = JSON.parse(body);
          } catch (_) {
            if (slim.length > 0) break;
            res
              .status(502)
              .json({ error: "Invalid SerpAPI JSON", organic_results: [] });
            return;
          }
          const organic = Array.isArray(data.organic_results)
            ? data.organic_results
            : [];
          if (organic.length === 0) break;
          for (const row of organic) {
            const title = row.title || "";
            const link = row.link || "";
            const dedupe = `${title}|${link}`.toLowerCase();
            if (!title || seen.has(dedupe)) continue;
            seen.add(dedupe);
            slim.push({
              position: slim.length + 1,
              title,
              link,
              snippet: row.snippet || "",
              publication_info: row.publication_info || {},
              resources: row.resources || [],
              result_id: row.result_id || "",
            });
          }
          if (organic.length < pageNum) break;
        }

        res.status(200).json({
          source: "google_scholar_serpapi",
          query: q,
          organic_results: slim.slice(0, num),
          quota: {
            used: quota.used,
            limit: quota.limit,
            remaining: quota.remaining,
            tier: quota.tier,
          },
        });
      } catch (e) {
        res.status(502).json({
          error: e.message || "Scholar search failed",
          organic_results: [],
        });
      }
    },
  );
}

module.exports = { createGoogleScholarSearchHandler };
