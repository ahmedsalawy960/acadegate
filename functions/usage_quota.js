'use strict';

/**
 * Daily usage quotas by subscription tier.
 * Enforced only in Cloud Functions (Admin SDK).
 *
 * Defaults can be overridden by:
 * - config/quotas: { free: { gemini, scholar }, pro: { gemini, scholar } }
 * - users/{uid}.quotaGeminiDaily / quotaScholarDaily (per-user)
 */

const { getFirestore, FieldValue } = require('firebase-admin/firestore');

const DEFAULT_LIMITS = {
  free: { gemini: 20, scholar: 6 },
  pro: { gemini: 100, scholar: 30 },
  admin: { gemini: 100000, scholar: 100000 },
};

/** @deprecated use DEFAULT_LIMITS — kept for require() callers */
const LIMITS = DEFAULT_LIMITS;

function utcDayKey(d = new Date()) {
  return d.toISOString().slice(0, 10);
}

function db() {
  return getFirestore();
}

function positiveInt(value, fallback) {
  const n = Number(value);
  if (!Number.isFinite(n) || n < 0) return fallback;
  return Math.min(Math.floor(n), 1000000);
}

function isPermissionError(err) {
  const code = err && (err.code || err.status);
  const msg = String((err && err.message) || err || '');
  return (
    code === 7 ||
    code === 'permission-denied' ||
    /PERMISSION_DENIED|Missing or insufficient permissions/i.test(msg)
  );
}

/**
 * @param {FirebaseFirestore.DocumentData} data
 * @returns {'free'|'pro'|'admin'}
 */
function tierFromUserData(data) {
  if (String(data.role || '') === 'admin') return 'admin';

  let sub = String(data.subscription || 'free').trim().toLowerCase();
  if (sub === 'pro') {
    const exp = data.subscriptionExpiresAt;
    if (exp && typeof exp.toDate === 'function') {
      if (exp.toDate().getTime() < Date.now()) sub = 'free';
    } else if (typeof exp === 'string' && exp.trim()) {
      const t = Date.parse(exp);
      if (Number.isFinite(t) && t < Date.now()) sub = 'free';
    }
  }
  return sub === 'pro' ? 'pro' : 'free';
}

/**
 * @param {string} uid
 * @returns {Promise<'free'|'pro'|'admin'>}
 */
async function resolveTier(uid) {
  const snap = await db().collection('users').doc(uid).get();
  const data = snap.exists ? snap.data() || {} : {};
  return tierFromUserData(data);
}

/**
 * @param {string} uid
 * @returns {Promise<{ tier: string, gemini: number, scholar: number }>}
 */
async function resolveLimits(uid) {
  const userSnap = await db().collection('users').doc(uid).get();
  const data = userSnap.exists ? userSnap.data() || {} : {};
  const tier = tierFromUserData(data);

  let gemini = DEFAULT_LIMITS[tier]?.gemini ?? DEFAULT_LIMITS.free.gemini;
  let scholar = DEFAULT_LIMITS[tier]?.scholar ?? DEFAULT_LIMITS.free.scholar;

  try {
    const cfgSnap = await db().collection('config').doc('quotas').get();
    if (cfgSnap.exists) {
      const cfg = cfgSnap.data() || {};
      const tierCfg = cfg[tier];
      if (tierCfg && typeof tierCfg === 'object') {
        if (tierCfg.gemini != null) gemini = positiveInt(tierCfg.gemini, gemini);
        if (tierCfg.scholar != null) {
          scholar = positiveInt(tierCfg.scholar, scholar);
        }
      }
    }
  } catch (e) {
    console.warn('config/quotas read failed', e.message || e);
  }

  if (data.quotaGeminiDaily != null) {
    gemini = positiveInt(data.quotaGeminiDaily, gemini);
  }
  if (data.quotaScholarDaily != null) {
    scholar = positiveInt(data.quotaScholarDaily, scholar);
  }

  return { tier, gemini, scholar };
}

