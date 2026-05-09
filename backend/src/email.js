function canSend() {
  return Boolean(process.env.SMTP_HOST && process.env.SMTP_USER && process.env.SMTP_PASS);
}

async function sendEmail({ to, subject, text }) {
  const recipients = Array.isArray(to) ? to.filter(Boolean) : [to].filter(Boolean);
  if (!recipients.length) return;

  // Keep backend running even if SMTP isn't configured in dev.
  if (!canSend()) {
    console.log("[email:skipped]", { to: recipients, subject });
    return;
  }

  let nodemailer;
  try {
    nodemailer = require("nodemailer");
  } catch (_err) {
    console.log("[email:missing-nodemailer]", { to: recipients, subject });
    return;
  }

  const transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port: Number(process.env.SMTP_PORT || 587),
    secure: String(process.env.SMTP_SECURE || "").toLowerCase() === "true",
    auth: {
      user: process.env.SMTP_USER,
      pass: process.env.SMTP_PASS,
    },
  });

  const from = process.env.MAIL_FROM || process.env.SMTP_USER;
  await transporter.sendMail({
    from,
    to: recipients.join(","),
    subject,
    text,
  });
}

module.exports = { sendEmail };

