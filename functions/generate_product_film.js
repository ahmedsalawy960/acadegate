const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { getStorage } = require("firebase-admin/storage");
const { GoogleAuth } = require("google-auth-library");
const crypto = require("crypto");

const PROJECT_ID = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT || "acadegate-new";
const LOCATION = "us-central1";
const GEMINI_BASE = "https://generativelanguage.googleapis.com/v1beta";
const VERTEX_BASE =
  `https://${LOCATION}-aiplatform.googleapis.com/v1/projects/${PROJECT_ID}` +
  `/locations/${LOCATION}/publishers/google/models`;

const VERTEX_MODELS = [
  "veo-3.1-fast-generate-001",
  "veo-3.1-generate-001",
  "veo-3.0-fast-generate-001",
  "veo-3.0-generate-001",
];

const GEMINI_MODELS = [
  "veo-3.1-fast-generate-preview",
  "veo-3.1-generate-preview",
  "veo-3.0-fast-generate-preview",
  "veo-3.0-generate-preview",
];

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function formatApiError(status, errBody) {
  const body = String(errBody || "");
  const lower = body.toLowerCase();
  if (status === 429 || lower.includes("resource_exhausted") || lower.includes("quota")) {
    return "حصة توليد الفيديو غير كافية. فعّل فوترة Vertex AI / Gemini ثم أعد المحاولة.";
  }
  if (lower.includes("api has not been used") || lower.includes("is disabled") || lower.includes("not been enabled")) {
    return "يلزم تفعيل Vertex AI API في مشروع Firebase (aiplatform.googleapis.com) ثم أعد المحاولة.";
  }
  try {
    const parsed = JSON.parse(body);
    const message = parsed?.error?.message;
    if (message) return String(message);
  } catch (_) {}
  return body.length > 240 ? `${body.slice(0, 240)}...` : body;
}

function isMissingModel(msg) {
  const t = String(msg || "").toLowerCase();
  return (
    t.includes("not found") ||
    t.includes("not supported") ||
    t.includes("is not available") ||
    t.includes("was not found")
  );
}

function isVertexApiDisabled(err) {
  const t = `${err?.message || ""} ${err?.body || ""}`.toLowerCase();
  return (
    t.includes("api has not been used") ||
    t.includes("is disabled") ||
    t.includes("not been enabled") ||
    t.includes("aiplatform.googleapis.com")
  );
}

async function waitForServiceUsageOp(token, operationName) {
  const deadline = Date.now() + 2 * 60 * 1000;
  while (Date.now() < deadline) {
    await sleep(4000);
    const res = await fetch(
      `https://serviceusage.googleapis.com/v1/${operationName}`,
      { headers: { Authorization: `Bearer ${token}` } },
    );
    const text = await res.text();
    if (!res.ok) throw new Error(formatApiError(res.status, text));
    const op = JSON.parse(text);
    if (op.done === true) {
      if (op.error) {
        throw new Error(op.error.message || JSON.stringify(op.error));
      }
      return;
    }
  }
  throw new Error("انتهت مهلة تفعيل Vertex AI API");
}

async function ensureVertexAiEnabled(token) {
  const service = `projects/${PROJECT_ID}/services/aiplatform.googleapis.com`;
  const getRes = await fetch(`https://serviceusage.googleapis.com/v1/${service}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  const getText = await getRes.text();
  if (getRes.ok) {
    try {
      const state = JSON.parse(getText)?.state;
      if (state === "ENABLED") return { already: true };
    } catch (_) {}
  }
  const enableRes = await fetch(
    `https://serviceusage.googleapis.com/v1/${service}:enable`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: "{}",
    },
  );
  const enableText = await enableRes.text();
  if (!enableRes.ok) {
    const err = new Error(formatApiError(enableRes.status, enableText));
    err.status = enableRes.status;
    err.body = enableText;
    throw err;
  }
  let opName = "";
  try {
    opName = JSON.parse(enableText)?.name || "";
  } catch (_) {}
  if (opName) {
    await waitForServiceUsageOp(token, opName);
  } else {
    await sleep(10000);
  }
  return { enabled: true };
}

const MAX_STEPS = 4;
const VERTEX_FAST_MODELS = VERTEX_MODELS.filter((m) => m.includes("fast"));
const GEMINI_FAST_MODELS = GEMINI_MODELS.filter((m) => m.includes("fast"));

