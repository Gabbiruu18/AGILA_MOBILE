const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

// ==========================================================================================
// HELPER FUNCTION: Reusable function to get a user's data from any role.
// This is the only part that needs to check the notification setting.
// ==========================================================================================
async function getUserData(uid) {
  const rolesToSearch = ["student", "teacher", "program_head"];
  for (const role of rolesToSearch) {
    const userDocRef = admin.firestore().collection("users").doc(role).collection("accounts").doc(uid);
    const userDoc = await userDocRef.get();
    
    if (userDoc.exists) {
      console.log(`User ${uid} found with role '${role}'.`);
      // Return the entire data object. This is useful for checking multiple fields.
      return userDoc.data();
    }
  }
  // This will run only if the user was not found in any of the roles.
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

  if (!receiverUid) {
    console.log("No valid 'to{Role}Id' field found. Exiting.");
    return;
  }
  
  console.log(`Function triggered for new request. Receiver target: ${receiverUid}`);

  // --- MODIFIED: Use the helper function ---
  const receiverData = await getUserData(receiverUid);

  // --- THIS IS THE NEW LOGIC BLOCK ---
  // 1. Check if user exists at all.
  if (!receiverData) {
    // The helper function already logs the reason.
    return;
  }
  // 2. Check the notification preference. Defaults to ON if the field is missing.
  if (receiverData.notificationsEnabled === false) {
    console.log(`User ${receiverUid} has notifications disabled. Not sending.`);
    return;
  }
  // 3. Check for the FCM token.
  if (!receiverData.fcmToken) {
    console.log(`User ${receiverUid} has no FCM token. Not sending.`);
    return;
  }
  // --- END NEW LOGIC BLOCK ---

  const payload = {
    notification: { title: "New Request Received", body: `${requesterName} has sent you a new request.` },
    token: receiverData.fcmToken, // Use the token from the data we fetched
  };

  try {
    await admin.messaging().send(payload);
    console.log("Successfully sent 'new request' message.");
  } catch (error) {
    console.error("Error sending 'new request' message:", error);
  }
});


// ==========================================================================================
// FUNCTION 2: Notifies the REQUESTER when a request is approved or denied.
// ==========================================================================================
exports.sendRequestStatusNotification = onDocumentUpdated("users/{userRole}/accounts/{userId}/Request/{requestId}", async (event) => {
  const newValue = event.data.after.data();
  const previousValue = event.data.before.data();

  if (newValue.status === previousValue.status || (newValue.status !== "Approved" && newValue.status !== "Rejected")) {
    return;
  }
  
  console.log("Function triggered for request status update.");
  const requesterUid = newValue.fromStudentId || newValue.fromTeacherId || newValue.fromProgramHeadId;

  if (!requesterUid) {
    console.log("No valid 'from{Role}Id' field found. Exiting.");
    return;
  }

  // --- MODIFIED: Use the helper function ---
  const requesterData = await getUserData(requesterUid);

  // --- THIS IS THE NEW LOGIC BLOCK (Identical to Function 1) ---
  // 1. Check if user exists at all.
  if (!requesterData) {
    return;
  }
  // 2. Check the notification preference.
  if (requesterData.notificationsEnabled === false) {
    console.log(`User ${requesterUid} has notifications disabled. Not sending.`);
    return;
  }
  // 3. Check for the FCM token.
  if (!requesterData.fcmToken) {
    console.log(`User ${requesterUid} has no FCM token. Not sending.`);
    return;
  }
  // --- END NEW LOGIC BLOCK ---

  const payload = {
    notification: { title: `Request ${newValue.status.charAt(0).toUpperCase() + newValue.status.slice(1)}`, body: `Your request has been ${newValue.status}.` },
    token: requesterData.fcmToken, // Use the token from the data we fetched
  };

  try {
    await admin.messaging().send(payload);
    console.log("Successfully sent 'status update' message.");
  } catch (error) {
    console.error("Error sending message:", error);
  }
});