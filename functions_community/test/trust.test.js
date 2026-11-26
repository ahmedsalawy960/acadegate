"use strict";
const test = require("node:test");
const assert = require("node:assert");
const { resolveAuthorName, badgeForProfile, createTrustHandlers } = require("../trust");

// Minimal in-memory Firestore stand-in.
function fakeDb(store) {
  const ref = (path) => ({
    path,
    async get() {
      const d = store[path];
      return { exists: d !== undefined, data: () => d };
    },
    async update(patch) {
      store[path] = { ...store[path] };
      for (const [k, v] of Object.entries(patch)) {
        if (v === "DELETE") delete store[path][k];
        else store[path][k] = v;
      }
    },
    collection: (name) => collection(`${path}/${name}`),
  });
  const collection = (path) => ({
    doc: (id) => ref(`${path}/${id}`),
    where(field, op, value) {
      const filters = [[field, value]];
      const q = {
        where(f, o, v) { filters.push([f, v]); return q; },
        async get() {
          const docs = Object.entries(store)
            .filter(([p]) => p.startsWith(`${path}/`) && !p.slice(path.length + 1).includes("/"))
            .filter(([, d]) => filters.every(([f, v]) => d[f] === v))
            .map(([, d]) => ({ data: () => d }));
          return { forEach: (fn) => docs.forEach(fn), size: docs.length };
        },
      };
      return q;
    },
  });
  return { collection };
}
const FieldValue = { serverTimestamp: () => "TS", delete: () => "DELETE" };
const auth = (users) => ({
  async getUser(uid) {
    if (!users[uid]) throw new Error("not found");
    return users[uid];
  },
});

test("author name: profile, then account, then email, then default", () => {
  assert.strictEqual(resolveAuthorName({ displayName: " Sara " }, { displayName: "X" }), "Sara");
  assert.strictEqual(resolveAuthorName({}, { displayName: "Omar" }), "Omar");
  assert.strictEqual(resolveAuthorName({}, { email: "mona@x.edu" }), "mona");
  assert.strictEqual(resolveAuthorName(null, null), "طالب");
  assert.strictEqual(resolveAuthorName({ displayName: "a".repeat(300) }, null).length, 100);
});

test("badges come only from platform roles", () => {
  assert.strictEqual(badgeForProfile({ role: "admin" }), "team");
  assert.strictEqual(badgeForProfile({ role: "supervisor" }), "supervisor");
  assert.strictEqual(badgeForProfile({ role: "student" }), "");
  assert.strictEqual(badgeForProfile({ badge: "team" }), "");
});

test("a forged client authorName is replaced by the server name", async () => {
  const store = {
    "users/u1": { displayName: "Real Name", role: "student" },
    "community_posts/p1": { authorId: "u1", authorName: "Dr. Fake Professor", authorBadge: "team" },
  };
  const h = createTrustHandlers({ db: fakeDb(store), auth: auth({}), FieldValue });
  const ref = fakeDb(store).collection("community_posts").doc("p1");
  await h.stampAuthor(ref, store["community_posts/p1"]);
  assert.strictEqual(store["community_posts/p1"].authorName, "Real Name");
  assert.strictEqual(store["community_posts/p1"].authorBadge, undefined);
});

test("admin account gets the team badge", async () => {
  const store = {
    "users/a1": { displayName: "Ahmed", role: "admin" },
    "community_posts/p1": { authorId: "a1", authorName: "x" },
  };
  const h = createTrustHandlers({ db: fakeDb(store), auth: auth({}), FieldValue });
  await h.stampAuthor(fakeDb(store).collection("community_posts").doc("p1"), store["community_posts/p1"]);
  assert.strictEqual(store["community_posts/p1"].authorBadge, "team");
});

test("starter content keeps its fixed author line", async () => {
  const store = { "community_posts/s": { authorId: "a1", authorName: "Team", isStarterContent: true } };
  const h = createTrustHandlers({ db: fakeDb(store), auth: auth({}), FieldValue });
  const r = await h.stampAuthor(fakeDb(store).collection("community_posts").doc("s"), store["community_posts/s"]);
  assert.strictEqual(r.changed, false);
  assert.strictEqual(store["community_posts/s"].authorName, "Team");
});

function reportsFor(postId, replyId, ids, status = "open") {
  const out = {};
  ids.forEach((id) => {
    out[`community_reports/${id}_${postId}`] = { reporterId: id, postId, replyId, status };
  });
  return out;
}

test("post is hidden only at 3 distinct open reports", async () => {
  const store = {
    "community_posts/p1": { authorId: "au", approvalStatus: "approved" },
    ...reportsFor("p1", "", ["r1", "r2"]),
  };
  const h = createTrustHandlers({ db: fakeDb(store), auth: auth({}), FieldValue });
  assert.strictEqual((await h.handleReport({ postId: "p1", replyId: "" })).hidden, false);
  Object.assign(store, reportsFor("p1", "", ["r3"]));
  const r = await h.handleReport({ postId: "p1", replyId: "" });
  assert.strictEqual(r.hidden, true);
  assert.strictEqual(store["community_posts/p1"].approvalStatus, "suspended");
  assert.strictEqual(store["community_posts/p1"].hiddenByReports, true);
});

test("author self-reports and resolved reports do not count", async () => {
  const store = {
    "community_posts/p1": { authorId: "au", approvalStatus: "approved" },
    ...reportsFor("p1", "", ["au", "r1"]),
    ...reportsFor("p1", "", ["r2", "r3"], "dismissed"),
  };
  const h = createTrustHandlers({ db: fakeDb(store), auth: auth({}), FieldValue });
  const r = await h.handleReport({ postId: "p1", replyId: "" });
  assert.strictEqual(r.hidden, false);
  assert.strictEqual(store["community_posts/p1"].approvalStatus, "approved");
});

test("a reply is flagged, the post stays public", async () => {
  const store = {
    "community_posts/p1": { authorId: "au", approvalStatus: "approved" },
    "community_posts/p1/replies/x": { authorId: "bu" },
  };
  ["r1", "r2", "r3"].forEach((id) => {
    store[`community_reports/${id}_p1_x`] = { reporterId: id, postId: "p1", replyId: "x", status: "open" };
  });
  const h = createTrustHandlers({ db: fakeDb(store), auth: auth({}), FieldValue });
  const r = await h.handleReport({ postId: "p1", replyId: "x" });
  assert.strictEqual(r.hidden, true);
  assert.strictEqual(store["community_posts/p1/replies/x"].hiddenByReports, true);
  assert.strictEqual(store["community_posts/p1"].approvalStatus, "approved");
});

test("an already suspended or pending post is left alone", async () => {
  const store = {
    "community_posts/p1": { authorId: "au", approvalStatus: "rejected" },
    ...reportsFor("p1", "", ["r1", "r2", "r3"]),
  };
  const h = createTrustHandlers({ db: fakeDb(store), auth: auth({}), FieldValue });
  const r = await h.handleReport({ postId: "p1", replyId: "" });
  assert.strictEqual(r.hidden, false);
  assert.strictEqual(store["community_posts/p1"].approvalStatus, "rejected");
});
