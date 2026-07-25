const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");

/**
 * Weekly / on-demand sync of Egyptian WooCommerce lab catalogs into
 * `store_suppliers` + `product` (directory listings with contacts).
 */

const SUPPLIERS = [
  {
    id: "piochem",
    nameAr: "بايوكيم — Piochem",
    nameEn: "Piochem",
    website: "https://piochem.com/",
    email: "info@piochem.com",
    phone: "+201205700001",
    whatsapp: "",
    city: "6 أكتوبر / الجيزة",
    woo: "https://piochem.com",
    defaultCategory: "كيميائيات وكواشف",
  },
  {
    id: "cornell_lab",
    nameAr: "كورنيل لاب — Cornell Lab",
    nameEn: "Cornell Lab",
    website: "https://cornelllab.com/",
    email: "info@cornelllab.com",
    phone: "+201001431106",
    whatsapp: "",
    city: "المعادي / القاهرة",
    woo: "https://cornelllab.com",
    defaultCategory: "كيميائيات وكواشف",
  },
  {
    id: "labtronic",
    nameAr: "لابترونيك — LABTRONIC",
    nameEn: "LABTRONIC",
    website: "https://labtronic-eg.com/",
    email: "info@labtronic-eg.com",
    phone: "+201090548848",
    whatsapp: "01094557032",
    city: "مصر",
    woo: "https://labtronic-eg.com",
    defaultCategory: "طبي وصيدلي وسريري",
  },
  {
    id: "omega_lab_equip",
    nameAr: "أوميجا للتجهيزات المعملية",
    nameEn: "Omega Laboratory Equipment",
    website: "https://ome-ga.com/",
    email: "",
    phone: "01095069944",
    whatsapp: "01095069944",
    city: "مصر",
    woo: "https://ome-ga.com",
    defaultCategory: "أجهزة وأدوات قياس",
  },
  {
    id: "lab_supply_group",
    nameAr: "لاب سابلاي جروب",
    nameEn: "Lab Supply Group",
    website: "https://lab-supply.net/",
    email: "sales@lab-supply.net",
    phone: "+201050227430",
    whatsapp: "+201018768333",
    city: "مصر",
    woo: "https://lab-supply.net",
    defaultCategory: "مستهلكات وأدوات مختبر",
  },
  {
    id: "makers_electronics",
    nameAr: "ميكرز إلكترونكس — Makers",
    nameEn: "Makers Electronics",
    website: "https://makerselectronics.com/",
    email: "info@makerselectronics.com",
    phone: "+20248813824",
    whatsapp: "01211981188",
    city: "الإسكندرية",
    woo: "https://makerselectronics.com",
    defaultCategory: "هندسة وإلكترونيات",
  },
  {
    id: "am_electronics",
    nameAr: "إيه إم إلكترونكس — AM Electronics",
    nameEn: "AM Electronics",
    website: "https://am-electronics.com/",
    email: "",
    phone: "",
    whatsapp: "",
    city: "مصر",
    woo: "https://am-electronics.com",
    defaultCategory: "هندسة وإلكترونيات",
  },
  {
    id: "ekostra",
    nameAr: "إيكوسترا إلكترونكس",
    nameEn: "Ekostra Electronics",
    website: "https://ekostra.com/",
    email: "",
    phone: "",
    whatsapp: "",
    city: "التجمع الأول / القاهرة",
    woo: "https://ekostra.com",
    defaultCategory: "هندسة وإلكترونيات",
  },
];

