/**
 * Simple per-instance IP rate limiter for public HTTP Cloud Functions.
 * Not a global quota across instances — still reduces abuse bursts.
 */

function clientIp(req) {
  const fwd = req.headers["x-forwarded-for"];
  if (typeof fwd === "string" && fwd.length > 0) {
    return fwd.split(",")[0].trim();
  }
  return req.ip || req.socket?.remoteAddress || "unknown";
}

/**
 * @param {{ windowMs?: number, max?: number }} opts
 * @returns {(req: import('express').Request, res: import('express').Response) => boolean}
 *   returns true if limited (response already sent)
 */
function createIpRateLimiter(opts = {}) {
  const windowMs = opts.windowMs ?? 60_000;
  const max = opts.max ?? 60;
  /** @type {Map<string, { count: number, resetAt: number }>} */
  const buckets = new Map();

  // Bound memory growth on long-lived instances
  const MAX_KEYS = 5000;

  return function checkRateLimit(req, res) {
    const now = Date.now();
    const key = clientIp(req);
    let bucket = buckets.get(key);
    if (!bucket || now >= bucket.resetAt) {
      bucket = { count: 0, resetAt: now + windowMs };
      if (buckets.size >= MAX_KEYS) {
        // Drop oldest-ish entries
        const first = buckets.keys().next().value;
        if (first != null) buckets.delete(first);
      }
      buckets.set(key, bucket);
    }
    bucket.count += 1;
    const remaining = Math.max(0, max - bucket.count);
    res.set("X-RateLimit-Limit", String(max));
    res.set("X-RateLimit-Remaining", String(remaining));
    res.set("X-RateLimit-Reset", String(Math.ceil(bucket.resetAt / 1000)));
    if (bucket.count > max) {
      res.status(429).json({
        error: "Too many requests",
        retryAfterSec: Math.ceil((bucket.resetAt - now) / 1000),
      });
      return true;
    }
    return false;
  };
}

module.exports = { createIpRateLimiter, clientIp };