const SETTINGS = {
  chemicals: {
    placeEn:
      "a university chemistry teaching laboratory with benches and, if relevant, a fume hood",
    attireEn: "white lab coat and blue nitrile gloves",
    chemOk: true,
  },
  biology: {
    placeEn:
      "a university biology / biotechnology teaching lab with a clean bench or biosafety cabinet",
    attireEn: "white lab coat and nitrile gloves",
    chemOk: true,
  },
  medical: {
    placeEn:
      "a clinical skills room or hospital pharmacy compounding bench — never a chemistry lab",
    attireEn: "clinical scrubs or a white medical coat",
    chemOk: false,
  },
  engineering: {
    placeEn:
      "an electronics / engineering workshop with an ESD mat, tools, and a workbench — never a chemistry laboratory",
    attireEn: "workshop clothing and safety glasses when using tools",
    chemOk: false,
  },
  physics_materials: {
    placeEn:
      "a university physics or materials teaching room with instruments or sample benches — not a wet chemistry lab",
    attireEn: "academic workshop attire; safety glasses if instruments are used",
    chemOk: false,
  },
  agriculture: {
    placeEn:
      "a greenhouse, farm workshop, or veterinary treatment room matching the product",
    attireEn: "field coat, coveralls, or veterinary clinic attire",
    chemOk: false,
  },
  computing: {
    placeEn:
      "a university computer laboratory or researcher desk with monitors — never a chemistry lab",
    attireEn: "ordinary academic clothing",
    chemOk: false,
  },
  knowledge_assets: {
    placeEn: "a quiet researcher desk with a laptop",
    attireEn: "ordinary academic clothing",
    chemOk: false,
  },
  consumables: {
    placeEn:
      "a general teaching prep room that matches this consumable — do not assume a chemistry lab",
    attireEn: "PPE appropriate to the product only",
    chemOk: false,
  },
  instruments: {
    placeEn: "an instrument / metrology room or engineering measurement bench",
    attireEn: "academic workshop attire",
    chemOk: false,
  },
  safety: {
    placeEn: "a workplace safety training area or practical workshop",
    attireEn: "the protective equipment being demonstrated",
    chemOk: false,
  },
  field: {
    placeEn:
      "an outdoor academic field site (survey, archaeology, or environmental sampling)",
    attireEn: "field clothing; high-visibility vest if outdoors",
    chemOk: false,
  },
  books: {
    placeEn: "a university library reading table or study carrel",
    attireEn: "ordinary academic clothing",
    chemOk: false,
  },
  humanities: {
    placeEn: "a seminar room or quiet study",
    attireEn: "ordinary academic clothing",
    chemOk: false,
  },
  office: {
    placeEn: "an academic office with a writing desk and documents",
    attireEn: "ordinary academic clothing",
    chemOk: false,
  },
  general: {
    placeEn:
      "a realistic academic workspace that matches how THIS specific product is actually used (desk, workshop, clinic, studio, or field). Do not default to a chemistry laboratory",
    attireEn: "clothing appropriate to that workspace",
    chemOk: false,
  },
};

const CATEGORY_TITLES = [
  ["مستلزمات ومواد كيميائية", "chemicals"],
  ["كيميائيات", "chemicals"],
  ["بيولوجيا", "biology"],
  ["طبي وصيدلي", "medical"],
  ["متجر طبي", "medical"],
  ["هندسة وإلكترونيات", "engineering"],
  ["متجر هندسي", "engineering"],
  ["فيزياء ومواد", "physics_materials"],
  ["زراعة وبيطري", "agriculture"],
  ["متجر زراعي", "agriculture"],
  ["حوسبة", "computing"],
  ["أصول معرفية", "knowledge_assets"],
  ["مستهلكات", "consumables"],
  ["أجهزة وأدوات قياس", "instruments"],
  ["سلامة", "safety"],
  ["أدوات ميدانية", "field"],
  ["كتب ومراجع", "books"],
  ["إنسانيات", "humanities"],
  ["مستلزمات كتابة", "office"],
  ["مكتبي", "office"],
  ["مستلزمات عامة", "general"],
  ["متجر عام", "general"],
];

function settingIdFromCategoryField(category) {
  const cat = String(category || "").trim();
  if (!cat) return "";
  const lower = cat.toLowerCase();
  if (SETTINGS[lower]) return lower;
  for (const [needle, id] of CATEGORY_TITLES) {
    if (cat.includes(needle)) return id;
  }
  return "";
}