const CONTACT_ONLY = [
  {
    id: "trust_scientific",
    nameAr: "تراست ساينتيفيك — Trust Scientific",
    nameEn: "Trust Scientific",
    website: "https://trust-scientific.com/",
    email: "info@trust-scientific.com",
    phone: "",
    whatsapp: "",
    city: "فيصل / الجيزة",
    defaultCategory: "كيميائيات وكواشف",
  },
  {
    id: "lct_chemicals",
    nameAr: "الكيماويات المعملية — LCT",
    nameEn: "Lab Chemicals Trading Co.",
    website: "http://www.lct-chemicals.com/",
    email: "",
    phone: "+20227923295",
    whatsapp: "",
    city: "جاردن سيتي / القاهرة",
    defaultCategory: "كيميائيات وكواشف",
  },
  {
    id: "igtechnology",
    nameAr: "آي جي تكنولوجي — IGTechnology",
    nameEn: "IGTechnology",
    website: "https://www.igtechnologyeg.com/",
    email: "",
    phone: "",
    whatsapp: "",
    city: "مصر",
    defaultCategory: "بيولوجيا وتقنية حيوية",
  },
  {
    id: "lab_egypt",
    nameAr: "لاب إيجيبت — Lab Egypt",
    nameEn: "Lab Egypt",
    website: "https://labegypt.com/",
    email: "",
    phone: "",
    whatsapp: "",
    city: "مصر",
    defaultCategory: "أجهزة وأدوات قياس",
  },
  {
    id: "lab_supply_egypt",
    nameAr: "لاب سابلاي إيجيبت",
    nameEn: "Lab Supply Egypt",
    website: "https://labsupplyegypt.com/",
    email: "",
    phone: "",
    whatsapp: "",
    city: "مصر",
    defaultCategory: "مستهلكات وأدوات مختبر",
  },
  {
    id: "delta_medical",
    nameAr: "دلتا ميديكال",
    nameEn: "Delta Medical",
    website: "https://deltamedicalco.com/",
    email: "",
    phone: "",
    whatsapp: "",
    city: "مصر",
    defaultCategory: "طبي وصيدلي وسريري",
  },
  {
    id: "arkan_scientech",
    nameAr: "أركان ساينتك — Arkan Scientech",
    nameEn: "Arkan Scientech",
    website: "https://arkanscientech.com/",
    email: "",
    phone: "",
    whatsapp: "",
    city: "مصر",
    defaultCategory: "طبي وصيدلي وسريري",
  },
  {
    id: "biolab_pharma",
    nameAr: "بيولاب فارما إيجي",
    nameEn: "Biolab Pharma Egy",
    website: "https://biolabpharma-egy.com/",
    email: "",
    phone: "",
    whatsapp: "",
    city: "مصر",
    defaultCategory: "زراعة وبيطري",
  },
  {
    id: "nile_chem",
    nameAr: "النيل للكيماويات",
    nameEn: "Nile Chem",
    website: "https://nilegroupe.com/ar/nile-chem/",
    email: "",
    phone: "",
    whatsapp: "",
    city: "مصر",
    defaultCategory: "كيميائيات وكواشف",
  },
];

function displayContact(s) {
  return [s.phone, s.whatsapp && s.whatsapp !== s.phone ? `واتساب: ${s.whatsapp}` : "", s.email, s.website]
    .filter(Boolean)
    .join(" · ");
}

function stripHtml(raw) {
  return String(raw || "")
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&quot;/g, '"')
    .replace(/\s+/g, " ")
    .trim();
}

