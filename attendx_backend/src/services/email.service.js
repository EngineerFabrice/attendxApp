'use strict'
const nodemailer = require('nodemailer')

// ── Transporter (lazy-init, cached) ─────────────────────────────────────────
let _transport = null

function _getTransport() {
  if (_transport) return _transport

  const host = process.env.SMTP_HOST
  const port = Number(process.env.SMTP_PORT) || 587
  const user = process.env.SMTP_USER
  const pass = process.env.SMTP_PASS

  if (!host || !user || !pass) {
    console.warn('[Email] SMTP not configured — email notifications disabled')
    return null
  }

  _transport = nodemailer.createTransport({
    host,
    port,
    secure: port === 465,
    auth: { user, pass },
    pool: true,
    maxConnections: 5,
  })

  console.log('[Email] ✅ SMTP ready —', user)
  return _transport
}

// ── Base sender ───────────────────────────────────────────────────────────────
async function _send({ to, subject, html, text }) {
  const t = _getTransport()
  if (!t) return  // silently skip when SMTP not configured

  const from = `"AttendX" <${process.env.EMAIL_FROM || process.env.SMTP_USER}>`
  try {
    await t.sendMail({ from, to, subject, html, text })
    console.log(`[Email] ✉  "${subject}" → ${to}`)
  } catch (err) {
    console.error(`[Email] ✗ Failed to send to ${to}:`, err.message)
    throw err
  }
}