function settingIdFromProductText(productName, description) {
  const blob = `${productName || ""} ${description || ""}`;
  const tests = [
    ["chemicals", /كيميائ|كواشف|reagent|solvent|\bacid\b|حمض|ملح ك/i],
    ["biology", /بيولوجيا|تقنية حيوي|biotech|\bpcr\b|\bdna\b/i],
    ["engineering", /هندسة|إلكترون|الكترون|arduino|pcb|soldering|لحام|microcontroller|raspberry/i],
    ["medical", /طبي|صيدلي|سريري|clinical|syringe|محقن|ضماد|stethoscope/i],
    ["agriculture", /زراع|بيطري|greenhouse|تربة|بذور|\bري\b|irrigation|\bvet\b/i],
    ["computing", /حوسبة|برمج|software|laptop|حاسوب|python|matlab/i],
    ["field", /ميدان|مسح|survey|\bgps\b|آثار|archaeolog/i],
    ["books", /كتب|مراجع|textbook|journal|موسوعة/i],
    ["humanities", /إنسانيات|تربية|اجتماع|questionnaire/i],
    ["office", /مكتبي|قرطاس|ملف|binder|notebook/i],
    ["instruments", /قياس|multimeter|oscilloscope|مجهر|microscope/i],
    ["safety", /سلامة|وقاية|\bppe\b|helmet|خوذة/i],
    ["physics_materials", /فيزياء|مواد|optics|ليزر|laser/i],
  ];
  for (const [id, re] of tests) {
    if (re.test(blob)) return id;
  }
  return "general";
}

function resolveSetting(category, productName, description) {
  const fromCat = settingIdFromCategoryField(category);
  if (fromCat && fromCat !== "general") {
    return { id: fromCat, ...(SETTINGS[fromCat] || SETTINGS.general) };
  }
  const inferred = settingIdFromProductText(productName, description);
  const id = inferred || fromCat || "general";
  return { id, ...(SETTINGS[id] || SETTINGS.general) };
}

function buildScenes({ productName, steps }) {
  const list = Array.isArray(steps) ? steps : [];
  const usable = list
    .map((s, index) => ({
      index,
      titleAr: String(s.titleAr || s.titleEn || "").trim(),
      titleEn: String(s.titleEn || s.titleAr || "").trim(),
      bodyAr: String(s.bodyAr || s.bodyEn || "").trim(),
      bodyEn: String(s.bodyEn || s.bodyAr || "").trim(),
    }))
    .filter((s) => s.titleAr || s.bodyAr)
    .slice(0, MAX_STEPS);
  if (usable.length > 0) return usable;
  return [
    {
      index: 0,
      titleAr: `التعرف على ${productName}`,
      titleEn: `Identify ${productName}`,
      bodyAr: "يفحص المستخدم المنتج ويطابق شكله قبل الاستخدام.",
      bodyEn: "The user inspects the product and matches its appearance before use.",
    },
    {
      index: 1,
      titleAr: "الاستخدام الآمن",
      titleEn: "Safe use",
      bodyAr: "ينفّذ خطوة الاستخدام ببطء ووضوح في المكان المناسب لتخصص المنتج.",
      bodyEn: "Performs the usage step slowly in a setting that matches the product specialty.",
    },
  ];
}

function clipPrompt({ productName, description, scene, sceneCount, setting }) {
  const action = [scene.titleEn || scene.titleAr, scene.bodyEn || scene.bodyAr]
    .filter(Boolean)
    .join(". ");
  const partHint =
    "Show the full step as one slow, clear physical action a student can copy. Hold the product in frame. Unhurried.";
  const noChem = setting.chemOk
    ? ""
    : `STRICT SETTING RULE: Do NOT show a chemistry laboratory, fume hood, reagent shelves, conical flasks, or chemical bottles unless they ARE this product. The location must be: ${setting.placeEn}.`;
  return `Photoreal academic instructional demonstration, 16:9, 8 seconds, 24fps.
Natural lighting. Calm instructional documentary. NOT a movie trailer. NO lens flares. NO cinematic color grading.

SETTING (mandatory): ${setting.placeEn}.
ATTIRE: ${setting.attireEn}.
${noChem}

This is written step ${scene.index + 1} of ${sceneCount} of the usage guide for "${productName}".
${partHint}
${description ? `Product notes: ${description}` : ""}

THE ACTION TO SHOW:
${action}

PRODUCT APPEARANCE:
- Match the reference photo for SHAPE, SIZE, MATERIAL, and COLOR only.
- Any container MUST be completely BLANK: no printed label, no letters, no Arabic, no English, no digits, no barcodes, no logos, no fake writing.
- Instrument screens are dark or blank.

FORBIDDEN:
- Any on-screen captions, titles, subtitles, watermarks, logos, UI, infographics
- Gibberish or invented writing on bottles, boxes, or machines
- Collage, split screen, storyboard, PowerPoint
- Dramatic cinema lighting or hero-product commercials`;
}