function mapCategory(name, categories, fallback) {
  const cats = (categories || []).join(" ").toLowerCase();
  const hay = `${cats} ${String(name || "").toLowerCase()}`;
  if (/veterinary|canine|feline|poultry|livestock|بيطر|دواجن|أعلاف|feed additive/.test(hay)) {
    return "زراعة وبيطري";
  }
  if (/elisa kit|pcr|qpcr|cell culture|agarose|molecular biology|بيولوجيا|تقنية حيوية/.test(hay)) {
    return "بيولوجيا وتقنية حيوية";
  }
  if (/hematology|cbc|clinical chemistry|coagulation|human devices|rapid test|طبي|صيدل/.test(hay) && !/veterinary/.test(hay)) {
    return "طبي وصيدلي وسريري";
  }
  if (/glassware|volumetric flask|beaker|pipette tip|centrifuge tube|plasticware|زجاج|مستهلك/.test(hay)) {
    return "مستهلكات وأدوات مختبر";
  }
  if (/solvent|hplc|reagent|chemical|مذيب|كاشف|كيمي|fisher chemical|thermo scientific/.test(hay)) {
    return "كيميائيات وكواشف";
  }
  if (/safety|ppe|glove|سلام|قفاز/.test(hay)) return "سلامة ومعدات وقاية";
  if (/survey|gps|theodolite|مسح|ميدان/.test(hay)) return "أدوات ميدانية ومسح";
  if (/plc|oscilloscope|multimeter|arduino|هندس|إلكترون/.test(hay)) return "هندسة وإلكترونيات";
  if (/analyzer|centrifuge|spectrophotometer|microscope|ph meter|جهاز|قياس|devices|instrument/.test(hay)) {
    return "أجهزة وأدوات قياس";
  }
  if (/book|textbook|كتاب|مرجع/.test(hay)) return "كتب ومراجع علمية";
  return fallback || "مستلزمات عامة";
}

async function fetchWooProducts(baseUrl) {
  const root = String(baseUrl).replace(/\/+$/, "");
  const products = [];
  let page = 1;
  let totalPages = 1;
  while (page <= totalPages) {
    const url = `${root}/wp-json/wc/store/v1/products?per_page=100&page=${page}`;
    const res = await fetch(url, {
      headers: {
        "User-Agent": "AcadeGate/1.0 (store sync; +https://acadegate.app)",
        Accept: "application/json",
      },
    });
    if (!res.ok) {
      throw new Error(`WooCommerce HTTP ${res.status} for ${url}`);
    }
    totalPages = Number(res.headers.get("x-wp-totalpages") || totalPages) || 1;
    const rows = await res.json();
    if (!Array.isArray(rows)) break;
    for (const row of rows) {
      const prices = row.prices || {};
      const minor = Number(prices.currency_minor_unit ?? 2);
      const raw = Number(prices.price || 0);
      const price = raw / Math.pow(10, minor);
      const cats = Array.isArray(row.categories)
        ? row.categories.map((c) => c.name).filter(Boolean)
        : [];
      const image =
        Array.isArray(row.images) && row.images[0] ? row.images[0].src || "" : "";
      products.push({
        id: row.id,
        name: stripHtml(row.name || ""),
        permalink: row.permalink || "",
        description: stripHtml(row.short_description || row.description || ""),
        sku: row.sku || "",
        price,
        currency: prices.currency_code || "EGP",
        imageUrl: image,
        categories: cats,
        inStock: row.is_in_stock !== false,
      });
    }
    page += 1;
  }
  return products;
}

