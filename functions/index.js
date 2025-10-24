const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

// ==========================================================================================
// HELPER FUNCTION: Saves a notification to a user's subcollection. (No changes needed here)
// ==========================================================================================
async function saveNotificationToSubcollection(uid, role, title, message) {
  if (!uid || !role) {
    console.log("Cannot save notification without UID and role.");
    return;
  }
  try {
    const notificationRef = admin.firestore()
      .collection("users").doc(role)
      .collection("accounts").doc(uid)
      .collection("notifications");

    await notificationRef.add({
      title: title,
      message: message,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      read: false,
    });
    console.log(`Notification for ${uid} (role: ${role}) saved to subcollection.`);
  } catch (error) {
    console.error("Error saving notification to subcollection:", error);
  }
}


// ==========================================================================================
// HELPER FUNCTION: Reusable function to get a user's data from any role. (No changes needed here)
// ==========================================================================================
async function getUserData(uid) {
  const rolesToSearch = ["student", "teacher", "program_head"];
  for (const role of rolesToSearch) {
    const userDocRef = admin.firestore().collection("users").doc(role).collection("accounts").doc(uid);
    const userDoc = await userDocRef.get();

    if (userDoc.exists) {
      console.log(`User ${uid} found with role '${role}'.`);
      return { data: userDoc.data(), role: role };
    }
  }
  console.log(`Could not find a user with UID '${uid}' in any role.`);
  return null;
}


// ==========================================================================================
// FUNCTION 1: Notifies the RECEIVER when a NEW request is created.
// ==========================================================================================
exports.sendNewRequestNotification = onDocumentCreated("users/{userRole}/accounts/{userId}/Request/{requestId}", async (event) => {
  const newRequestData = event.data.data();
  const requesterName = newRequestData.requesterName || "Someone";
  const receiverUid = newRequestData.toStudentId || newRequestData.toTeacherId || newRequestData.toProgramHeadId;

  if (!receiverUid) return;

  const receiverInfo = await getUserData(receiverUid);

  // Stop only if user doesn't exist or has explicitly disabled notifications
  if (!receiverInfo || receiverInfo.data.notificationsEnabled === false) {
    console.log(`Notifications will not be processed for user ${receiverUid} (user not found or notifications disabled).`);
    return;
  }

  const title = "New Request Received";
  const body = `${requesterName} has sent you a new request.`;

  // --- NEW LOGIC: Save first, then attempt to send ---
  // 1. Save the notification to the database.
  await saveNotificationToSubcollection(receiverUid, receiverInfo.role, title, body);

  // 2. Check for FCM token and send push notification if available.
  if (receiverInfo.data.fcmToken) {
    const payload = { notification: { title, body }, token: receiverInfo.data.fcmToken };
    try {
      await admin.messaging().send(payload);
      console.log("Successfully sent 'new request' push notification.");
    } catch (error) {
      console.error("Error sending 'new request' push notification:", error);
    }
  } else {
    console.log(`User ${receiverUid} has no FCM token. Skipped sending push notification.`);
  }
});


// ==========================================================================================
// FUNCTION 2: Notifies the REQUESTER when a request is approved or denied.
// ==========================================================================================
exports.sendRequestStatusNotification = onDocumentUpdated("users/{userRole}/accounts/{userId}/Request/{requestId}", async (event) => {
  const newValue = event.data.after.data();
  const previousValue = event.data.before.data();

  if (newValue.status === previousValue.status || (newValue.status !== "Approved" && newValue.status !== "Rejected")) return;

  const requesterUid = newValue.fromStudentId || newValue.fromTeacherId || newValue.fromProgramHeadId;

  if (!requesterUid) return;

  const requesterInfo = await getUserData(requesterUid);

  if (!requesterInfo || requesterInfo.data.notificationsEnabled === false) {
    console.log(`Notifications will not be processed for user ${requesterUid} (user not found or notifications disabled).`);
    return;
  }

  const title = `Request ${newValue.status}`;
  const body = `Your request has been ${newValue.status}.`;

  // --- NEW LOGIC: Save first, then attempt to send ---
  await saveNotificationToSubcollection(requesterUid, requesterInfo.role, title, body);

  if (requesterInfo.data.fcmToken) {
    const payload = { notification: { title, body }, token: requesterInfo.data.fcmToken };
    try {
      await admin.messaging().send(payload);
      console.log("Successfully sent 'status update' push notification.");
    } catch (error) {
      console.error("Error sending 'status update' push notification:", error);
    }
  } else {
    console.log(`User ${requesterUid} has no FCM token. Skipped sending push notification.`);
  }
});


