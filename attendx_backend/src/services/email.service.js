const nodemailer = require('nodemailer');

let transporter = null;

function init() {
  if (transporter) return transporter;

  const host = process.env.SMTP_HOST;
  const port = Number(process.env.SMTP_PORT) || 587;
  const user = process.env.SMTP_USER;
  const pass = process.env.SMTP_PASS;

  if (!host || !user || !pass) {
    console.warn('[Email] SMTP credentials not set — email disabled');
    return null;
  }

  transporter = nodemailer.createTransport({
    host,
    port,
    secure: port === 465,
    auth: { user, pass },
  });

  console.log('[Email] ✅ SMTP configured —', user);
  return transporter;
}

async function sendPasswordReset(toEmail, resetToken) {
  const t = init();
  if (!t) {
    console.warn('[Email] Cannot send reset email — SMTP not configured');
    return;
  }

  const resetUrl = `${process.env.APP_URL || 'attendx://reset-password'}?token=${resetToken}`;

  await t.sendMail({
    from: `"AttendX" <${process.env.SMTP_USER}>`,
    to: toEmail,
    subject: 'AttendX — Password Reset Code',
    text:
      `Your AttendX password reset code is:\n\n${resetToken}\n\n` +
      `This code expires in 15 minutes.\n\n` +
      `If you did not request a password reset, ignore this email.`,
    html:
      `<div style="font-family:sans-serif;max-width:480px;margin:auto">` +
      `<h2 style="color:#1E88E5">AttendX Password Reset</h2>` +
      `<p>Use the code below to reset your password. It expires in <strong>15 minutes</strong>.</p>` +
      `<div style="font-size:32px;font-weight:bold;letter-spacing:6px;` +
        `background:#f1f5f9;padding:16px 24px;border-radius:8px;` +
        `text-align:center;margin:24px 0">${resetToken}</div>` +
      `<p style="color:#64748b;font-size:13px">` +
        `If you did not request a password reset, you can safely ignore this email.</p>` +
      `</div>`,
  });

  console.log(`[Email] Reset code sent to ${toEmail}`);
}

module.exports = { init, sendPasswordReset };
