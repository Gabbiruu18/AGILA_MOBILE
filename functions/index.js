const functions = require("firebase-functions");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

// Initialize Firebase Admin SDK
admin.initializeApp();

// Nodemailer setup (Use your email credentials or an SMTP service like Gmail, SendGrid, etc.)
const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: "gabby.roxanne12@gmail.com", // Replace with your email
    pass: "projectagila1234", // Replace with your app password (DO NOT use your actual password)
  },
});

// Cloud Function to send OTP
exports.sendEmailOTP = functions.https.onCall(async (data, context) => {
  const email = data.email;
  const otp = data.otp;

  if (!email || !otp) {
    return { success: false, message: "Invalid email or OTP" };
  }

  const mailOptions = {
    from: "your-email@gmail.com",
    to: email,
    subject: "Your OTP Code",
    text: `Your OTP code is: ${otp}. This code is valid for 5 minutes.`,
  };

  try {
    await transporter.sendMail(mailOptions);
    return { success: true, message: "OTP sent successfully" };
  } catch (error) {
    console.error("Error sending email:", error);
    return { success: false, message: error.message };
  }
});