async function fetchImageAsBase64(url) {
  const u = String(url || "").trim();
  if (!u || !/^https?:\/\//i.test(u)) return null;
  if (/youtube\.com|youtu\.be|vimeo\.com|search_query=/i.test(u)) return null;
  try {
    const res = await fetch(u, { redirect: "follow" });
    if (!res.ok) return null;
    const mime = (res.headers.get("content-type") || "image/jpeg")
      .split(";")[0]
      .trim();
    if (!mime.startsWith("image/")) return null;
    const buf = Buffer.from(await res.arrayBuffer());
    if (buf.length < 80 || buf.length > 4 * 1024 * 1024) return null;
    return { mimeType: mime, data: buf.toString("base64") };
  } catch (_) {
    return null;
  }
}

function veoInstance(prompt, image) {
  const instance = { prompt };
  if (image) {
    instance.image = {
      bytesBase64Encoded: image.data,
      mimeType: image.mimeType,
    };
  }
  return instance;
}

function extractVideoAsset(operation) {
  const resp = operation?.response || {};
  const gvr = resp.generateVideoResponse || resp;
  const samples =
    gvr.generatedSamples ||
    gvr.generatedVideos ||
    resp.generatedVideos ||
    resp.videos ||
    [];
  if (!Array.isArray(samples) || samples.length === 0) {
    if (gvr.raiMediaFilteredReasons || gvr.raiMediaFilteredCount) {
      return { error: "تم حجب الفيديو بواسطة فلاتر الأمان. جرّب وصفاً أبسط للمنتج." };
    }
    return null;
  }
  const sample = samples[0];
  const video = sample?.video || sample;
  if (!video) return null;
  if (video.bytesBase64Encoded) {
    return { bytes: Buffer.from(String(video.bytesBase64Encoded), "base64") };
  }
  if (video.uri) return { uri: String(video.uri) };
  if (video.gcsUri) return { uri: String(video.gcsUri) };
  if (typeof video === "string") return { uri: video };
  return null;
}

async function getAccessToken() {
  const auth = new GoogleAuth({
    scopes: ["https://www.googleapis.com/auth/cloud-platform"],
  });
  const client = await auth.getClient();
  const token = await client.getAccessToken();
  const value = typeof token === "string" ? token : token?.token;
  if (!value) throw new Error("تعذر الحصول على رمز Vertex AI");
  return value;
}

async function startVertex({ token, model, prompt, image }) {
  const url = `${VERTEX_BASE}/${model}:predictLongRunning`;
  const response = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      instances: [veoInstance(prompt, image)],
      parameters: {
        aspectRatio: "16:9",
        durationSeconds: 8,
        sampleCount: 1,
        personGeneration: "allow_adult",
      },
    }),
  });
  const bodyText = await response.text();
  if (!response.ok) {
    const err = new Error(formatApiError(response.status, bodyText));
    err.status = response.status;
    err.body = bodyText;
    throw err;
  }
  const data = JSON.parse(bodyText);
  if (!data.name) throw new Error("Vertex لم يُرجع معرّف العملية");
  return data.name;
}

async function pollVertex({ token, model, operationName }) {
  const deadline = Date.now() + 3.5 * 60 * 1000;
  while (Date.now() < deadline) {
    await sleep(6000);
    const res = await fetch(`${VERTEX_BASE}/${model}:fetchPredictOperation`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ operationName }),
    });
    const text = await res.text();
    if (!res.ok) throw new Error(formatApiError(res.status, text));
    const op = JSON.parse(text);
    if (op.error) throw new Error(op.error.message || JSON.stringify(op.error));
    if (op.done === true) {
      const asset = extractVideoAsset(op);
      if (asset?.error) throw new Error(asset.error);
      if (!asset) throw new Error("اكتملت العملية بدون ملف فيديو");
      return asset;
    }
  }
  throw new Error("انتهت مهلة توليد الفيديو. أعد المحاولة.");
}

