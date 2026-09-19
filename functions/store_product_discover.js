const { onCall, HttpsError } = require("firebase-functions/v2/https");

const USER_AGENT =
  "AcadeGate/1.0 (academic product discovery; +https://acadegate.app)";

function extractKeywords(text, max = 8) {
  const cleaned = String(text || "")
    .toLowerCase()
    .replace(/[^\u0600-\u06FFa-z0-9.\-\s]/gi, " ");
  const stop = new Set([
    "the",
    "and",
    "for",
    "with",
    "from",
    "this",
    "that",
    "من",
    "إلى",
    "على",
    "في",
    "مع",
    "عن",
    "هذا",
    "هذه",
    "التي",
    "الذي",
    "أو",
    "و",
    "أن",
    "إلى",
    "يحتاج",
    "مطلوب",
    "تجربة",
    "جهاز",
  ]);
  const counts = new Map();
  for (const w of cleaned.split(/\s+/)) {
    if (w.length < 3 || stop.has(w)) continue;
    counts.set(w, (counts.get(w) || 0) + 1);
  }
  return [...counts.entries()]
    .sort((a, b) => b[1] - a[1] || b[0].length - a[0].length)
    .slice(0, max)
    .map(([w]) => w);
}

function stripHtml(html) {
  return String(html || "")
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/\s+/g, " ")
    .trim();
}

async function wooSearch(baseUrl, query, perPage) {
  const root = String(baseUrl || "").replace(/\/+$/, "");
  if (!root) return [];
  const url = new URL(`${root}/wp-json/wc/store/v1/products`);
  url.searchParams.set("search", query);
  url.searchParams.set("per_page", String(perPage || 8));
  url.searchParams.set("page", "1");

  const res = await fetch(url.toString(), {
    headers: { Accept: "application/json", "User-Agent": USER_AGENT },
    signal: AbortSignal.timeout(18000),
  });
  if (!res.ok) return [];
  const data = await res.json().catch(() => null);
  if (!Array.isArray(data)) return [];

  return data
    .map((item) => {
      if (!item || typeof item !== "object") return null;
      const name = String(item.name || "").trim();
      if (!name) return null;
      let price = 0;
      let currency = "EGP";
      if (item.prices && typeof item.prices === "object") {
        currency = item.prices.currency_code || "EGP";
        const minor = Number(item.prices.currency_minor_unit ?? 2);
        const raw = Number(item.prices.price ?? 0);
        price = raw / 10 ** (Number.isFinite(minor) ? minor : 2);
      }
      const images = Array.isArray(item.images) ? item.images : [];
      const imageUrl =
        images[0]?.src || images[0]?.thumbnail || null;
      const cats = Array.isArray(item.categories)
        ? item.categories.map((c) => c?.name).filter(Boolean)
        : [];
      const description = stripHtml(
        item.short_description || item.description || "",
      );
      return {
        name,
        price,
        currency,
        imageUrl,
        sourceUrl: item.permalink || "",
        description: description.slice(0, 500),
        category: cats[0] || "",
        sku: item.sku || "",
        inStock: item.is_in_stock !== false,
      };
    })
    .filter(Boolean);
}

async function duckDuckGoHints(query) {
  try {
    const url = new URL("https://api.duckduckgo.com/");
    url.searchParams.set("q", query);
    url.searchParams.set("format", "json");
    url.searchParams.set("no_redirect", "1");
    url.searchParams.set("no_html", "1");
    const res = await fetch(url.toString(), {
      headers: { Accept: "application/json", "User-Agent": USER_AGENT },
      signal: AbortSignal.timeout(12000),
    });
    if (!res.ok) return [];
    const data = await res.json();
    const out = [];
    if (data.AbstractURL && data.AbstractText) {
      out.push({
        title: data.Heading || query,
        url: data.AbstractURL,
        snippet: String(data.AbstractText).slice(0, 280),
        source: "duckduckgo",
      });
    }
    const related = Array.isArray(data.RelatedTopics) ? data.RelatedTopics : [];
    for (const item of related) {
      if (item && item.FirstURL && item.Text) {
        out.push({
          title: String(item.Text).slice(0, 120),
          url: item.FirstURL,
          snippet: String(item.Text).slice(0, 280),
          source: "duckduckgo",
        });
      } else if (item && Array.isArray(item.Topics)) {
        for (const t of item.Topics.slice(0, 3)) {
          if (t?.FirstURL && t?.Text) {
            out.push({
              title: String(t.Text).slice(0, 120),
              url: t.FirstURL,
              snippet: String(t.Text).slice(0, 280),
              source: "duckduckgo",
            });
          }
        }
      }
      if (out.length >= 8) break;
    }
    return out.slice(0, 8);
  } catch (_) {
    return [];
  }
}

