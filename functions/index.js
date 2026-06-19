const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");

const geminiApiKey = defineSecret("GEMINI_API_KEY");

const MODELS = [
  "gemini-2.5-flash",
  "gemini-2.5-pro",
  "gemini-2.0-flash-lite",
  "gemini-flash-latest",
];

exports.geminiAdvisor = onCall(
  {
    secrets: [geminiApiKey],
    timeoutSeconds: 120,
    cors: true,
  },
  async (request) => {
    const { systemPrompt, userMessage, history = [], maxOutputTokens = 8192 } =
      request.data || {};

    if (!userMessage || typeof userMessage !== "string") {
      throw new HttpsError("invalid-argument", "userMessage مطلوب");
    }

    const apiKey = geminiApiKey.value();
    if (!apiKey) {
      throw new HttpsError(
        "failed-precondition",
        "GEMINI_API_KEY غير مضبوط في Firebase Functions",
      );
    }

    const contents = [];
    for (const item of history) {
      if (!item || !item.text) continue;
      contents.push({
        role: item.role === "assistant" ? "model" : "user",
        parts: [{ text: item.text }],
      });
    }
    contents.push({ role: "user", parts: [{ text: userMessage }] });

    let lastError = "unknown";
    for (const model of MODELS) {
      try {
        const url =
          `https://generativelanguage.googleapis.com/v1beta/models/${model}` +
          `:generateContent?key=${apiKey}`;

        const response = await fetch(url, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            system_instruction: {
              parts: [{ text: systemPrompt || "أنت مساعد أكاديمي." }],
            },
            contents,
            generationConfig: {
              temperature: 0.85,
              maxOutputTokens,
            },
          }),
        });

        if (!response.ok) {
          const errBody = await response.text();
          lastError = `${model}: ${response.status} ${errBody}`;
          continue;
        }

        const data = await response.json();
        const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
        if (text && text.trim()) {
          return { text: text.trim(), model };
        }
        lastError = `${model}: empty response`;
      } catch (err) {
        lastError = `${model}: ${err.message}`;
      }
    }

    return { error: lastError };
  },
);