function allowDegraded(reason) {
  console.error('consumeQuota degraded — allowing AI request:', reason);
  return {
    ok: true,
    used: 0,
    limit: DEFAULT_LIMITS.admin.gemini,
    tier: 'degraded',
    remaining: DEFAULT_LIMITS.admin.gemini,
    day: utcDayKey(),
    degraded: true,
  };
}

/**
 * Atomically consume one unit of daily quota.
 * @param {{ uid: string, kind: 'gemini'|'scholar' }} opts
 */
async function consumeQuota({ uid, kind }) {
  if (!uid || (kind !== 'gemini' && kind !== 'scholar')) {
    return {
      ok: false,
      code: 'invalid-argument',
      message: 'Invalid quota request.',
    };
  }

  let limits;
  try {
    limits = await resolveLimits(uid);
  } catch (e) {
    // Firestore IAM / Admin read failures must not brick Gemini.
    return allowDegraded(e.message || e);
  }

  const limit = kind === 'gemini' ? limits.gemini : limits.scholar;
  const tier = limits.tier;
  const day = utcDayKey();
  const ref = db().collection('usage').doc(uid).collection('daily').doc(day);

  // Admins are never blocked by the daily counter (still logged for metrics).
  if (tier === 'admin') {
    try {
      const snap = await ref.get();
      const data = snap.exists ? snap.data() || {} : {};
      const used = Math.max(0, Number(data[kind] || 0) || 0);
      const next = used + 1;
      await ref.set(
        {
          [kind]: next,
          date: day,
          tier,
          limitGemini: limits.gemini,
          limitScholar: limits.scholar,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      return {
        ok: true,
        used: next,
        limit,
        tier,
        remaining: limit,
        day,
        bypassed: true,
      };
    } catch (e) {
      console.warn('admin quota log failed', e.message || e);
      return {
        ok: true,
        used: 0,
        limit,
        tier,
        remaining: limit,
        day,
        bypassed: true,
      };
    }
  }

  try {
    const out = await db().runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const data = snap.exists ? snap.data() || {} : {};
      const used = Math.max(0, Number(data[kind] || 0) || 0);
      if (used >= limit) {
        return {
          ok: false,
          code: 'resource-exhausted',
          used,
          limit,
          tier,
          remaining: 0,
          day,
        };
      }
      const next = used + 1;
      tx.set(
        ref,
        {
          [kind]: next,
          date: day,
          tier,
          limitGemini: limits.gemini,
          limitScholar: limits.scholar,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      return {
        ok: true,
        used: next,
        limit,
        tier,
        remaining: Math.max(0, limit - next),
        day,
      };
    });
    return out;
  } catch (e) {
    console.error('consumeQuota failed', e);
    if (isPermissionError(e)) {
      return allowDegraded(e.message || e);
    }
    return {
      ok: false,
      code: 'internal',
      message: 'Could not update usage quota.',
    };
  }
}

function quotaExceededHttpPayload(q, kind) {
  const label = kind === 'scholar' ? 'Google Scholar' : 'AcadeGate AI';
  const tier = q.tier || 'free';
  const ar = `وصلت للحد اليومي لـ ${label} (${q.used}/${q.limit}). عدّل الحد من لوحة الإدارة أو حاول غداً.`;
  const en = `Daily ${label} limit reached (${q.used}/${q.limit}). Adjust the limit in admin or try tomorrow.`;
  return { error: ar, errorEn: en, code: 'quota_exceeded', quota: q, tier };
}

function quotaExceededHttpsError(q, kind) {
  const { HttpsError } = require('firebase-functions/v2/https');
  const payload = quotaExceededHttpPayload(q, kind);
  return new HttpsError('resource-exhausted', payload.error, {
    code: 'quota_exceeded',
    errorEn: payload.errorEn,
    quota: q,
  });
}

module.exports = {
  LIMITS,
  DEFAULT_LIMITS,
  resolveTier,
  resolveLimits,
  consumeQuota,
  quotaExceededHttpPayload,
  quotaExceededHttpsError,
  utcDayKey,
};
