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

async function getResendApiKey(): Promise<string | null> {
  try {
    const doc = await db.collection("config").doc("email").get();
    return doc.data()?.resendApiKey as string | null;
  } catch {
    return null;
  }
}

async function sendParentEmail({
  parentEmail,
  studentName,
  teacherName,
  subject,
  body,
}: {
  parentEmail: string;
  studentName: string;
  teacherName: string;
  subject: string;
  body: string;
}): Promise<void> {
  const resendApiKey = await getResendApiKey();
  if (!resendApiKey) {
    console.error("No Resend API key found");
    return;
  }

  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${resendApiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: "Zyntune <notifications@zyntune.com>",
      to: [parentEmail],
      subject,
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; background: #0D0D1A; color: #ffffff; border-radius: 16px; overflow: hidden;">
          <div style="background: linear-gradient(135deg, #6B21FF, #9B59B6); padding: 24px; text-align: center;">
            <h1 style="margin: 0; font-size: 24px; font-weight: 900; letter-spacing: 1px;">Zyntune</h1>
            <p style="margin: 8px 0 0; color: rgba(255,255,255,0.7); font-size: 14px;">Music Practice App</p>
          </div>
          <div style="padding: 24px;">
            <p style="color: rgba(255,255,255,0.6); font-size: 14px; margin: 0 0 16px;">
              This is an automated notification for the parent or guardian of <strong style="color: #ffffff;">${studentName}</strong>.
            </p>
            <div style="background: rgba(107,33,255,0.15); border: 1px solid rgba(107,33,255,0.3); border-radius: 12px; padding: 16px; margin-bottom: 16px;">
              <p style="margin: 0; font-size: 15px; line-height: 1.6; color: #ffffff;">${body}</p>
            </div>
            <p style="color: rgba(255,255,255,0.4); font-size: 12px; margin: 0;">
              Sent by ${teacherName} via Zyntune Studio · <a href="mailto:zyntuneapp@gmail.com" style="color: #00BFA5;">Report a concern</a>
            </p>
          </div>
        </div>
      `,
    }),
  });

  if (!response.ok) {
    const err = await response.text();
    throw new Error(`Resend error: ${err}`);
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

  if (typeof presetIndex !== "number" || presetIndex < 0 || presetIndex >= PRESET_MESSAGES.length) {
    throw new HttpsError("invalid-argument", "Invalid preset message index.");
  }

  const message = PRESET_MESSAGES[presetIndex];

  const studentDoc = await db.collection("users").doc(studentUid).get();
  if (!studentDoc.exists) {
    throw new HttpsError("not-found", "Student not found.");
  }

  const studentData = studentDoc.data()!;
  if (studentData.teacherId !== teacherUid) {
    throw new HttpsError("permission-denied", "You are not this student's teacher.");
  }

  const teacherDoc = await db.collection("users").doc(teacherUid).get();
  const teacherName = teacherDoc.data()?.name as string | undefined ?? "Your teacher";
  const studentName = studentData.name as string | undefined ?? "Your child";
  const parentEmail = studentData.parentEmail as string | undefined ?? "";

  // Log the reminder
  await db.collection("users").doc(studentUid).collection("reminders").add({
    teacherUid,
    studentUid,
    teacherName,
    message,
    presetIndex,
    sentAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Send push notification
  const restApiKey = await getOneSignalKey();
  if (restApiKey) {
    await fetch("https://onesignal.com/api/v1/notifications", {
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
  }

  // CC parent if email is set
  if (parentEmail) {
    try {
      await sendParentEmail({
        parentEmail,
        studentName,
        teacherName,
        subject: `Practice reminder for ${studentName} from ${teacherName}`,
        body: `${teacherName} sent a practice reminder to ${studentName}:<br><br><strong>${message}</strong>`,
      });
    } catch (e) {
      console.error("Parent email failed:", e);
    }
  }

  return { success: true };
});

export const notifyNewAssignment = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }

  const teacherUid = request.auth.uid;
  const { studentUid, assignmentTitle } = request.data as {
    studentUid: string;
    assignmentTitle: string;
  };

  if (!studentUid || !assignmentTitle) {
    throw new HttpsError("invalid-argument", "studentUid and assignmentTitle are required.");
  }

  const studentDoc = await db.collection("users").doc(studentUid).get();
  if (!studentDoc.exists) {
    throw new HttpsError("not-found", "Student not found.");
  }

  const studentData = studentDoc.data()!;
  if (studentData.teacherId !== teacherUid) {
    throw new HttpsError("permission-denied", "You are not this student's teacher.");
  }

  const teacherDoc = await db.collection("users").doc(teacherUid).get();
  const teacherName = teacherDoc.data()?.name as string | undefined ?? "Your teacher";
  const studentName = studentData.name as string | undefined ?? "Your child";
  const parentEmail = studentData.parentEmail as string | undefined ?? "";

  // CC parent if email is set
  if (parentEmail) {
    try {
      await sendParentEmail({
        parentEmail,
        studentName,
        teacherName,
        subject: `New assignment for ${studentName} from ${teacherName}`,
        body: `${teacherName} assigned new homework to ${studentName}:<br><br><strong>${assignmentTitle}</strong><br><br>Open the Zyntune app to view the full assignment.`,
      });
    } catch (e) {
      console.error("Parent email failed:", e);
    }
  }

  return { success: true };
});