// ── Shared layout wrapper ─────────────────────────────────────────────────────
function _layout(title, bodyHtml) {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8"/>
  <meta name="viewport" content="width=device-width,initial-scale=1"/>
  <title>${title}</title>
</head>
<body style="margin:0;padding:0;background:#f1f5f9;font-family:Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#f1f5f9;padding:40px 16px;">
    <tr><td align="center">
      <table width="600" cellpadding="0" cellspacing="0"
             style="background:#ffffff;border-radius:12px;overflow:hidden;box-shadow:0 2px 8px rgba(0,0,0,.08);">
        <tr>
          <td style="background:#2563eb;padding:28px 36px;">
            <span style="color:#fff;font-size:22px;font-weight:700;letter-spacing:-0.5px;">&#10003; AttendX</span>
            <span style="color:#bfdbfe;font-size:13px;margin-left:12px;">Smart Attendance System</span>
          </td>
        </tr>
        <tr>
          <td style="padding:36px 36px 24px;">
            ${bodyHtml}
          </td>
        </tr>
        <tr>
          <td style="background:#f8fafc;padding:20px 36px;border-top:1px solid #e2e8f0;">
            <p style="margin:0;font-size:12px;color:#94a3b8;text-align:center;">
              This is an automated message from AttendX. Please do not reply to this email.<br/>
              &copy; ${new Date().getFullYear()} AttendX &mdash; University of Rwanda
            </p>
          </td>
        </tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`
}

// ── 1. Password reset ─────────────────────────────────────────────────────────
async function sendPasswordReset(toEmail, resetToken) {
  const appUrl   = process.env.APP_URL || 'http://localhost:5173'
  const resetUrl = `${appUrl}/reset-password?token=${resetToken}`

  const html = _layout('Reset Your Password', `
    <h2 style="color:#1e293b;font-size:22px;margin:0 0 8px;">Reset Your Password</h2>
    <p style="color:#475569;margin:0 0 20px;">
      We received a request to reset your AttendX password.
      Use the code below &mdash; it expires in <strong>15 minutes</strong>.
    </p>
    <div style="background:#f1f5f9;border-radius:10px;padding:24px;text-align:center;margin-bottom:24px;">
      <span style="font-size:36px;font-weight:700;letter-spacing:10px;color:#2563eb;">${resetToken}</span>
    </div>
    <p style="margin:0 0 20px;">Or click the button to reset directly:</p>
    <a href="${resetUrl}"
       style="display:inline-block;background:#2563eb;color:#fff;padding:13px 28px;
              border-radius:8px;text-decoration:none;font-weight:600;font-size:15px;">
      Reset Password
    </a>
    <p style="margin:24px 0 0;font-size:13px;color:#94a3b8;">
      If you did not request this, you can safely ignore this email. Your password will not change.
    </p>
  `)

  await _send({
    to: toEmail,
    subject: 'AttendX — Password Reset Code',
    html,
    text: `Your AttendX password reset code is: ${resetToken}\n\nExpires in 15 minutes.\n\nReset link: ${resetUrl}\n\nIgnore this email if you did not request a reset.`,
  })
}

// ── 2. Absence warning ────────────────────────────────────────────────────────
async function sendAbsenceWarning(toEmail, { studentName, courseName, attendanceRate }) {
  const rateColor = attendanceRate < 60 ? '#dc2626' : '#d97706'

  const html = _layout('Attendance Warning', `
    <h2 style="color:#dc2626;font-size:22px;margin:0 0 8px;">&#9888;&#65039; Attendance Warning</h2>
    <p style="color:#475569;margin:0 0 20px;">Dear <strong>${studentName}</strong>,</p>
    <p style="color:#475569;margin:0 0 20px;">
      Your attendance in <strong>${courseName}</strong> has dropped below the required minimum.
    </p>
    <div style="background:#fef2f2;border:1px solid #fecaca;border-radius:10px;
                padding:20px;text-align:center;margin-bottom:24px;">
      <p style="margin:0;font-size:12px;color:#dc2626;font-weight:700;letter-spacing:1px;">
        CURRENT ATTENDANCE RATE
      </p>
      <p style="margin:6px 0;font-size:48px;font-weight:700;color:${rateColor};">${attendanceRate}%</p>
      <p style="margin:0;font-size:12px;color:#dc2626;">Minimum required: 75%</p>
    </div>
    <p style="color:#475569;margin:0 0 16px;">
      Please attend all upcoming sessions and contact your lecturer if you have extenuating circumstances.
    </p>
    <p style="color:#475569;margin:0;font-size:13px;">
      View your full attendance history in the AttendX mobile app.
    </p>
  `)

  await _send({
    to: toEmail,
    subject: `⚠️ Attendance Warning — ${courseName}`,
    html,
    text: `Dear ${studentName},\n\nYour attendance in ${courseName} is ${attendanceRate}% (minimum: 75%).\nPlease attend upcoming sessions to avoid academic penalties.\n\nAttendX`,
  })
}

// ── 3. Session started alert ──────────────────────────────────────────────────
async function sendSessionStarted(toEmail, { studentName, courseName, roomName, sessionCode, expiresAt }) {
  const html = _layout('Session Started', `
    <h2 style="color:#1e293b;font-size:22px;margin:0 0 8px;">&#128203; Session Started</h2>
    <p style="color:#475569;margin:0 0 20px;">Dear <strong>${studentName}</strong>,</p>
    <p style="color:#475569;margin:0 0 20px;">
      Your lecturer has started an attendance session for <strong>${courseName}</strong>.
    </p>
    <div style="background:#eff6ff;border:1px solid #bfdbfe;border-radius:10px;
                padding:20px 24px;margin-bottom:24px;">
      <p style="margin:0;font-size:12px;color:#1d4ed8;font-weight:700;letter-spacing:1px;">SESSION CODE</p>
      <p style="margin:6px 0;font-size:40px;font-weight:700;letter-spacing:8px;color:#1d4ed8;">${sessionCode}</p>
      <p style="margin:0;font-size:12px;color:#3b82f6;">Room: ${roomName} &nbsp;|&nbsp; Expires: ${expiresAt}</p>
    </div>
    <p style="color:#475569;margin:0;font-size:13px;">
      Open the AttendX app and scan the QR code or enter the session code above to check in.
    </p>
  `)

  await _send({
    to: toEmail,
    subject: `&#128203; Attendance Session — ${courseName}`,
    html,
    text: `Dear ${studentName},\n\n${courseName} session started.\nCode: ${sessionCode} | Room: ${roomName}\nExpires: ${expiresAt}\n\nOpen AttendX to check in.`,
  })
}

