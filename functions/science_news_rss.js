const { onRequest } = require("firebase-functions/v2/https");

const ITEMS_PER_FEED = 12;
const MAX_ITEMS = 200;
const AR_SUPPLEMENT_THRESHOLD = 25;

const FEEDS_EN = [
  { sourceName: "ScienceDaily", url: "https://www.sciencedaily.com/rss/all.xml", category: "general" },
  { sourceName: "ScienceDaily — Health", url: "https://www.sciencedaily.com/rss/health_medicine.xml", category: "medicine" },
  { sourceName: "ScienceDaily — Mind & Brain", url: "https://www.sciencedaily.com/rss/mind_brain.xml", category: "psychology" },
  { sourceName: "ScienceDaily — Tech", url: "https://www.sciencedaily.com/rss/tech.xml", category: "technology" },
  { sourceName: "ScienceDaily — Earth", url: "https://www.sciencedaily.com/rss/earth_climate.xml", category: "environment" },
  { sourceName: "ScienceDaily — Life", url: "https://www.sciencedaily.com/rss/plants_animals.xml", category: "agriculture" },
  { sourceName: "ScienceDaily — Physics", url: "https://www.sciencedaily.com/rss/matter_energy.xml", category: "physics" },
  { sourceName: "ScienceDaily — Space", url: "https://www.sciencedaily.com/rss/space_time.xml", category: "astronomy" },
  { sourceName: "ScienceDaily — Math & CS", url: "https://www.sciencedaily.com/rss/computers_math.xml", category: "mathematics" },
  { sourceName: "Nature", url: "https://feeds.nature.com/nature/rss/current", category: "biology" },
  { sourceName: "Nature Medicine", url: "https://feeds.nature.com/nm/rss/current", category: "medicine" },
  { sourceName: "Phys.org", url: "https://phys.org/rss-feed/", category: "physics" },
  { sourceName: "Medical Xpress", url: "https://medicalxpress.com/rss-feed/", category: "medicine" },
  { sourceName: "Tech Xplore", url: "https://techxplore.com/rss-feed/", category: "technology" },
  { sourceName: "NASA", url: "https://www.nasa.gov/rss/dyn/breaking_news.rss", category: "astronomy" },
  { sourceName: "IEEE Spectrum", url: "https://spectrum.ieee.org/feeds/feed.rss", category: "engineering" },
  { sourceName: "MIT Technology Review", url: "https://www.technologyreview.com/feed/", category: "technology" },
  { sourceName: "WHO", url: "https://www.who.int/rss-feeds/news-english.xml", category: "medicine" },
];

/** Arabic science feeds only — no general/political news portals. */
const FEEDS_AR = [
  {
    sourceName: "دويتشه فيله — علوم",
    url: "https://rss.dw.com/rdf/rss-ar-sci",
    category: "general",
  },
];

