const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { getStorage } = require("firebase-admin/storage");
const crypto = require("crypto");

const PARTWORK_BASE = "https://api.partwork.ai/v1";
const TYE_BASE = "https://tylellm.com";

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function buildPrompt({ prompt, fabricationBrief, name }) {
  const parts = [];
  if (name && String(name).trim()) {
    parts.push(`Part name: ${String(name).trim()}`);
  }
  if (prompt && String(prompt).trim()) {
    parts.push(String(prompt).trim());
  }
  if (fabricationBrief && typeof fabricationBrief === "object") {
    const f = fabricationBrief;
    const lines = [
      f.processHint && `Process: ${f.processHint}`,
      f.materialHint && `Material: ${f.materialHint}`,
      f.dimensionsSummary && `Dimensions: ${f.dimensionsSummary}`,
      f.tolerances && `Tolerances: ${f.tolerances}`,
      f.modificationNotes && `Notes: ${f.modificationNotes}`,
      f.supplierAskEn || f.supplierAskAr,
    ].filter(Boolean);
    if (lines.length) {
      parts.push("Manufacturing brief:\n" + lines.join("\n"));
    }
  }
  const text = parts.join("\n\n").trim();
  if (text.length < 8) {
    throw new HttpsError(
      "invalid-argument",
      "prompt أو موجز التصنيع مطلوب لتوليد CAD",
    );
  }
  // Keep prompts bounded for vendor APIs
  return text.length > 3500 ? `${text.slice(0, 3500)}…` : text;
}

async function uploadCadBuffer({
  uid,
  buffer,
  format,
  provider,
  baseName,
}) {
  const bucket = getStorage().bucket();
  const safe = String(baseName || "part")
    .replace(/[^\w.\-]+/g, "_")
    .slice(0, 60);
  const ext = format === "stl" ? "stl" : "step";
  const contentType =
    format === "stl" ? "model/stl" : "application/step";
  const token = crypto.randomUUID();
  const path = `uploads/${uid}/cad/${provider}_${Date.now()}_${safe}.${ext}`;
  const file = bucket.file(path);
  await file.save(Buffer.from(buffer), {
    resumable: false,
    metadata: {
      contentType,
      metadata: {
        firebaseStorageDownloadTokens: token,
        provider,
        format,
      },
    },
  });
  const url =
    `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/` +
    `${encodeURIComponent(path)}?alt=media&token=${token}`;
  return { url, storagePath: path, format, provider, contentType };
}