async function startGemini({ apiKey, model, prompt, image }) {
  const url = `${GEMINI_BASE}/models/${model}:predictLongRunning?key=${apiKey}`;
  const response = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      instances: [veoInstance(prompt, image)],
      parameters: {
        aspectRatio: "16:9",
        durationSeconds: 8,
        sampleCount: 1,
        personGeneration: "allow_adult",
      },
    }),
  });
  const bodyText = await response.text();
  if (!response.ok) {
    const err = new Error(formatApiError(response.status, bodyText));
    err.status = response.status;
    err.body = bodyText;
    throw err;
  }
  const data = JSON.parse(bodyText);
  if (!data.name) throw new Error("Veo لم يُرجع معرّف العملية");
  return data.name;
}

async function pollGemini({ apiKey, operationName }) {
  const deadline = Date.now() + 3.5 * 60 * 1000;
  while (Date.now() < deadline) {
    await sleep(6000);
    const res = await fetch(`${GEMINI_BASE}/${operationName}?key=${apiKey}`);
    const text = await res.text();
    if (!res.ok) throw new Error(formatApiError(res.status, text));
    const op = JSON.parse(text);
    if (op.error) throw new Error(op.error.message || JSON.stringify(op.error));
    if (op.done === true) {
      const asset = extractVideoAsset(op);
      if (asset?.error) throw new Error(asset.error);
      if (!asset) throw new Error("اكتملت العملية بدون ملف فيديو");
      return asset;
    }
  }
  throw new Error("انتهت مهلة توليد الفيديو. أعد المحاولة.");
}