function createStoreProductDiscoverHandlers() {
  const storeProductDiscover = onCall(
    {
      timeoutSeconds: 120,
      memory: "512MiB",
      cors: true,
    },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError(
          "unauthenticated",
          "يجب تسجيل الدخول للبحث في المتاجر",
        );
      }

      const data = request.data || {};
      const description = String(data.description || data.query || "").trim();
      if (description.length < 3) {
        throw new HttpsError(
          "invalid-argument",
          "اكتب وصفاً أو كلمات بحث أوضح",
        );
      }

      const keywords = Array.isArray(data.keywords) && data.keywords.length
        ? data.keywords.map(String).filter(Boolean).slice(0, 8)
        : extractKeywords(description);

      // استعلام قصير لـ Woo — تجنب إرسال فقرة Gemini كاملة
      let searchQuery = String(data.storeQuery || "").trim();
      if (!searchQuery) {
        const firstLine = String(description)
          .split(/\r?\n/)
          .map((l) => l.trim().replace(/^[\-\*\d\.\)\s]+/, ""))
          .find((l) => l.length >= 3);
        if (firstLine && /[A-Za-z]/.test(firstLine) && firstLine.length <= 100) {
          searchQuery = firstLine.slice(0, 80);
        } else if (keywords.length) {
          searchQuery = keywords.slice(0, 5).join(" ");
        } else {
          searchQuery = description.slice(0, 80);
        }
      }

      const queryVariants = [
        searchQuery,
        keywords.slice(0, 3).join(" "),
        keywords.find((k) => /^[a-z0-9.\-]+$/i.test(k)) || "",
      ].filter((q, i, arr) => q && q.length >= 2 && arr.indexOf(q) === i);

      const suppliers = Array.isArray(data.suppliers) ? data.suppliers : [];
      const perSupplier = Math.min(
        Math.max(Number(data.perSupplier) || 6, 1),
        12,
      );

      const remote = [];
      const errors = [];
      const seen = new Set();

      const tasks = suppliers
        .filter((s) => s && s.baseUrl)
        .slice(0, 16)
        .map(async (s) => {
          try {
            for (const q of queryVariants) {
              const products = await wooSearch(s.baseUrl, q, perSupplier);
              for (const p of products) {
                const key = (p.sourceUrl || `${s.id}|${p.name}`).toLowerCase();
                if (seen.has(key)) continue;
                seen.add(key);
                remote.push({
                  ...p,
                  storeName: s.nameAr || s.nameEn || s.id || "Supplier",
                  supplierId: s.id || "",
                  website: s.website || "",
                  email: s.email || "",
                  phone: s.phone || "",
                  fromRemoteSite: true,
                });
              }
              if (remote.filter((r) => r.supplierId === (s.id || "")).length >=
                perSupplier) {
                break;
              }
            }
          } catch (err) {
            errors.push({
              supplierId: s.id || "",
              error: String(err?.message || err),
            });
          }
        });

      const webHintsPromise = duckDuckGoHints(
        `${searchQuery} lab supply OR scientific OR reagent OR filter`,
      );

      const [, webHints] = await Promise.all([
        Promise.all(tasks),
        webHintsPromise,
      ]);

      const qEnc = encodeURIComponent(searchQuery);
      const webSearchLinks = [
        {
          title: "Google — بحث منتجات",
          url: `https://www.google.com/search?q=${qEnc}+lab+OR+scientific+supply`,
          snippet: "بحث عام عن المنتج على الإنترنت",
          source: "google",
        },
        {
          title: "Google Shopping",
          url: `https://www.google.com/search?tbm=shop&q=${qEnc}`,
          snippet: "مقارنة أسعار ومنتجات مشابهة",
          source: "google_shopping",
        },
        {
          title: "DuckDuckGo",
          url: `https://duckduckgo.com/?q=${qEnc}+scientific+supply`,
          snippet: "بحث بديل بدون تتبع",
          source: "duckduckgo_search",
        },
      ];

      const wooSupplierCount = suppliers.filter((s) => s && s.baseUrl).length;
      return {
        searchQuery,
        keywords,
        remote,
        webHints,
        webSearchLinks,
        errors,
        note:
          `بحث مباشر في ${wooSupplierCount} متاجر WooCommerce فقط + كتالوج التطبيق + روابط Google. ` +
          "باقي الموردين المستوردين دليل اتصال بلا فهرس منتجات حي — وليست زيارة لكل مواقعهم.",
      };
    },
  );

  return { storeProductDiscover };
}

module.exports = { createStoreProductDiscoverHandlers };
