'use strict';

/**
 * Daily usage quotas by subscription tier.
 * Enforced only in Cloud Functions (Admin SDK).
 *
 * Defaults can be overridden by:
 * - config/quotas: { free: { gemini, scholar, consensus }, pro: { ... } }
 * - users/{uid}.quotaGeminiDaily / quotaScholarDaily / quotaConsensusDaily / quotaCopyleaksDaily
 * - config/quotas.consensusMonthly caps the shared Consensus API key
 */

const { getFirestore, FieldValue } = require('firebase-admin/firestore');

// month = allowance that lasts the calendar month.
// day = ceiling so one heavy day cannot empty the month.
const DEFAULT_LIMITS = {
  free: {
    month: { gemini: 0, scholar: 0, consensus: 0, copyleaks: 0 },
    day: { gemini: 0, scholar: 0, consensus: 0, copyleaks: 0 },
  },
  plus: {
    month: { gemini: 300, scholar: 90, consensus: 45, copyleaks: 15 },
    day: { gemini: 40, scholar: 15, consensus: 8, copyleaks: 2 },
  },
  pro: {
    month: { gemini: 1500, scholar: 450, consensus: 225, copyleaks: 75 },
    day: { gemini: 120, scholar: 40, consensus: 20, copyleaks: 6 },
  },
  admin: {
    month: { gemini: 100000, scholar: 100000, consensus: 100000, copyleaks: 100000 },
    day: { gemini: 100000, scholar: 100000, consensus: 100000, copyleaks: 100000 },
  },
};

/** @deprecated use DEFAULT_LIMITS — kept for require() callers */
const LIMITS = DEFAULT_LIMITS;

function utcDayKey(d = new Date()) {
  return d.toISOString().slice(0, 10);
}