async function upsertSuppliers(db, list, productSyncEnabled) {
  const batch = db.batch();
  for (const s of list) {
    const ref = db.collection("store_suppliers").doc(s.id);
    batch.set(
      ref,
      {
        id: s.id,
        nameAr: s.nameAr,
        nameEn: s.nameEn,
        name: s.nameAr,
        website: s.website,
        email: s.email || "",
        phone: s.phone || "",
        whatsapp: s.whatsapp || "",
        city: s.city || "",
        contact: displayContact(s),
        defaultCategoryTitle: s.defaultCategory,
        productSyncEnabled: !!productSyncEnabled,
        ...(s.woo ? { wooCommerceBaseUrl: s.woo } : {}),
        importSource: "egypt_suppliers_catalog_2026",
        isVerifiedSeller: true,
        updatedAt: FieldValue.serverTimestamp(),
        syncedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  }
  await batch.commit();
}

async function upsertProducts(db, supplier, products, adminUid) {
  let imported = 0;
  let updated = 0;
  const chunk = 400;
  for (let i = 0; i < products.length; i += chunk) {
    const slice = products.slice(i, i + chunk);
    const refs = slice.map((p) =>
      db.collection("product").doc(`wc_${supplier.id}_${p.id}`),
    );
    const snaps = await db.getAll(...refs);
    const batch = db.batch();
    slice.forEach((p, idx) => {
      const snap = snaps[idx];
      const category = mapCategory(p.name, p.categories, supplier.defaultCategory);
      const payload = {
        name: p.name,
        price: p.price,
        currency: p.currency,
        category,
        description:
          p.description ||
          `منتج من كتالوج ${supplier.nameAr}. للتفاصيل والتواصل راجع بيانات المورد أو رابط المصدر.`,
        storeName: supplier.nameAr,
        contact: displayContact(supplier),
        email: supplier.email || "",
        phone: supplier.phone || "",
        whatsapp: supplier.whatsapp || "",
        website: supplier.website,
        sourceUrl: p.permalink,
        ...(p.imageUrl ? { imageUrl: p.imageUrl } : {}),
        ...(p.sku ? { sku: p.sku } : {}),
        brand: (p.categories && p.categories[0]) || supplier.nameEn,
        supplierId: supplier.id,
        importSource: `wc_${supplier.id}`,
        externalProductId: p.id,
        isVerifiedSeller: true,
        isDirectoryListing: true,
        inStock: p.inStock,
        approvalStatus: "approved",
        syncedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      };
      if (!snap.exists) {
        payload.createdBy = adminUid || "system_store_sync";
        payload.createdAt = FieldValue.serverTimestamp();
        batch.set(refs[idx], payload);
        imported += 1;
      } else {
        const existingSource = snap.get("importSource") || "";
        if (existingSource && !String(existingSource).startsWith("wc_")) {
          return;
        }
        batch.set(refs[idx], payload, { merge: true });
        updated += 1;
      }
    });
    await batch.commit();
  }
  return { imported, updated };
}

async function runStoreSuppliersSync({ adminUid = "system_store_sync" } = {}) {
  const db = getFirestore();
  await upsertSuppliers(db, [...SUPPLIERS, ...CONTACT_ONLY], false);
  await upsertSuppliers(db, SUPPLIERS, true);

  let productsImported = 0;
  let productsUpdated = 0;
  const productsBySupplier = {};

  for (const supplier of SUPPLIERS) {
    const products = await fetchWooProducts(supplier.woo);
    const stats = await upsertProducts(db, supplier, products, adminUid);
    productsImported += stats.imported;
    productsUpdated += stats.updated;
    productsBySupplier[supplier.id] = products.length;
  }

  await db.doc("app_meta/store_suppliers_sync").set(
    {
      syncedAt: FieldValue.serverTimestamp(),
      productsImported,
      productsUpdated,
      productsBySupplier,
      syncedBy: adminUid,
      autoUpdateReady: true,
      source: "cloud_function",
    },
    { merge: true },
  );

  return {
    suppliers: SUPPLIERS.length + CONTACT_ONLY.length,
    productsImported,
    productsUpdated,
    productsBySupplier,
  };
}

function createStoreSuppliersSyncHandlers() {
  const storeSuppliersSyncWeekly = onSchedule(
    {
      schedule: "every monday 03:00",
      timeZone: "Africa/Cairo",
      timeoutSeconds: 540,
      memory: "1GiB",
    },
    async () => {
      await runStoreSuppliersSync({ adminUid: "system_weekly_sync" });
    },
  );

  const storeSuppliersSyncNow = onCall(
    { timeoutSeconds: 540, memory: "1GiB" },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Sign in required");
      }
      const db = getFirestore();
      const userSnap = await db.collection("users").doc(request.auth.uid).get();
      if (userSnap.get("role") !== "admin") {
        throw new HttpsError("permission-denied", "Admin only");
      }
      return runStoreSuppliersSync({ adminUid: request.auth.uid });
    },
  );

  return { storeSuppliersSyncWeekly, storeSuppliersSyncNow };
}

module.exports = { createStoreSuppliersSyncHandlers, runStoreSuppliersSync };
