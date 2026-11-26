"use strict";
const test = require("node:test");
const assert = require("node:assert");
const { pickRecipients, createNotifyHandlers, MAX_RECIPIENTS } = require("../notify");

function fakeDb(store) {
  const added = [];
  const db = {
    added,
    collection(name) {
      return {
        doc: (id) => ({
          async get() {
            const d = store[`${name}/${id}`];
            return { exists: d !== undefined, data: () => d };
          },
        }),
        where(field, _op, value) {
          return {
            async get() {
              const docs = Object.entries(store)
                .filter(([p]) => p.startsWith(`${name}/`) && store[p][field] === value)
                .map(([, d]) => ({ data: () => d }));
              return { forEach: (fn) => docs.forEach(fn) };
            },
          };
        },
        async add(doc) {
          added.push({ name, ...doc });
        },
      };
    },
  };
  return db;
}
const FieldValue = { serverTimestamp: () => "TS" };
const mk = (store) => {
  const db = fakeDb(store);
  return { db, h: createNotifyHandlers({ db, FieldValue, nameFor: async (u) => `name-${u}` }) };
};

test("recipients: author plus followers, never the replier, author can opt out", () => {
  const follows = [{ userId: "f1", mode: "on" }, { userId: "au", mode: "off" }, { userId: "rp" }];
  assert.deepStrictEqual(
    pickRecipients({ authorId: "au", replierId: "rp", follows }).sort(),
    ["f1"],
  );
  assert.deepStrictEqual(
    pickRecipients({ authorId: "au", replierId: "rp", follows: [] }),
    ["au"],
  );
  assert.deepStrictEqual(pickRecipients({ authorId: "rp", replierId: "rp", follows: [] }), []);
});

test("recipients are capped", () => {
  const follows = Array.from({ length: 200 }, (_, i) => ({ userId: `u${i}` }));
  assert.strictEqual(pickRecipients({ authorId: "a", replierId: "r", follows }).length, MAX_RECIPIENTS);
});

test("reply notifies author and follower with server-side name", async () => {
  const store = {
    "community_posts/p1": { authorId: "au", title: "Sampling help", approvalStatus: "approved" },
    "community_follows/f1_p1": { userId: "f1", postId: "p1", mode: "on" },
  };
  const { db, h } = mk(store);
  const r = await h.handleReply("p1", { authorId: "rp", authorName: "Dr. Fake" });
  assert.strictEqual(r.sent, 2);
  const byUser = Object.fromEntries(db.added.map((n) => [n.userId, n]));
  assert.ok(byUser.au.title.includes("your post"));
  assert.ok(byUser.f1.title.includes("you follow"));
  assert.strictEqual(byUser.au.body, "name-rp: Sampling help");
  assert.strictEqual(byUser.au.contextType, "community_post");
  assert.strictEqual(byUser.au.contextId, "p1");
  assert.strictEqual(byUser.au.read, false);
});

test("replying to your own post notifies nobody", async () => {
  const store = { "community_posts/p1": { authorId: "au", title: "T", approvalStatus: "approved" } };
  const { db, h } = mk(store);
  assert.strictEqual((await h.handleReply("p1", { authorId: "au" })).sent, 0);
  assert.strictEqual(db.added.length, 0);
});

test("no notification for a post that is not published", async () => {
  const store = { "community_posts/p1": { authorId: "au", title: "T", approvalStatus: "suspended" } };
  const { db, h } = mk(store);
  assert.strictEqual((await h.handleReply("p1", { authorId: "x" })).sent, 0);
  assert.strictEqual(db.added.length, 0);
});

test("post approval notifies the author once, never for starter content", async () => {
  const { db, h } = mk({});
  assert.strictEqual((await h.handlePostStatus("p1", { approvalStatus: "pending" }, { approvalStatus: "approved", authorId: "au", title: "T" })).sent, 1);
  assert.strictEqual(db.added[0].type, "community_post_approved");
  assert.strictEqual((await h.handlePostStatus("p1", { approvalStatus: "approved" }, { approvalStatus: "approved", authorId: "au" })).sent, 0);
  assert.strictEqual((await h.handlePostStatus("p1", { approvalStatus: "pending" }, { approvalStatus: "approved", authorId: "au", isStarterContent: true })).sent, 0);
  assert.strictEqual((await h.handlePostStatus("p1", { approvalStatus: "approved" }, { approvalStatus: "suspended", authorId: "au" })).sent, 0);
});
