const { onRequest } = require("firebase-functions/v2/https");
const { createIpRateLimiter } = require("./http_rate_limit");

const rateLimit = createIpRateLimiter({ windowMs: 60_000, max: 30 });

const ALLOWED_HOSTS = new Set([
  "api.crossref.org",
  "api.openalex.org",
  "api.semanticscholar.org",
  "api.unpaywall.org",
  "api.openaire.eu",
  "opencitations.net",
  "api.datacite.org",
  "zenodo.org",
  "www.ebi.ac.uk",
  "serpapi.com",
  "pub.orcid.org",
  "query.wikidata.org",
]);

const DEFAULT_HEADERS = {
  Accept: "application/json",
  "User-Agent": "AcadeGate/1.0 (mailto:support@acadegate.app)",
};

/**
 * Proxy for citation APIs — fixes browser CORS on Chrome/Web.
 * GET ?url=https://api.crossref.org/works/...
 */
function createCitationProxyHandler() {
  return onRequest({ cors: true, timeoutSeconds: 30 }, async (req, res) => {
    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }
    if (rateLimit(req, res)) return;

    const targetRaw = req.query.url;
    if (!targetRaw || typeof targetRaw !== "string") {
      res.status(400).json({ error: "Missing url query parameter" });
      return;
    }

    let target;
    try {
      target = new URL(targetRaw);
    } catch (_) {
      res.status(400).json({ error: "Invalid url" });
      return;
    }

    if (target.protocol !== "https:" || !ALLOWED_HOSTS.has(target.hostname)) {
      res.status(403).json({ error: "Host not allowed" });
      return;
    }

    try {
      const response = await fetch(target.toString(), {
        headers: DEFAULT_HEADERS,
      });
      const body = await response.text();
      if (body.length > 2_000_000) {
        res.status(502).json({ error: "Upstream response too large" });
        return;
      }
      res.status(response.status);
      res.set("Content-Type", response.headers.get("content-type") || "application/json");
      res.send(body);
    } catch (err) {
      res.status(502).json({
        error: "Upstream fetch failed",
        message: String(err?.message || err),
      });
    }
  });
}

module.exports = { createCitationProxyHandler, ALLOWED_HOSTS };
