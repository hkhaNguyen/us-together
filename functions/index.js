// When one of the two adds something, the app writes an activity/{id}
// document in the same batch. This sends it as a notification to every
// device the other one has filed under tokens/, then removes it.
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();

// FCM's answer for a token whose app was uninstalled or signed out.
const goneTokens = new Set(['messaging/registration-token-not-registered', 'messaging/invalid-registration-token']);

exports.tellTheOther = onDocumentCreated(
  // Firestore's region: the trigger has to run beside the database.
  { document: 'activity/{id}', region: 'asia-southeast1' },
  async (event) => {
    const activity = event.data.data();
    const db = getFirestore();
    const [person, tokens] = await Promise.all([
      db.doc(`people/${activity.by}`).get(),
      db.collection('tokens').where('person', '!=', activity.by).get(),
    ]);

    if (!tokens.empty) {
      const { title, body } = await describe(db, person.get('name') ?? 'Ai đó', activity);
      const result = await getMessaging().sendEachForMulticast({
        tokens: tokens.docs.map((d) => d.id),
        notification: { title, body },
      });
      await Promise.all(
        result.responses.map((r, i) => (goneTokens.has(r.error?.code) ? tokens.docs[i].ref.delete() : null)),
      );
    }

    await event.data.ref.delete();
  },
);

/** The notification's two lines, in the app's voice. */
async function describe(db, name, activity) {
  switch (activity.type) {
    case 'photos':
      return { title: `${name} vừa thêm ${activity.count} ảnh`, body: activity.title || 'vào xem nha' };
    case 'moment':
      return { title: `${name} vừa lưu một kỷ niệm`, body: activity.title };
    case 'moment-photos':
      return { title: `${name} thêm ${activity.count} ảnh vào kỷ niệm`, body: activity.title };
    case 'entry': {
      const moment = await db.doc(`moments/${activity.momentId}`).get();
      return { title: `${name} viết cảm nghĩ về “${moment.get('title') ?? 'một kỷ niệm'}”`, body: activity.text };
    }
    default:
      return { title: `${name} vừa thêm gì đó`, body: 'vào xem nha' };
  }
}