function utcMonthKey(day = utcDayKey()) {
  return day.slice(0, 7);
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
 * @returns {'free'|'plus'|'pro'|'admin'}
 */
function tierFromUserData(data) {
  if (String(data.role || '') === 'admin') return 'admin';

  let sub = String(data.subscription || 'free').trim().toLowerCase();
  if (sub !== 'pro' && sub !== 'plus') return 'free';
  const exp = data.subscriptionExpiresAt;
  if (exp && typeof exp.toDate === 'function') {
    if (exp.toDate().getTime() < Date.now()) return 'free';
  } else if (typeof exp === 'string' && exp.trim()) {
    const t = Date.parse(exp);
    if (Number.isFinite(t) && t < Date.now()) return 'free';
  }
  return sub;
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
 * @returns {Promise<{ tier: string, gemini: number, scholar: number, consensus: number, copyleaks: number }>}
 */
async function resolveLimits(uid) {
  const userSnap = await db().collection('users').doc(uid).get();
  const data = userSnap.exists ? userSnap.data() || {} : {};
  const tier = tierFromUserData(data);

  const base = DEFAULT_LIMITS[tier] || DEFAULT_LIMITS.free;
  const day = { ...base.day };
  const month = { ...base.month };

  try {
    const cfgSnap = await db().collection('config').doc('quotas').get();
    if (cfgSnap.exists) {
      const tierCfg = (cfgSnap.data() || {})[tier];
      if (tierCfg && typeof tierCfg === 'object') {
        for (const kind of ['gemini', 'scholar', 'consensus', 'copyleaks']) {
          if (tierCfg[kind] != null) day[kind] = positiveInt(tierCfg[kind], day[kind]);
          const monthKey = `${kind}Month`;
          if (tierCfg[monthKey] != null) {
            month[kind] = positiveInt(tierCfg[monthKey], month[kind]);
          }
        }
      }
    }
  } catch (e) {
    console.warn('config/quotas read failed', e.message || e);
  }

  if (data.quotaGeminiDaily != null) day.gemini = positiveInt(data.quotaGeminiDaily, day.gemini);
  if (data.quotaScholarDaily != null) day.scholar = positiveInt(data.quotaScholarDaily, day.scholar);
  if (data.quotaConsensusDaily != null) {
    day.consensus = positiveInt(data.quotaConsensusDaily, day.consensus);
  }
  if (data.quotaCopyleaksDaily != null) {
    day.copyleaks = positiveInt(data.quotaCopyleaksDaily, day.copyleaks);
  }

  return {
    tier,
    gemini: day.gemini,
    scholar: day.scholar,
    consensus: day.consensus,
    copyleaks: day.copyleaks,
    month,
  };
}

function allowDegraded(reason) {
  console.error('consumeQuota degraded — allowing AI request:', reason);
  return {
    ok: true,
    used: 0,
    limit: DEFAULT_LIMITS.admin.day.gemini,
    tier: 'degraded',
    remaining: DEFAULT_LIMITS.admin.day.gemini,
    day: utcDayKey(),
    degraded: true,
  };
}

/**
 * Atomically consume one unit of daily quota.
 * @param {{ uid: string, kind: 'gemini'|'scholar'|'consensus' }} opts
 */
async function consumeQuota({ uid, kind }) {
  if (
    !uid ||
    (kind !== 'gemini' &&
      kind !== 'scholar' &&
      kind !== 'consensus' &&
      kind !== 'copyleaks')
  ) {
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

  const dayLimit = limits[kind];
  const monthLimit = limits.month[kind];
  const tier = limits.tier;
  const day = utcDayKey();
  const month = utcMonthKey(day);
  const dayRef = db().collection('usage').doc(uid).collection('daily').doc(day);
  const monthRef = db().collection('usage').doc(uid).collection('monthly').doc(month);

  // Admins are never blocked by the daily counter (still logged for metrics).
  if (tier === 'admin') {
    try {
      const snap = await dayRef.get();
      const data = snap.exists ? snap.data() || {} : {};
      const used = Math.max(0, Number(data[kind] || 0) || 0);
      const next = used + 1;
      await dayRef.set(
        {
          [kind]: next,
          date: day,
          tier,
          limitGemini: limits.gemini,
          limitScholar: limits.scholar,
          limitCopyleaks: limits.copyleaks,
          limitConsensus: limits.consensus,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      return {
        ok: true,
        used: next,
        limit: dayLimit,
        tier,
        remaining: dayLimit,
        day,
        bypassed: true,
      };
    } catch (e) {
      console.warn('admin quota log failed', e.message || e);
      return {
        ok: true,
        used: 0,
        limit: dayLimit,
        tier,
        remaining: dayLimit,
        day,
        bypassed: true,
      };
    }
  }

  try {
    const out = await db().runTransaction(async (tx) => {
      const daySnap = await tx.get(dayRef);
      const monthSnap = await tx.get(monthRef);
      const dayData = daySnap.exists ? daySnap.data() || {} : {};
      const monthData = monthSnap.exists ? monthSnap.data() || {} : {};
      const dayUsed = Math.max(0, Number(dayData[kind] || 0) || 0);
      const monthUsed = Math.max(0, Number(monthData[kind] || 0) || 0);
      if (monthUsed >= monthLimit) {
        return {
          ok: false,
          code: 'resource-exhausted',
          scope: 'month',
          used: monthUsed,
          limit: monthLimit,
          tier,
          remaining: 0,
          day,
        };
      }
      if (dayUsed >= dayLimit) {
        return {
          ok: false,
          code: 'resource-exhausted',
          scope: 'day',
          used: dayUsed,
          limit: dayLimit,
          tier,
          remaining: 0,
          day,
        };
      }
      const stamp = {
        [kind]: FieldValue.increment(1),
        tier,
        updatedAt: FieldValue.serverTimestamp(),
      };
      tx.set(dayRef, { ...stamp, date: day }, { merge: true });
      tx.set(monthRef, { ...stamp, month }, { merge: true });
      return {
        ok: true,
        used: monthUsed + 1,
        limit: monthLimit,
        dayUsed: dayUsed + 1,
        dayLimit,
        tier,
        remaining: Math.max(0, monthLimit - monthUsed - 1),
        day,
        scope: 'month',
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
  const label =
    kind === 'scholar'
      ? 'البحث عن المراجع'
      : kind === 'consensus'
        ? 'خلاصة الدراسات'
        : kind === 'copyleaks'
          ? 'فحص الأصالة'
          : 'المساعدة في الكتابة';
  const windowAr = q.scope === 'day' ? 'حد اليوم' : 'رصيد هذا الشهر';
  const windowEn = q.scope === 'day' ? 'today’s limit' : 'this month’s balance';
  const tier = q.tier || 'free';
  const ar = `انتهى حد باقتك: ${windowAr} لـ ${label} (${q.used}/${q.limit}). فعّل اشتراكاً، أو انتقل لباقة أعلى، أو اطلب زيادة الحد.`;
  const en = `Plan limit reached: ${windowEn} for ${label} (${q.used}/${q.limit}). Activate a plan, move to a higher plan, or ask to raise the limit.`;
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