async function partworkGenerate({ apiKey, prompt, formats, uid, name }) {
  if (!apiKey) {
    return {
      assets: [],
      error: "PARTWORK_API_KEY غير مضبوط",
    };
  }

  const headers = {
    "X-API-Key": apiKey,
    "Content-Type": "application/json",
  };

  const genRes = await fetch(`${PARTWORK_BASE}/generate`, {
    method: "POST",
    headers,
    body: JSON.stringify({ prompt, conversation_id: null }),
  });
  const genBody = await genRes.json().catch(() => ({}));
  if (!genRes.ok) {
    return {
      assets: [],
      error:
        genBody.error ||
        genBody.message ||
        `PartWork generate failed (${genRes.status})`,
    };
  }

  const jobId = genBody.job_id;
  if (!jobId) {
    return { assets: [], error: "PartWork: missing job_id" };
  }

  let result = null;
  for (let i = 0; i < 60; i++) {
    await sleep(2000);
    const stRes = await fetch(`${PARTWORK_BASE}/job/${jobId}`, { headers });
    const st = await stRes.json().catch(() => ({}));
    if (st.status === "completed") {
      result = st.result || {};
      break;
    }
    if (st.status === "failed") {
      return {
        assets: [],
        error: st.error || "PartWork generation failed",
      };
    }
  }
  if (!result) {
    return { assets: [], error: "PartWork: generation timed out" };
  }

  const partId = result.part_id;
  const assets = [];
  const wanted = Array.isArray(formats) && formats.length
    ? formats.map((f) => String(f).toLowerCase())
    : ["step", "stl"];

  for (const format of wanted) {
    if (!["step", "stl", "3mf", "glb"].includes(format)) continue;
    try {
      let downloadUrl = null;
      if (format === "step" && result.step_key) {
        const dl = await fetch(`${PARTWORK_BASE}/download`, {
          method: "POST",
          headers,
          body: JSON.stringify({ s3_key: result.step_key }),
        });
        const dlBody = await dl.json().catch(() => ({}));
        downloadUrl = dlBody.download_url;
      }
      if (!downloadUrl && partId) {
        const ex = await fetch(`${PARTWORK_BASE}/export`, {
          method: "POST",
          headers,
          body: JSON.stringify({ part_id: partId, format }),
        });
        const exBody = await ex.json().catch(() => ({}));
        if (!ex.ok) {
          assets.push({
            provider: "partwork",
            format,
            error: exBody.error || `export ${format} failed`,
          });
          continue;
        }
        downloadUrl = exBody.download_url;
      }
      if (!downloadUrl && format !== "step" && result.model_url) {
        // fallback: keep preview mesh URL for non-STEP if export missing
        if (format === "glb" || format === "stl") {
          downloadUrl = result.model_url;
        }
      }
      if (!downloadUrl) {
        assets.push({
          provider: "partwork",
          format,
          error: "no download URL",
        });
        continue;
      }

      const fileRes = await fetch(downloadUrl);
      if (!fileRes.ok) {
        assets.push({
          provider: "partwork",
          format,
          error: `download failed (${fileRes.status})`,
        });
        continue;
      }
      const buf = Buffer.from(await fileRes.arrayBuffer());
      if (buf.length < 32) {
        assets.push({
          provider: "partwork",
          format,
          error: "empty file",
        });
        continue;
      }
      const uploaded = await uploadCadBuffer({
        uid,
        buffer: buf,
        format: format === "stl" ? "stl" : format === "step" ? "step" : format,
        provider: "partwork",
        baseName: name,
      });
      assets.push({
        ...uploaded,
        thumbnailUrl: result.thumbnail_url || null,
        partId: partId || null,
        jobId,
      });
    } catch (err) {
      assets.push({
        provider: "partwork",
        format,
        error: err.message || String(err),
      });
    }
  }

  return { assets, error: null, partId, jobId, thumbnailUrl: result.thumbnail_url };
}

async function tyeGenerate({
  apiKey,
  geminiKey,
  prompt,
  imageUrl,
  uid,
  name,
  model,
}) {
  if (!apiKey) {
    return {
      assets: [],
      error: "TYE_API_KEY غير مضبوط (مفتاح gx_ من tylellm.com)",
    };
  }

  const useImage = typeof imageUrl === "string" && imageUrl.trim().length > 8;
  const endpoint = useImage
    ? `${TYE_BASE}/cad/from-image`
    : `${TYE_BASE}/cad/from-text`;

  // Prefer Gemini BYOK for reliable recipes; fall back to server-hosted pro.
  const body = {
    name: String(name || "acadegate_part").slice(0, 80),
  };
  if (useImage) {
    body.image = imageUrl.trim();
    body.prompt = prompt;
  } else {
    body.prompt = prompt;
  }

  if (geminiKey) {
    body.model = model || "gm_31_pro";
    body.byok_key = geminiKey;
  } else {
    body.model = model || "pro";
  }

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 120000);
  let res;
  try {
    res = await fetch(endpoint, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
        Accept: "application/step, application/octet-stream, */*",
      },
      body: JSON.stringify(body),
      signal: controller.signal,
    });
  } catch (err) {
    clearTimeout(timer);
    return {
      assets: [],
      error: err.name === "AbortError"
        ? "ty\\e timed out"
        : `ty\\e request failed: ${err.message || err}`,
    };
  }
  clearTimeout(timer);

  if (!res.ok) {
    let detail = "";
    try {
      const j = await res.json();
      detail = j.detail || j.error || JSON.stringify(j);
    } catch (_) {
      detail = await res.text().catch(() => "");
    }
    return {
      assets: [],
      error: `ty\\e ${res.status}: ${String(detail).slice(0, 400)}`,
    };
  }

  const buf = Buffer.from(await res.arrayBuffer());
  if (buf.length < 64) {
    return { assets: [], error: "ty\\e returned empty STEP" };
  }

  const uploaded = await uploadCadBuffer({
    uid,
    buffer: buf,
    format: "step",
    provider: "tye",
    baseName: name,
  });

  return {
    assets: [
      {
        ...uploaded,
        faces: res.headers.get("x-tye-faces"),
        bodies: res.headers.get("x-tye-bodies"),
        buildMs: res.headers.get("x-tye-build-ms"),
        note: "ty\\e يُنتج STEP (B-rep). لملف STL استخدم PartWork.",
      },
    ],
    error: null,
  };
}