function stripHtml(raw) {
  return String(raw || "")
    .replace(/<!\[CDATA\[|\]\]>/g, "")
    .replace(/<[^>]+>/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function parseDate(raw) {
  if (!raw) return null;
  const d = new Date(stripHtml(raw));
  return Number.isNaN(d.getTime()) ? null : d.toISOString();
}

function containsAny(text, keywords) {
  return keywords.some((k) => text.includes(k));
}

function detectCategory(text, fallback) {
  const lower = String(text || "").toLowerCase();
  if (containsAny(lower, ["medical", "health", "clinical", "cancer", "virus", "طب", "مرض", "دواء"])) {
    return "medicine";
  }
  if (containsAny(lower, ["engineer", "material", "robot", "ieee", "هندس"])) {
    return "engineering";
  }
  if (containsAny(lower, ["physics", "quantum", "particle", "laser", "فيزياء"])) {
    return "physics";
  }
  if (containsAny(lower, ["chemistry", "chemical", "molecule", "catalyst", "كيمياء"])) {
    return "chemistry";
  }
  if (containsAny(lower, ["biology", "cell", "gene", "genome", "protein", "أحياء", "خلية"])) {
    return "biology";
  }
  if (containsAny(lower, ["climate", "environment", "pollution", "carbon", "مناخ", "بيئة"])) {
    return "environment";
  }
  if (containsAny(lower, ["agriculture", "crop", "farm", "soil", "زراع", "محصول"])) {
    return "agriculture";
  }
  if (containsAny(lower, ["psychology", "brain", "mental", "cognitive", "نفس", "دماغ"])) {
    return "psychology";
  }
  if (containsAny(lower, ["space", "nasa", "galaxy", "telescope", "planet", "فضاء", "فلك"])) {
    return "astronomy";
  }
  if (containsAny(lower, ["math", "algorithm", "statistics", "theorem", "رياض", "خوارزم"])) {
    return "mathematics";
  }
  if (containsAny(lower, ["ai", "computer", "software", "digital", "chip", "ذكاء", "حاسوب"])) {
    return "technology";
  }
  return fallback;
}

function resolveCategory(text, feedCategory) {
  let cat = feedCategory !== "general" ? feedCategory : detectCategory(text, feedCategory);
  const lower = String(text || "").toLowerCase();
  if (
    cat === "physics" &&
    containsAny(lower, ["chemistry", "chemical", "molecule", "catalyst", "polymer"])
  ) {
    cat = "chemistry";
  }
  return cat;
}

function parseRssXml(xml, feed, language) {
  const items = [];
  const itemRegex = /<item\b[^>]*>([\s\S]*?)<\/item>/gi;
  let match;

  while ((match = itemRegex.exec(xml)) !== null && items.length < ITEMS_PER_FEED) {
    const block = match[1];
    const title = block.match(/<title[^>]*>([\s\S]*?)<\/title>/i)?.[1];
    const link = block.match(/<link[^>]*>([\s\S]*?)<\/link>/i)?.[1]
      || block.match(/<link[^>]+href="([^"]+)"/i)?.[1];
    const desc = block.match(/<description[^>]*>([\s\S]*?)<\/description>/i)?.[1]
      || block.match(/<summary[^>]*>([\s\S]*?)<\/summary>/i)?.[1]
      || block.match(/<content[^>]*>([\s\S]*?)<\/content>/i)?.[1]
      || "";
    const pubDate = block.match(/<pubDate[^>]*>([\s\S]*?)<\/pubDate>/i)?.[1]
      || block.match(/<dc:date[^>]*>([\s\S]*?)<\/dc:date>/i)?.[1]
      || block.match(/<updated[^>]*>([\s\S]*?)<\/updated>/i)?.[1];

    const cleanTitle = stripHtml(title);
    const cleanLink = stripHtml(link);
    if (!cleanTitle || !cleanLink) continue;

    const summary = stripHtml(desc).slice(0, 420);
    items.push({
      title: cleanTitle,
      summary,
      source: feed.sourceName,
      category: resolveCategory(`${cleanTitle} ${summary}`, feed.category),
      url: cleanLink,
      publishedAt: parseDate(pubDate),
      language,
    });
  }

  if (items.length > 0) return items;

  const entryRegex = /<entry\b[^>]*>([\s\S]*?)<\/entry>/gi;
  while ((match = entryRegex.exec(xml)) !== null && items.length < ITEMS_PER_FEED) {
    const block = match[1];
    const title = block.match(/<title[^>]*>([\s\S]*?)<\/title>/i)?.[1];
    const link = block.match(/<link[^>]+href="([^"]+)"/i)?.[1]
      || block.match(/<id[^>]*>([\s\S]*?)<\/id>/i)?.[1];
    const summary = block.match(/<summary[^>]*>([\s\S]*?)<\/summary>/i)?.[1]
      || block.match(/<content[^>]*>([\s\S]*?)<\/content>/i)?.[1]
      || "";
    const updated = block.match(/<updated[^>]*>([\s\S]*?)<\/updated>/i)?.[1]
      || block.match(/<published[^>]*>([\s\S]*?)<\/published>/i)?.[1];

    const cleanTitle = stripHtml(title);
    const cleanLink = stripHtml(link);
    if (!cleanTitle || !cleanLink) continue;

    const cleanSummary = stripHtml(summary).slice(0, 420);
    items.push({
      title: cleanTitle,
      summary: cleanSummary,
      source: feed.sourceName,
      category: resolveCategory(`${cleanTitle} ${cleanSummary}`, feed.category),
      url: cleanLink,
      publishedAt: parseDate(updated),
      language,
    });
  }

  return items;
}

async function fetchFeed(feed, language) {
  try {
    const response = await fetch(feed.url, {
      headers: {
        "User-Agent": "AcadeGate-ScienceNews/1.0 (+https://acadegate.app)",
        Accept: "application/rss+xml, application/xml, text/xml, */*",
      },
      signal: AbortSignal.timeout(20000),
    });
    if (!response.ok) return [];
    const xml = await response.text();
    if (!xml.includes("<") || xml.trimStart().startsWith("<!DOCTYPE html")) return [];
    return parseRssXml(xml, feed, language);
  } catch (_) {
    return [];
  }
}

function dedupeItems(items) {
  const seen = new Set();
  const out = [];
  for (const item of items) {
    const key = item.title.toLowerCase().trim();
    if (!key || seen.has(key)) continue;
    seen.add(key);
    out.push(item);
  }
  return out;
}

async function fetchFeedBatch(feeds, language) {
  const batches = await Promise.all(feeds.map((feed) => fetchFeed(feed, language)));
  return batches.flat();
}

function createScienceNewsRssHandler() {
  return onRequest(
    {
      cors: true,
      timeoutSeconds: 120,
      memory: "512MiB",
    },
    async (req, res) => {
      if (req.method === "OPTIONS") {
        res.status(204).send("");
        return;
      }

      const lang = req.query.lang === "ar" ? "ar" : "en";
      let items = [];

      if (lang === "ar") {
        items = await fetchFeedBatch(FEEDS_AR, "ar");
        if (items.length < AR_SUPPLEMENT_THRESHOLD) {
          const supplement = await fetchFeedBatch(FEEDS_EN, "en");
          items = [...items, ...supplement];
        }
      } else {
        items = await fetchFeedBatch(FEEDS_EN, "en");
      }

      items.sort((a, b) => {
        const ad = a.publishedAt ? new Date(a.publishedAt).getTime() : 0;
        const bd = b.publishedAt ? new Date(b.publishedAt).getTime() : 0;
        return bd - ad;
      });

      items = dedupeItems(items).slice(0, MAX_ITEMS);

      res.status(200).json({
        ok: true,
        language: lang,
        count: items.length,
        items,
      });
    },
  );
}

module.exports = { createScienceNewsRssHandler };
