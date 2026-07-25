/**
 * Parses tool/generate_research_ideas_seed.py add(...) calls and emits Dart seed.
 */
const fs = require("fs");
const path = require("path");

const pyPath = path.join(__dirname, "generate_research_ideas_seed.py");
const outPath = path.join(
  __dirname,
  "../lib/features/research_marketplace/seed/egypt_research_ideas_seed.dart"
);

const py = fs.readFileSync(pyPath, "utf8");

function parseStringLiteral(s, start) {
  const quote = s[start];
  if (quote !== '"' && quote !== "'") throw new Error("expected string at " + start);
  let i = start + 1;
  let out = "";
  while (i < s.length) {
    const c = s[i];
    if (c === "\\") {
      const n = s[i + 1];
      if (n === "n") {
        out += "\n";
        i += 2;
        continue;
      }
      out += n;
      i += 2;
      continue;
    }
    if (c === quote) return { value: out, end: i + 1 };
    out += c;
    i++;
  }
  throw new Error("unterminated string");
}

function skipWs(s, i) {
  while (i < s.length && /\s/.test(s[i])) i++;
  return i;
}

function parseList(s, start) {
  // start at '['
  let i = start + 1;
  const items = [];
  i = skipWs(s, i);
  while (s[i] !== "]") {
    const { value, end } = parseStringLiteral(s, i);
    items.push(value);
    i = skipWs(s, end);
    if (s[i] === ",") {
      i = skipWs(s, i + 1);
    }
  }
  return { value: items, end: i + 1 };
}

function buildDetails(problem, gap, goals, method, outcomes) {
  return (
    "المشكلة:\n" +
    problem +
    "\n\nالفجوة البحثية (اتجاهات 2024–2026):\n" +
    gap +
    "\n\nالأهداف:\n" +
    goals +
    "\n\nالمنهج المقترح:\n" +
    method +
    "\n\nالمخرجات المتوقعة:\n" +
    outcomes
  );
}

const ideas = [];
const re = /\nadd\(/g;
let m;
while ((m = re.exec(py)) !== null) {
  let i = m.index + m[0].length;
  const args = [];
  for (let a = 0; a < 10; a++) {
    i = skipWs(py, i);
    if (py[i] === "[") {
      const { value, end } = parseList(py, i);
      args.push(value);
      i = skipWs(py, end);
    } else {
      const { value, end } = parseStringLiteral(py, i);
      args.push(value);
      i = skipWs(py, end);
    }
    if (py[i] === ",") i++;
    else if (py[i] === ")") break;
  }
  const [cat, title, provider, budget, tags, problem, gap, goals, method, outcomes] = args;
  ideas.push({
    category: cat,
    title,
    provider,
    budget,
    tags,
    details: buildDetails(problem, gap, goals, method, outcomes),
  });
}

if (ideas.length !== 90) {
  console.error("Expected 90 ideas, got", ideas.length);
  process.exit(1);
}

function esc(s) {
  return s.replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\n/g, "\\n");
}

const lines = [
  "/// حزمة 90 فكرة بحثية كاملة (5 لكل كلية) — اتجاهات 2024–2026.",
  "/// تُنشر عبر أداة المدير باسم المستخدم الحالي.",
  "",
  "class SeedResearchIdea {",
  "  final String category;",
  "  final String title;",
  "  final String provider;",
  "  final String details;",
  "  final String budget;",
  "  final List<String> tags;",
  "",
  "  const SeedResearchIdea({",
  "    required this.category,",
  "    required this.title,",
  "    required this.provider,",
  "    required this.details,",
  "    required this.budget,",
  "    required this.tags,",
  "  });",
  "}",
  "",
  "const List<SeedResearchIdea> egyptResearchIdeasSeed = [",
];

for (const idea of ideas) {
  const tagLit = idea.tags.map((t) => `"${esc(t)}"`).join(", ");
  lines.push("  SeedResearchIdea(");
  lines.push(`    category: "${esc(idea.category)}",`);
  lines.push(`    title: "${esc(idea.title)}",`);
  lines.push(`    provider: "${esc(idea.provider)}",`);
  lines.push(`    details: "${esc(idea.details)}",`);
  lines.push(`    budget: "${esc(idea.budget)}",`);
  lines.push(`    tags: [${tagLit}],`);
  lines.push("  ),");
}
lines.push("];");
lines.push("");

fs.mkdirSync(path.dirname(outPath), { recursive: true });
fs.writeFileSync(outPath, lines.join("\n"), "utf8");
console.log(`Wrote ${ideas.length} ideas -> ${outPath}`);