function createCadGenerateHandlers({
  partworkApiKey,
  tyeApiKey,
  geminiApiKey,
}) {
  const generateCadPart = onCall(
    {
      secrets: [partworkApiKey, tyeApiKey, geminiApiKey],
      timeoutSeconds: 300,
      memory: "1GiB",
      cors: true,
    },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError(
          "unauthenticated",
          "يجب تسجيل الدخول لتوليد ملفات CAD",
        );
      }

      const data = request.data || {};
      const provider = String(data.provider || "both").toLowerCase();
      const formats = Array.isArray(data.formats)
        ? data.formats
        : ["step", "stl"];
      const name = data.name || "acadegate_part";
      const imageUrl = data.imageUrl || data.diagramUrl || null;
      const model = data.tyeModel || null;

      let prompt;
      try {
        prompt = buildPrompt({
          prompt: data.prompt,
          fabricationBrief: data.fabricationBrief,
          name,
        });
      } catch (e) {
        throw e;
      }

      const uid = request.auth.uid;
      const pwKey = partworkApiKey?.value?.() || "";
      const tyeKey = tyeApiKey?.value?.() || "";
      const gemKey = geminiApiKey?.value?.() || "";

      const providers = [];
      if (provider === "both" || provider === "partwork") {
        providers.push("partwork");
      }
      if (provider === "both" || provider === "tye" || provider === "ty\\e") {
        providers.push("tye");
      }
      if (providers.length === 0) {
        throw new HttpsError(
          "invalid-argument",
          "provider يجب أن يكون partwork أو tye أو both",
        );
      }

      const assets = [];
      const errors = [];

      for (const p of providers) {
        if (p === "partwork") {
          const out = await partworkGenerate({
            apiKey: pwKey,
            prompt,
            formats,
            uid,
            name,
          });
          assets.push(...(out.assets || []));
          if (out.error) errors.push({ provider: "partwork", error: out.error });
        } else if (p === "tye") {
          const out = await tyeGenerate({
            apiKey: tyeKey,
            geminiKey: gemKey,
            prompt,
            imageUrl,
            uid,
            name,
            model,
          });
          assets.push(...(out.assets || []));
          if (out.error) errors.push({ provider: "tye", error: out.error });
        }
      }

      const okAssets = assets.filter((a) => a.url);
      if (okAssets.length === 0) {
        throw new HttpsError(
          "failed-precondition",
          errors.map((e) => `${e.provider}: ${e.error}`).join(" | ") ||
            "تعذر توليد ملفات CAD — تحقق من مفاتيح PartWork / ty\\e",
        );
      }

      return {
        assets: okAssets,
        errors,
        promptUsed: prompt.slice(0, 500),
      };
    },
  );

  return { generateCadPart };
}

module.exports = { createCadGenerateHandlers };
