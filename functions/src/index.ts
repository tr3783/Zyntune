import { setGlobalOptions } from "firebase-functions";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import fetch from "node-fetch";

setGlobalOptions({ maxInstances: 10 });

admin.initializeApp();
const db = admin.firestore();

const ONESIGNAL_APP_ID = "20e7738a-bb97-4378-9f7d-5204ec5e87a3";

const PRESET_MESSAGES = [
  "Don't forget to practice today! 🎵",
  "Great work this week — keep it up! 🌟",
  "Lesson coming up — make sure you've practiced!",
  "Check your assignments in Zyntune!",
  "You're doing great — keep the streak going! 🔥",
];

async function getOneSignalKey(): Promise<string | null> {
  try {
    const doc = await db.collection("config").doc("onesignal").get();
    return doc.data()?.restApiKey as string | null;
  } catch {
    return null;
  }
}

export const sendReminder = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }

  const teacherUid = request.auth.uid;
  const { studentUid, presetIndex } = request.data as {
    studentUid: string;
    presetIndex: number;
  };

  if (!studentUid) {
    throw new HttpsError("invalid-argument", "studentUid is required.");
  }

  // Validate preset index
  if (typeof presetIndex !== "number" || presetIndex < 0 || presetIndex >= PRESET_MESSAGES.length) {
    throw new HttpsError("invalid-argument", "Invalid preset message index.");
  }

  const message = PRESET_MESSAGES[presetIndex];

  // Verify caller is actually this student's teacher
  const studentDoc = await db.collection("users").doc(studentUid).get();
  if (!studentDoc.exists) {
    throw new HttpsError("not-found", "Student not found.");
  }

  const studentData = studentDoc.data()!;
  if (studentData.teacherId !== teacherUid) {
    throw new HttpsError("permission-denied", "You are not this student's teacher.");
  }

  // Get teacher name
  const teacherDoc = await db.collection("users").doc(teacherUid).get();
  const teacherName = teacherDoc.data()?.name as string | undefined ?? "Your teacher";

  // Log the reminder to Firestore for audit trail
  await db.collection("users").doc(studentUid).collection("reminders").add({
    teacherUid,
    studentUid,
    teacherName,
    message,
    presetIndex,
    sentAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Get OneSignal key
  const restApiKey = await getOneSignalKey();
  if (!restApiKey) {
    throw new HttpsError("internal", "Push notification service not configured.");
  }

  // Send via OneSignal
  const response = await fetch("https://onesignal.com/api/v1/notifications", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Basic ${restApiKey}`,
    },
    body: JSON.stringify({
      app_id: ONESIGNAL_APP_ID,
      target_channel: "push",
      include_aliases: { external_id: [studentUid] },
      headings: { en: `👋 Reminder from ${teacherName}` },
      contents: { en: message },
      data: { type: "reminder" },
    }),
  });

  if (!response.ok) {
    const err = await response.text();
    throw new HttpsError("internal", `OneSignal error: ${err}`);
  }

  return { success: true };
});
