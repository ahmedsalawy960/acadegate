"use strict";

// In-app notifications for community replies. Clients cannot write the
// notifications collection, so the server does it here.

const MAX_RECIPIENTS = 50;

function clip(text, max) {
  const value = typeof text === "string" ? text.trim() : "";
  return value.length > max ? `${value.slice(0, max - 1).trim()}…` : value;
}

/**
 * Who hears about a new reply: the post author (unless they switched it off)
 * and everyone who follows the post. Never the replier. Capped.
 */
function pickRecipients({ authorId, replierId, follows }) {
  const wanted = new Set();
  const off = new Set();
  for (const f of follows) {
    if (!f || !f.userId) continue;
    if (f.mode === "off") off.add(f.userId);
    else wanted.add(f.userId);
  }
  if (authorId && !off.has(authorId)) wanted.add(authorId);
  wanted.delete(replierId);
  return [...wanted].slice(0, MAX_RECIPIENTS);
}

function createNotifyHandlers({ db, FieldValue, nameFor }) {
  async function writeNotification(userId, fields) {
    await db.collection("notifications").add({
      userId,
      read: false,
      createdAt: FieldValue.serverTimestamp(),
      ...fields,
    });
  }

  /** New reply: notify the author and followers of the post. */
  async function handleReply(postId, reply) {
    const replierId = reply && reply.authorId;
    if (!postId || !replierId) return { sent: 0, reason: "no-reply" };

    const postSnap = await db.collection("community_posts").doc(postId).get();
    if (!postSnap.exists) return { sent: 0, reason: "no-post" };
    const post = postSnap.data();
    // Only published posts have replies that others should be pinged about.
    if (post.approvalStatus !== undefined && post.approvalStatus !== "approved") {
      return { sent: 0, reason: "not-public" };
    }

    const followSnap = await db
      .collection("community_follows")
      .where("postId", "==", postId)
      .get();
    const follows = [];
    followSnap.forEach((doc) => follows.push(doc.data()));

    const recipients = pickRecipients({
      authorId: post.authorId,
      replierId,
      follows,
    });
    if (recipients.length === 0) return { sent: 0, reason: "nobody" };

    const replierName = clip(await nameFor(replierId), 60);
    const title = clip(post.title, 80);
    const followerSet = new Set(follows.map((f) => f.userId));
    let sent = 0;
    for (const userId of recipients) {
      const isAuthor = userId === post.authorId;
      await writeNotification(userId, {
        title: isAuthor
          ? "رد جديد على منشورك | New reply on your post"
          : "رد جديد على منشور تتابعه | New reply on a post you follow",
        body: `${replierName}: ${title}`,
        type: "community_reply",
        senderId: replierId,
        contextId: postId,
        contextType: "community_post",
        isFollower: followerSet.has(userId),
      });
      sent += 1;
    }
    return { sent };
  }

  /** A post moved from pending to approved: tell its author. */
  async function handlePostStatus(postId, before, after) {
    if (!before || !after) return { sent: 0 };
    if (before.approvalStatus === "approved" || after.approvalStatus !== "approved") {
      return { sent: 0 };
    }
    if (after.isStarterContent === true || !after.authorId) return { sent: 0 };
    await writeNotification(after.authorId, {
      title: "تم نشر منشورك | Your post is published",
      body: clip(after.title, 120),
      type: "community_post_approved",
      contextId: postId,
      contextType: "community_post",
    });
    return { sent: 1 };
  }

  return { handleReply, handlePostStatus };
}

module.exports = { MAX_RECIPIENTS, pickRecipients, createNotifyHandlers };