// ── 4. Appeal result ──────────────────────────────────────────────────────────
async function sendAppealResult(toEmail, { studentName, courseName, status, reviewNote }) {
  const approved    = status === 'approved'
  const headerColor = approved ? '#16a34a' : '#dc2626'
  const bgColor     = approved ? '#f0fdf4' : '#fef2f2'
  const borderColor = approved ? '#bbf7d0' : '#fecaca'
  const icon        = approved ? '✅' : '❌'
  const statusLabel = approved ? 'APPROVED' : 'REJECTED'

  const html = _layout('Appeal Decision', `
    <h2 style="color:${headerColor};font-size:22px;margin:0 0 8px;">
      ${icon} Appeal ${approved ? 'Approved' : 'Rejected'}
    </h2>
    <p style="color:#475569;margin:0 0 20px;">Dear <strong>${studentName}</strong>,</p>
    <p style="color:#475569;margin:0 0 20px;">
      Your attendance appeal for <strong>${courseName}</strong> has been reviewed.
    </p>
    <div style="background:${bgColor};border:1px solid ${borderColor};border-radius:10px;
                padding:20px 24px;margin-bottom:24px;">
      <p style="margin:0;font-size:13px;font-weight:700;color:${headerColor};letter-spacing:0.5px;">
        DECISION: ${statusLabel}
      </p>
      ${reviewNote ? `<p style="margin:10px 0 0;color:#475569;font-size:14px;">${reviewNote}</p>` : ''}
    </div>
    ${approved
      ? `<p style="color:#475569;margin:0;">Your attendance record has been updated to <strong>Present</strong>. This is reflected in your app.</p>`
      : `<p style="color:#475569;margin:0;">If you believe this is incorrect, contact your lecturer or academic advisor.</p>`
    }
  `)

  await _send({
    to: toEmail,
    subject: `${icon} Appeal ${approved ? 'Approved' : 'Rejected'} — ${courseName}`,
    html,
    text: `Dear ${studentName},\n\nYour appeal for ${courseName} was ${status}.\n${reviewNote ? `Note: ${reviewNote}` : ''}\n\nAttendX`,
  })
}

// ── 5. Weekly attendance digest ───────────────────────────────────────────────
async function sendWeeklyDigest(toEmail, { studentName, overallRate, courses }) {
  const rateColor = overallRate >= 80 ? '#16a34a' : overallRate >= 75 ? '#d97706' : '#dc2626'

  const courseRows = (courses || []).map(c => {
    const cr    = Number(c.rate ?? 0)
    const crCol = cr >= 80 ? '#16a34a' : cr >= 75 ? '#d97706' : '#dc2626'
    return `<tr style="border-bottom:1px solid #e2e8f0;">
      <td style="padding:10px 12px;font-size:13px;color:#1e293b;">${c.code}</td>
      <td style="padding:10px 12px;font-size:13px;color:#475569;">${c.name}</td>
      <td style="padding:10px 12px;font-size:13px;font-weight:700;color:${crCol};text-align:right;">${cr}%</td>
    </tr>`
  }).join('')

  const html = _layout('Weekly Attendance Summary', `
    <h2 style="color:#1e293b;font-size:22px;margin:0 0 8px;">&#128202; Weekly Summary</h2>
    <p style="color:#475569;margin:0 0 20px;">
      Hi <strong>${studentName}</strong>, here is your attendance report for this week.
    </p>
    <div style="background:#eff6ff;border-radius:10px;padding:20px;text-align:center;margin-bottom:24px;">
      <p style="margin:0;font-size:12px;color:#1d4ed8;font-weight:700;letter-spacing:1px;">OVERALL RATE</p>
      <p style="margin:6px 0;font-size:48px;font-weight:700;color:${rateColor};">${overallRate}%</p>
      <p style="margin:0;font-size:12px;color:#3b82f6;">Minimum required: 75%</p>
    </div>
    ${courseRows
      ? `<table width="100%" cellpadding="0" cellspacing="0"
               style="border-collapse:collapse;border:1px solid #e2e8f0;border-radius:8px;overflow:hidden;">
           <thead>
             <tr style="background:#f8fafc;">
               <th style="padding:10px 12px;text-align:left;font-size:11px;color:#64748b;font-weight:700;">CODE</th>
               <th style="padding:10px 12px;text-align:left;font-size:11px;color:#64748b;font-weight:700;">COURSE</th>
               <th style="padding:10px 12px;text-align:right;font-size:11px;color:#64748b;font-weight:700;">RATE</th>
             </tr>
           </thead>
           <tbody>${courseRows}</tbody>
         </table>`
      : `<p style="color:#94a3b8;font-size:13px;text-align:center;">No sessions recorded this week.</p>`
    }
    <p style="margin:20px 0 0;font-size:13px;color:#94a3b8;">
      Open the AttendX app to view your full history and analytics.
    </p>
  `)

  const weekLabel = new Date().toLocaleDateString('en-GB', { month: 'short', day: 'numeric' })
  await _send({
    to: toEmail,
    subject: `&#128202; Weekly Attendance Summary — ${weekLabel}`,
    html,
    text: `Hi ${studentName},\n\nOverall: ${overallRate}%\n\n${(courses || []).map(c => `${c.code}: ${c.rate}%`).join('\n')}\n\nAttendX`,
  })
}

module.exports = {
  sendPasswordReset,
  sendAbsenceWarning,
  sendSessionStarted,
  sendAppealResult,
  sendWeeklyDigest,
}