async function downloadVideoBytes(headers, asset) {
  if (asset.bytes) return asset.bytes;
  const uri = String(asset.uri || "");
  if (uri.startsWith("gs://")) {
    const without = uri.replace(/^gs:\/\//, "");
    const slash = without.indexOf("/");
    const bucketName = without.slice(0, slash);
    const path = without.slice(slash + 1);
    const [buf] = await getStorage().bucket(bucketName).file(path).download();
    return buf;
  }
  const res = await fetch(uri, { headers, redirect: "follow" });
  if (!res.ok) {
    throw new Error(formatApiError(res.status, await res.text()));
  }
  return Buffer.from(await res.arrayBuffer());
}

async function uploadFilm({ uid, productId, bytes }) {
  const bucket = getStorage().bucket();
  const token = crypto.randomUUID();
  const path = `uploads/${uid}/products/guide/${productId}_film_${Date.now()}.mp4`;
  const file = bucket.file(path);
  await file.save(bytes, {
    resumable: false,
    metadata: {
      contentType: "video/mp4",
      metadata: { firebaseStorageDownloadTokens: token },
    },
  });
  const encoded = encodeURIComponent(path);
  return `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encoded}?alt=media&token=${token}`;
}

function createGenerateProductFilmHandler(geminiApiKey) {
  const generateProductFilm = onCall(
    {
      secrets: [geminiApiKey],
      timeoutSeconds: 540,
      memory: "1GiB",
      cors: true,
    },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError(
          "unauthenticated",
          "يجب تسجيل الدخول لتوليد فيديو المنتج",
        );
      }
      const {
        productId,
        productName,
        description = "",
        category = "",
        steps = [],
        imageUrl,
      } = request.data || {};
      if (!productName || !String(productName).trim()) {
        throw new HttpsError("invalid-argument", "اسم المنتج مطلوب");
      }
      const id = String(productId || "product").replace(/[^\w.-]/g, "_");
      const name = String(productName).trim();
      const desc = String(description || "").trim();
      const scenes = buildScenes({
        productName: name,
        steps: Array.isArray(steps) ? steps : [],
      });
      const setting = resolveSetting(category, name, desc);
      const image = await fetchImageAsBase64(imageUrl);
      const errors = [];
      const clips = [];
      let vertexToken = null;
      let workingModel = null;
      const apiKey = geminiApiKey.value();

      try {
        vertexToken = await getAccessToken();
        try {
          await ensureVertexAiEnabled(vertexToken);
        } catch (err) {
          errors.push(`vertex-enable: ${err.message || err}`);
        }
      } catch (err) {
        errors.push(`vertex: ${err.message || err}`);
      }

      async function vertexBytes(model, prompt) {
        const operationName = await startVertex({
          token: vertexToken,
          model,
          prompt,
          image,
        });
        const asset = await pollVertex({
          token: vertexToken,
          model,
          operationName,
        });
        const bytes = await downloadVideoBytes(
          { Authorization: `Bearer ${vertexToken}` },
          asset,
        );
        if (!bytes || bytes.length < 1000) {
          throw new Error("ملف فارغ");
        }
        return bytes;
      }

      async function geminiBytes(model, prompt) {
        const operationName = await startGemini({
          apiKey,
          model,
          prompt,
          image,
        });
        const asset = await pollGemini({ apiKey, operationName });
        const bytes = await downloadVideoBytes(
          { "x-goog-api-key": apiKey },
          asset,
        );
        if (!bytes || bytes.length < 1000) {
          throw new Error("ملف فارغ");
        }
        return bytes;
      }

      async function tryModels(prompt, models, kind) {
        for (const model of models) {
          try {
            const bytes =
              kind === "vertex"
                ? await vertexBytes(model, prompt)
                : await geminiBytes(model, prompt);
            workingModel = `${kind}/${model}`;
            return bytes;
          } catch (err) {
            errors.push(`${kind}/${model}: ${err.message || err}`);
            if (err.status === 429) break;
            if (kind === "vertex" && isVertexApiDisabled(err)) break;
          }
        }
        return null;
      }

      async function bytesForPrompt(prompt, { locked = false } = {}) {
        if (workingModel?.startsWith("vertex/") && vertexToken) {
          try {
            return await vertexBytes(workingModel.slice(7), prompt);
          } catch (err) {
            errors.push(`${workingModel}: ${err.message || err}`);
            if (locked) throw err;
            workingModel = null;
          }
        }
        if (workingModel?.startsWith("gemini/") && apiKey) {
          try {
            return await geminiBytes(workingModel.slice(7), prompt);
          } catch (err) {
            errors.push(`${workingModel}: ${err.message || err}`);
            if (locked) throw err;
            workingModel = null;
          }
        }
        if (locked) return null;
        if (vertexToken) {
          const bytes =
            (await tryModels(prompt, VERTEX_FAST_MODELS, "vertex")) ||
            (await tryModels(prompt, VERTEX_MODELS.filter((m) => !m.includes("fast")), "vertex"));
          if (bytes) return bytes;
        }
        if (apiKey) {
          const bytes =
            (await tryModels(prompt, GEMINI_FAST_MODELS, "gemini")) ||
            (await tryModels(prompt, GEMINI_MODELS.filter((m) => !m.includes("fast")), "gemini"));
          if (bytes) return bytes;
        }
        return null;
      }

      async function clipForScene(scene, { locked = false } = {}) {
        const prompt = clipPrompt({
          productName: name,
          description: desc,
          scene,
          sceneCount: scenes.length,
          setting,
        });
        const bytes = await bytesForPrompt(prompt, { locked });
        if (!bytes) return null;
        const videoUrl = await uploadFilm({
          uid: request.auth.uid,
          productId: `${id}_s${scene.index + 1}`,
          bytes,
        });
        return {
          url: videoUrl,
          stepIndex: scene.index,
          titleAr: scene.titleAr,
          titleEn: scene.titleEn,
        };
      }

      const [firstScene, ...otherScenes] = scenes;
      if (firstScene) {
        try {
          const first = await clipForScene(firstScene, { locked: false });
          if (first) clips.push(first);
        } catch (err) {
          errors.push(`clip1: ${err.message || err}`);
        }
      }
      if (otherScenes.length > 0) {
        const rest = await Promise.all(
          otherScenes.map(async (scene) => {
            try {
              return await clipForScene(scene, { locked: Boolean(workingModel) });
            } catch (err) {
              errors.push(`clip${scene.index + 1}: ${err.message || err}`);
              return null;
            }
          }),
        );
        for (const clip of rest) {
          if (clip) clips.push(clip);
        }
        clips.sort((a, b) => a.stepIndex - b.stepIndex);
      }

      if (clips.length === 0) {
        const useful =
          errors.find((e) => !isMissingModel(e)) ||
          errors[0] ||
          "تعذر توليد فيديو دليل الاستخدام";
        throw new HttpsError("unavailable", useful);
      }
      return {
        videoUrl: clips[0].url,
        clips,
        setting: setting.id,
        model: workingModel || "unknown",
      };
    },
  );

  return { generateProductFilm };
}

module.exports = { createGenerateProductFilmHandler };
