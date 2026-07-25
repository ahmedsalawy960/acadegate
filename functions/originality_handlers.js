function createOriginalityHandlers(deps) {
  const {
    onCall,
    onRequest,
    HttpsError,
    getAuth,
    getFirestore,
    FieldValue,
    copyleaksEmail,
    copyleaksApiKey,
    plagiarismCheckToken,
    copyleaksWebhookSecret,
    resolveProvider,
    runCopyleaksScan,
    runPlagiarismCheckScan,
    functionsServiceAccount,
    normalizePlagiarismCheckToken,
    requirePlagiarismCheckToken,
  } = deps;

  function httpsErrorToResponse(err) {
    if (err instanceof HttpsError) {
      return {
        status: err.code === "unauthenticated" ? 401 : 400,
        body: {
          error: {
            status: String(err.code || "unknown").toUpperCase(),
            message: err.message || err.code,
          },
        },
      };
    }
    return {
      status: 500,
      body: {
        error: {
          status: "INTERNAL",
          message: err?.message || "Internal error",
        },
      },
    };
  }

  async function verifyBearerHeader(headers) {
    const header =
      headers?.authorization ||
      headers?.Authorization ||
      "";
    if (!header.startsWith("Bearer ")) {
      return null;
    }

    const idToken = header.slice("Bearer ".length).trim();
    if (!idToken) return null;

    try {
      const decoded = await getAuth().verifyIdToken(idToken);
      return { uid: decoded.uid, token: decoded };
    } catch (err) {
      console.warn("verifyIdToken failed:", err.message);
      return null;
    }
  }

  async function executeOriginalityCheck(uid, data) {
    const {
      provider = "auto",
      text,
      base64,
      filename,
      language = "en",
    } = data || {};

    const hasCopyleaks = Boolean(
      copyleaksEmail.value()?.trim() && copyleaksApiKey.value()?.trim(),
    );
    const pcToken = normalizePlagiarismCheckToken(plagiarismCheckToken.value());
    const hasPlagiarismCheck = Boolean(pcToken);
    const chosen = resolveProvider(provider, hasCopyleaks, hasPlagiarismCheck);

    if (!chosen) {
      const wanted = String(provider || "auto").toLowerCase();
      if (wanted === "copyleaks") {
        throw new HttpsError(
          "failed-precondition",
          "Copyleaks credentials not configured in Firebase Functions",
        );
      }
      if (wanted === "plagiarismcheck" || wanted === "plagiarism_check") {
        throw new HttpsError(
          "failed-precondition",
          "PLAGIARISMCHECK_API_TOKEN invalid — set ASCII token from plagiarismcheck.org",
        );
      }
      throw new HttpsError(
        "failed-precondition",
        "Configure COPYLEAKS_EMAIL + COPYLEAKS_API_KEY or PLAGIARISMCHECK_API_TOKEN in Firebase Functions secrets",
      );
    }

    const hasText = typeof text === "string" && text.trim().length > 0;
    const hasFile = typeof base64 === "string" && base64.length > 0
      && typeof filename === "string" && filename.trim().length > 0;

    if (!hasText && !hasFile) {
      throw new HttpsError("invalid-argument", "Provide text or a file (base64 + filename)");
    }

    const MAX_FILE_BYTES = 24 * 1024 * 1024;
    if (hasFile) {
      const rawLen = Math.ceil((base64.length * 3) / 4);
      if (rawLen > MAX_FILE_BYTES) {
        throw new HttpsError(
          "invalid-argument",
          "File exceeds 24 MB upload limit",
        );
      }
    }

    const db = getFirestore();

    if (chosen === "copyleaks") {
      if (!hasCopyleaks) {
        throw new HttpsError(
          "failed-precondition",
          "Copyleaks credentials not configured",
        );
      }
      return runCopyleaksScan({
        db,
        uid,
        text: hasText ? text.trim() : null,
        base64: hasFile ? base64 : null,
        filename: hasFile ? filename.trim() : null,
        email: copyleaksEmail.value().trim(),
        apiKey: copyleaksApiKey.value().trim(),
        webhookSecret: copyleaksWebhookSecret.value(),
      });
    }

    return runPlagiarismCheckScan({
      text: hasText ? text.trim() : null,
      base64: hasFile ? base64 : null,
      filename: hasFile ? filename.trim() : null,
      token: requirePlagiarismCheckToken(plagiarismCheckToken.value()),
      language,
    });
  }

  const originalitySecrets = [
    copyleaksEmail,
    copyleaksApiKey,
    plagiarismCheckToken,
    copyleaksWebhookSecret,
  ];
  const originalityOptions = {
    secrets: originalitySecrets,
    timeoutSeconds: 300,
    memory: "512MiB",
    cors: true,
    invoker: "public",
    serviceAccount: functionsServiceAccount,
  };

  const originalityCheck = onCall(
    originalityOptions,
    async (request) => {
      if (request.auth?.uid) {
        return executeOriginalityCheck(request.auth.uid, request.data);
      }

      const auth = await verifyBearerHeader(request.rawRequest?.headers);
      if (!auth?.uid) {
        throw new HttpsError(
          "unauthenticated",
          "Sign in required for originality check",
        );
      }
      return executeOriginalityCheck(auth.uid, request.data);
    },
  );

  const originalityCheckHttp = onRequest(
    originalityOptions,
    async (req, res) => {
      res.set("Access-Control-Allow-Origin", "*");
      res.set("Access-Control-Allow-Headers", "Authorization, Content-Type");
      res.set("Access-Control-Allow-Methods", "POST, OPTIONS");

      if (req.method === "OPTIONS") {
        res.status(204).send("");
        return;
      }

      if (req.method !== "POST") {
        res.status(405).json({ error: { status: "INVALID_ARGUMENT", message: "POST only" } });
        return;
      }

      try {
        const auth = await verifyBearerHeader(req.headers);
        if (!auth?.uid) {
          res.status(401).json({
            error: {
              status: "UNAUTHENTICATED",
              message: "Sign in required for originality check",
            },
          });
          return;
        }

        const payload = req.body?.data ?? req.body ?? {};
        const result = await executeOriginalityCheck(auth.uid, payload);
        res.status(200).json({ result });
      } catch (err) {
        console.error("originalityCheckHttp error", err);
        const mapped = httpsErrorToResponse(err);
        res.status(mapped.status).json(mapped.body);
      }
    },
  );

  const copyleaksWebhook = onRequest(
    {
      cors: true,
      invoker: "public",
      serviceAccount: functionsServiceAccount,
      secrets: [copyleaksWebhookSecret],
    },
    async (req, res) => {
      if (req.method !== "POST") {
        res.status(405).send("Method not allowed");
        return;
      }

      const expected = String(copyleaksWebhookSecret.value() || "").trim();
      const provided = String(
        req.query.token ||
          req.get("x-acadegate-webhook-secret") ||
          "",
      ).trim();
      if (!expected || !provided || provided !== expected) {
        res.status(401).send("Unauthorized");
        return;
      }

      const scanId = req.query.scanId;
      if (!scanId || typeof scanId !== "string") {
        res.status(400).send("Missing scanId");
        return;
      }

      const event = req.query.event || req.query.status || "unknown";
      const db = getFirestore();

      try {
        const existing = await db.collection("originality_scans").doc(scanId).get();
        if (!existing.exists) {
          res.status(404).send("Unknown scanId");
          return;
        }

        await db.collection("originality_scans").doc(scanId).set(
          {
            event,
            status: event,
            payload: req.body || {},
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
        res.status(200).send("ok");
      } catch (err) {
        console.error("copyleaksWebhook error", err);
        res.status(500).send("error");
      }
    },
  );

  return { originalityCheck, originalityCheckHttp, copyleaksWebhook };
}

module.exports = { createOriginalityHandlers };
