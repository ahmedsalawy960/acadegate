/**
 * Guard against SSRF when Cloud Functions fetch remote URLs.
 */

function isPrivateOrLocalHostname(hostname) {
  const host = String(hostname || "")
    .trim()
    .toLowerCase()
    .replace(/\.$/, "");
  if (!host) return true;
  if (host === "localhost" || host.endsWith(".localhost") || host.endsWith(".local")) {
    return true;
  }
  if (host === "metadata.google.internal") return true;

  // IPv4 literals
  const ipv4 = host.match(/^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/);
  if (ipv4) {
    const parts = ipv4.slice(1).map((n) => Number(n));
    if (parts.some((n) => n > 255)) return true;
    const [a, b] = parts;
    if (a === 10) return true;
    if (a === 127) return true;
    if (a === 0) return true;
    if (a === 169 && b === 254) return true;
    if (a === 172 && b >= 16 && b <= 31) return true;
    if (a === 192 && b === 168) return true;
    if (a === 100 && b >= 64 && b <= 127) return true; // CGNAT
  }

  // IPv6 / IPv6-mapped rough checks
  if (host.includes(":")) {
    if (
      host === "::1" ||
      host.startsWith("fc") ||
      host.startsWith("fd") ||
      host.startsWith("fe80") ||
      host.includes("::ffff:127.") ||
      host.includes("::ffff:10.") ||
      host.includes("::ffff:192.168.")
    ) {
      return true;
    }
  }

  return false;
}

/**
 * @param {string} rawUrl
 * @param {{ allowedHosts?: string[] }} [opts]
 * @returns {URL}
 */
function assertSafePublicHttpsUrl(rawUrl, opts = {}) {
  let parsed;
  try {
    parsed = new URL(String(rawUrl || "").trim());
  } catch (_) {
    throw new Error("Invalid URL");
  }

  if (parsed.protocol !== "https:" && parsed.protocol !== "http:") {
    throw new Error("Only http(s) URLs are allowed");
  }

  // Prefer https; allow http only for non-local public hosts (still blocked if private).
  if (isPrivateOrLocalHostname(parsed.hostname)) {
    throw new Error("Private or local hosts are not allowed");
  }

  const allowed = opts.allowedHosts;
  if (Array.isArray(allowed) && allowed.length > 0) {
    const host = parsed.hostname.toLowerCase();
    const ok = allowed.some(
      (h) => host === h.toLowerCase() || host.endsWith(`.${h.toLowerCase()}`),
    );
    if (!ok) {
      throw new Error("Host is not on the allowlist");
    }
  }

  return parsed;
}

/**
 * Firebase Storage download URLs / GCS HTTPS for the project bucket.
 * Rejects arbitrary hosts.
 */
function assertFirebaseStorageHttpsUrl(rawUrl, projectId = "acadegate-new") {
  const parsed = assertSafePublicHttpsUrl(rawUrl);
  const host = parsed.hostname.toLowerCase();
  const path = parsed.pathname || "";

  const allowedHosts = new Set([
    "firebasestorage.googleapis.com",
    "storage.googleapis.com",
    `${projectId}.firebasestorage.app`,
  ]);
  if (!allowedHosts.has(host)) {
    throw new Error("fileUrl must be a Firebase Storage HTTPS URL");
  }

  const bucketHints = [
    projectId,
    `${projectId}.appspot.com`,
    `${projectId}.firebasestorage.app`,
  ];
  const pathLower = path.toLowerCase();
  const hostPath = `${host}${pathLower}`;
  const mentionsProject = bucketHints.some((hint) =>
    hostPath.includes(String(hint).toLowerCase()),
  );
  if (!mentionsProject) {
    throw new Error("fileUrl bucket does not match this project");
  }

  return parsed;
}

module.exports = {
  assertSafePublicHttpsUrl,
  assertFirebaseStorageHttpsUrl,
  isPrivateOrLocalHostname,
};
