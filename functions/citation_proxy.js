const { onRequest } = require("firebase-functions/v2/https");

const ALLOWED_HOSTS = new Set([
  "api.crossref.org",
  "api.openalex.org",
  "api.semanticscholar.org",
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

module.exports = { createCitationProxyHandler };