// ==========================================================================================
// FUNCTION FOR STUDENT ATTENDANCE NOTIFICATIONS
// ==========================================================================================
exports.sendStudentAttendanceRecordedNotification = onDocumentCreated("attendance_sessions/{sessionId}/students/{studentId}", async (event) => {
  const studentId = event.params.studentId;
  const attendanceData = event.data.data();
  const attendanceStatus = attendanceData.status || "marked";

  const sessionDoc = await admin.firestore().collection("attendance_sessions").doc(event.params.sessionId).get();
  const subjectName = sessionDoc.data()?.subjectName || "a class";

  const studentInfo = await getUserData(studentId);

  if (!studentInfo || studentInfo.data.notificationsEnabled === false) {
    console.log(`Notifications will not be processed for user ${studentId} (user not found or notifications disabled).`);
    return;
  }

  const title = "Attendance Recorded";
  const body = `Your attendance for ${subjectName} was recorded as '${attendanceStatus}'.`;

  // --- NEW LOGIC: Save first, then attempt to send ---
  await saveNotificationToSubcollection(studentId, studentInfo.role, title, body);

  if (studentInfo.data.fcmToken) {
    const payload = { notification: { title, body }, token: studentInfo.data.fcmToken };
    try {
      await admin.messaging().send(payload);
      console.log("Successfully sent 'student attendance' push notification.");
    } catch (error) {
      console.error("Error sending 'student attendance' push notification:", error);
    }
  } else {
    console.log(`User ${studentId} has no FCM token. Skipped sending push notification.`);
  }
});


// ==========================================================================================
// FUNCTION FOR TEACHER ATTENDANCE NOTIFICATIONS
// ==========================================================================================
exports.sendTeacherAttendanceRecordedNotification = onDocumentCreated("attendance_sessions/{sessionId}/instructor/main", async (event) => {
  const teacherAttendanceData = event.data.data();
  const teacherId = teacherAttendanceData.instructorId;
  const attendanceStatus = teacherAttendanceData.status || "marked";

  if (!teacherId) return;

  const sessionDoc = await admin.firestore().collection("attendance_sessions").doc(event.params.sessionId).get();
  const subjectName = sessionDoc.data()?.subjectName || "a class";

  const teacherInfo = await getUserData(teacherId);

  if (!teacherInfo || teacherInfo.data.notificationsEnabled === false) {
    console.log(`Notifications will not be processed for user ${teacherId} (user not found or notifications disabled).`);
    return;
  }

  const title = "Attendance Recorded";
  const body = `Your attendance for your class, ${subjectName}, was recorded as '${attendanceStatus}'.`;

  // --- NEW LOGIC: Save first, then attempt to send ---
  await saveNotificationToSubcollection(teacherId, teacherInfo.role, title, body);

  if (teacherInfo.data.fcmToken) {
    const payload = { notification: { title, body }, token: teacherInfo.data.fcmToken };
    try {
      await admin.messaging().send(payload);

      console.log("Successfully sent 'teacher attendance' push notification.");
    } catch (error) {
      console.error("Error sending 'teacher attendance' push notification:", error);
    }
  } else {
    console.log(`User ${teacherId} has no FCM token. Skipped sending push notification.`);
  }
});