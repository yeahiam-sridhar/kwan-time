const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

async function sendSpaceEventNotification({
  spaceId,
  eventId,
  event,
  title,
  body,
  type,
}) {
  const spaceDoc = await admin.firestore().collection('spaces').doc(spaceId).get();
  if (!spaceDoc.exists) {
    return null;
  }
  const space = spaceDoc.data();

  const roles = space.roles || {};
  const allUids = [
    ...(roles.admins || []),
    ...(roles.members || []),
    ...(roles.viewers || []),
  ].filter((uid) => uid !== event.createdBy);

  if (allUids.length === 0) {
    return null;
  }

  const tokens = [];
  for (let i = 0; i < allUids.length; i += 10) {
    const chunk = allUids.slice(i, i + 10);
    const usersSnap = await admin
      .firestore()
      .collection('users')
      .where('uid', 'in', chunk)
      .get();
    usersSnap.docs.forEach((doc) => {
      const token = doc.data().fcmToken;
      if (token) {
        tokens.push(token);
      }
    });
  }

  if (tokens.length === 0) {
    return null;
  }

  const message = {
    tokens,
    notification: {
      title,
      body,
    },
    data: {
      spaceId,
      eventId,
      type,
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
    },
    android: {
      priority: 'high',
      notification: { channelId: 'space_events' },
    },
    apns: {
      payload: { aps: { sound: 'default' } },
    },
  };

  const response = await admin.messaging().sendEachForMulticast(message);
  console.log(
    `[spaceNotifications] sent ${response.successCount}/${tokens.length} for event ${eventId} in space ${spaceId}`
  );

  const invalidTokenIds = [];
  response.responses.forEach((resp, idx) => {
    if (
      !resp.success &&
      (resp.error?.code === 'messaging/invalid-registration-token' ||
        resp.error?.code === 'messaging/registration-token-not-registered')
    ) {
      invalidTokenIds.push(tokens[idx]);
    }
  });

  if (invalidTokenIds.length > 0) {
    const batch = admin.firestore().batch();
    const usersSnap = await admin
      .firestore()
      .collection('users')
      .where('fcmToken', 'in', invalidTokenIds)
      .get();
    usersSnap.docs.forEach((doc) => {
      batch.update(doc.ref, { fcmToken: admin.firestore.FieldValue.delete() });
    });
    await batch.commit();
  }

  return null;
}

exports.onSpaceEventCreated = functions.firestore
  .document('spaces/{spaceId}/events/{eventId}')
  .onCreate(async (snap, context) => {
    const event = snap.data();
    const { spaceId, eventId } = context.params;
    return sendSpaceEventNotification({
      spaceId,
      eventId,
      event,
      title: 'New Event Added',
      body: `"${event.title}" added to ${space.name}`,
      type: 'event_created',
    });
  });

exports.onSpaceEventUpdated = functions.firestore
  .document('spaces/{spaceId}/events/{eventId}')
  .onUpdate(async (change, context) => {
    const event = change.after.data();
    const { spaceId, eventId } = context.params;
    return sendSpaceEventNotification({
      spaceId,
      eventId,
      event,
      title: 'Event Updated',
      body: `"${event.title}" updated in ${space.name}`,
      type: 'event_updated',
    });
  });

exports.onSpaceEventDeleted = functions.firestore
  .document('spaces/{spaceId}/events/{eventId}')
  .onDelete(async (snap, context) => {
    const event = snap.data();
    const { spaceId, eventId } = context.params;
    return sendSpaceEventNotification({
      spaceId,
      eventId,
      event,
      title: 'Event Removed',
      body: `"${event.title}" removed from ${space.name}`,
      type: 'event_deleted',
    });
  });
