const PptxGenJS = require('pptxgenjs');
const path = require('path');

const pptx = new PptxGenJS();
pptx.layout = 'LAYOUT_WIDE';
pptx.title  = 'AttendX — Smart Attendance Management System';
pptx.author = 'AttendX Team';

// ── Colour palette ─────────────────────────────────────────────────────────
const C = {
  blue:       '1E88E5',
  darkBlue:   '0D47A1',
  navy:       '0A1628',
  white:      'FFFFFF',
  lightGray:  'F1F5F9',
  medGray:    '94A3B8',
  darkGray:   '334155',
  green:      '10B981',
  orange:     'F59E0B',
  red:        'EF4444',
  accent:     '38BDF8',
};

// ── Helper: add a full-bleed gradient background ───────────────────────────
function darkBg(slide) {
  slide.addShape(pptx.ShapeType.rect, {
    x: 0, y: 0, w: '100%', h: '100%',
    fill: { type: 'solid', color: C.navy },
  });
}

// ── Helper: section label chip ──────────────────────────────────────────────
function chip(slide, text, x, y, color = C.blue) {
  slide.addShape(pptx.ShapeType.roundRect, {
    x, y, w: 1.8, h: 0.3, rectRadius: 0.08,
    fill: { type: 'solid', color },
    line: { color, width: 0 },
  });
  slide.addText(text, {
    x, y, w: 1.8, h: 0.3,
    fontSize: 9, bold: true, color: C.white,
    align: 'center', valign: 'middle',
  });
}

// ── Helper: bullet list ──────────────────────────────────────────────────────
function bullets(slide, items, x, y, w, h, fontSize = 13) {
  const rows = items.map(t => ([{
    text: '  ' + t,
    options: { bullet: { type: 'bullet', characterCode: '25CF', color: C.accent }, color: 'E2E8F0', fontSize, breakLine: true },
  }]));
  items.forEach((t, i) => {
    slide.addText('● ' + t, {
      x, y: y + i * (h / items.length), w, h: h / items.length,
      fontSize, color: 'CBD5E1', valign: 'middle',
    });
  });
}

// ── Helper: stat box ─────────────────────────────────────────────────────────
function statBox(slide, icon, value, label, x, y, color = C.blue) {
  slide.addShape(pptx.ShapeType.roundRect, {
    x, y, w: 2.8, h: 1.4, rectRadius: 0.12,
    fill: { type: 'solid', color: '0F2440' },
    line: { color, width: 1.5 },
  });
  slide.addText(icon, { x, y: y + 0.1, w: 2.8, h: 0.5, fontSize: 22, align: 'center' });
  slide.addText(value, {
    x, y: y + 0.55, w: 2.8, h: 0.4,
    fontSize: 18, bold: true, color, align: 'center',
  });
  slide.addText(label, {
    x, y: y + 0.95, w: 2.8, h: 0.35,
    fontSize: 10, color: C.medGray, align: 'center',
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// SLIDE 1 — TITLE
// ═══════════════════════════════════════════════════════════════════════════
{
  const s = pptx.addSlide();
  darkBg(s);

  // Blue accent bar top
  s.addShape(pptx.ShapeType.rect, { x: 0, y: 0, w: '100%', h: 0.06, fill: { color: C.blue } });

  // Glow circle
  s.addShape(pptx.ShapeType.ellipse, {
    x: 4.5, y: 0.4, w: 4.4, h: 4.4,
    fill: { type: 'solid', color: '0D2550' },
    line: { color: C.blue, width: 1, dashType: 'dash' },
  });

  // Logo icon area
  s.addShape(pptx.ShapeType.ellipse, {
    x: 5.4, y: 1.0, w: 2.5, h: 2.5,
    fill: { type: 'solid', color: C.blue },
  });
  s.addText('🎓', { x: 5.4, y: 1.15, w: 2.5, h: 2.2, fontSize: 48, align: 'center', valign: 'middle' });

  // Title text
  s.addText('AttendX', {
    x: 0.5, y: 1.2, w: 4.5, h: 1.0,
    fontSize: 52, bold: true, color: C.white,
    fontFace: 'Calibri',
  });
  s.addShape(pptx.ShapeType.rect, { x: 0.5, y: 2.2, w: 3.8, h: 0.06, fill: { color: C.blue } });
  s.addText('Smart Attendance Management System', {
    x: 0.5, y: 2.35, w: 4.5, h: 0.5,
    fontSize: 17, color: C.accent, italic: true,
  });
  s.addText('Intelligent GPS-based attendance for modern education', {
    x: 0.5, y: 2.9, w: 4.5, h: 0.4,
    fontSize: 12, color: C.medGray,
  });

  // Platforms
  const platforms = ['Admin Web Panel', 'Lecturer Web Panel', 'Student Mobile App'];
  platforms.forEach((p, i) => {
    s.addShape(pptx.ShapeType.roundRect, {
      x: 0.5 + i * 2.5, y: 3.55, w: 2.3, h: 0.38, rectRadius: 0.08,
      fill: { color: '0D2550' }, line: { color: C.blue, width: 1 },
    });
    s.addText(p, {
      x: 0.5 + i * 2.5, y: 3.55, w: 2.3, h: 0.38,
      fontSize: 10, color: C.white, align: 'center', valign: 'middle',
    });
  });

  // Tech badges row
  const techs = ['Node.js', 'React', 'Flutter', 'MySQL', 'Socket.io', 'Firebase', 'Twilio'];
  techs.forEach((t, i) => {
    s.addShape(pptx.ShapeType.roundRect, {
      x: 0.4 + i * 1.55, y: 4.2, w: 1.4, h: 0.28, rectRadius: 0.06,
      fill: { color: '162032' }, line: { color: C.accent, width: 0.5 },
    });
    s.addText(t, {
      x: 0.4 + i * 1.55, y: 4.2, w: 1.4, h: 0.28,
      fontSize: 9, color: C.accent, align: 'center', valign: 'middle',
    });
  });

  // Bottom bar
  s.addShape(pptx.ShapeType.rect, { x: 0, y: 4.9, w: '100%', h: 0.45, fill: { color: '0D2550' } });
  s.addText('University of Rwanda  ·  2025  ·  AttendX Team', {
    x: 0, y: 4.9, w: '100%', h: 0.45,
    fontSize: 10, color: C.medGray, align: 'center', valign: 'middle',
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// SLIDE 2 — THE PROBLEM
// ═══════════════════════════════════════════════════════════════════════════
{
  const s = pptx.addSlide();
  darkBg(s);
  s.addShape(pptx.ShapeType.rect, { x: 0, y: 0, w: '100%', h: 0.06, fill: { color: C.red } });

  chip(s, '⚠  PROBLEM STATEMENT', 0.5, 0.18, C.red);
  s.addText('The Problem We Solve', {
    x: 0.5, y: 0.55, w: 12, h: 0.65,
    fontSize: 32, bold: true, color: C.white,
  });

  const problems = [
    ['📋', 'Paper Registers', 'Manual registers are slow, error-prone and easily forged by students'],
    ['⏱', 'Wasted Class Time', 'Lecturers spend 5–10 minutes per class just taking attendance'],
    ['🤝', 'Proxy Attendance', 'Students sign for absent classmates — no way to verify presence'],
    ['📊', 'No Real-time Data', 'Admin sees attendance data days later, never in the moment'],
    ['🚨', 'No Early Warnings', 'Low-attendance students get no alert until it is already too late'],
  ];

  problems.forEach(([icon, title, desc], i) => {
    const x = 0.4 + (i % 3) * 4.45;
    const y = i < 3 ? 1.4 : 2.9;
    s.addShape(pptx.ShapeType.roundRect, {
      x, y, w: 4.1, h: 1.3, rectRadius: 0.12,
      fill: { color: '1A0A0A' }, line: { color: C.red, width: 1 },
    });
    s.addText(icon, { x, y: y + 0.1, w: 4.1, h: 0.45, fontSize: 20, align: 'center' });
    s.addText(title, {
      x, y: y + 0.48, w: 4.1, h: 0.3,
      fontSize: 13, bold: true, color: C.white, align: 'center',
    });
    s.addText(desc, {
      x: x + 0.15, y: y + 0.76, w: 3.8, h: 0.45,
      fontSize: 9.5, color: C.medGray, align: 'center',
    });
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// SLIDE 3 — OUR SOLUTION
// ═══════════════════════════════════════════════════════════════════════════
{
  const s = pptx.addSlide();
  darkBg(s);
  s.addShape(pptx.ShapeType.rect, { x: 0, y: 0, w: '100%', h: 0.06, fill: { color: C.green } });

  chip(s, '✅  SOLUTION', 0.5, 0.18, C.green);
  s.addText('Our Solution: AttendX', {
    x: 0.5, y: 0.55, w: 12, h: 0.65,
    fontSize: 32, bold: true, color: C.white,
  });

  const solutions = [
    ['📍', 'GPS Geofence', 'Students must be physically inside the classroom to check in'],
    ['🔑', 'Session Code', 'Unique 6-character code required on every single check-in'],
    ['⚡', 'One-Click Sessions', 'Lecturer starts & closes sessions from a web dashboard instantly'],
    ['📈', 'Live Analytics', 'Admin sees real-time rates, trends and at-risk students immediately'],
    ['📱', 'Push + SMS Alerts', 'Automated warnings sent via FCM push notification AND Twilio SMS'],
  ];

  solutions.forEach(([icon, title, desc], i) => {
    const x = 0.4 + (i % 3) * 4.45;
    const y = i < 3 ? 1.4 : 2.9;
    s.addShape(pptx.ShapeType.roundRect, {
      x, y, w: 4.1, h: 1.3, rectRadius: 0.12,
      fill: { color: '071A0A' }, line: { color: C.green, width: 1 },
    });
    s.addText(icon, { x, y: y + 0.1, w: 4.1, h: 0.45, fontSize: 20, align: 'center' });
    s.addText(title, {
      x, y: y + 0.48, w: 4.1, h: 0.3,
      fontSize: 13, bold: true, color: C.white, align: 'center',
    });
    s.addText(desc, {
      x: x + 0.15, y: y + 0.76, w: 3.8, h: 0.45,
      fontSize: 9.5, color: C.medGray, align: 'center',
    });
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// SLIDE 4 — SYSTEM ARCHITECTURE
// ═══════════════════════════════════════════════════════════════════════════
{
  const s = pptx.addSlide();
  darkBg(s);
  s.addShape(pptx.ShapeType.rect, { x: 0, y: 0, w: '100%', h: 0.06, fill: { color: C.accent } });

  chip(s, '🏗  ARCHITECTURE', 0.5, 0.18, C.blue);
  s.addText('System Architecture', {
    x: 0.5, y: 0.55, w: 12, h: 0.55, fontSize: 32, bold: true, color: C.white,
  });

  // Three tier boxes
  const tiers = [
    { label: 'CLIENT TIER', items: ['Admin React SPA', 'Lecturer React SPA', 'Student Flutter App'], color: C.blue, x: 0.4 },
    { label: 'API TIER', items: ['Node.js + Express 5', 'Socket.io (real-time)', 'JWT Auth + Middleware'], color: C.accent, x: 4.85 },
    { label: 'DATA TIER', items: ['MySQL 8 Database', 'Firebase Admin SDK', 'Twilio + Nodemailer'], color: C.green, x: 9.3 },
  ];

  tiers.forEach(({ label, items, color, x }) => {
    s.addShape(pptx.ShapeType.roundRect, {
      x, y: 1.35, w: 4.1, h: 2.9, rectRadius: 0.14,
      fill: { color: '0A1A30' }, line: { color, width: 1.5 },
    });
    s.addShape(pptx.ShapeType.rect, {
      x, y: 1.35, w: 4.1, h: 0.42,
      fill: { color }, line: { color, width: 0 },
    });
    s.addText(label, {
      x, y: 1.35, w: 4.1, h: 0.42,
      fontSize: 11, bold: true, color: C.white, align: 'center', valign: 'middle',
    });
    items.forEach((item, i) => {
      s.addText('▸  ' + item, {
        x: x + 0.2, y: 1.9 + i * 0.55, w: 3.7, h: 0.45,
        fontSize: 12, color: 'CBD5E1',
      });
    });
  });

  // Arrows between tiers
  s.addText('⟷', { x: 4.5, y: 2.5, w: 0.5, h: 0.5, fontSize: 22, color: C.accent, align: 'center' });
  s.addText('⟷', { x: 8.95, y: 2.5, w: 0.5, h: 0.5, fontSize: 22, color: C.accent, align: 'center' });

  // Bottom row
  const brows = ['bcrypt Passwords', 'Rate Limiting', 'Helmet Headers', 'Role-enforced JWT', 'CORS Restricted'];
  s.addText('Security Layer:', { x: 0.4, y: 4.4, w: 2.0, h: 0.3, fontSize: 10, bold: true, color: C.orange });
  brows.forEach((b, i) => {
    s.addShape(pptx.ShapeType.roundRect, {
      x: 2.3 + i * 2.25, y: 4.38, w: 2.1, h: 0.3, rectRadius: 0.06,
      fill: { color: '1A1000' }, line: { color: C.orange, width: 0.5 },
    });
    s.addText('🔒 ' + b, {
      x: 2.3 + i * 2.25, y: 4.38, w: 2.1, h: 0.3,
      fontSize: 9, color: C.orange, align: 'center', valign: 'middle',
    });
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// SLIDE 5 — ADMIN PANEL
// ═══════════════════════════════════════════════════════════════════════════
{
  const s = pptx.addSlide();
  darkBg(s);
  s.addShape(pptx.ShapeType.rect, { x: 0, y: 0, w: '100%', h: 0.06, fill: { color: C.orange } });

  chip(s, '👤  ADMIN PANEL', 0.5, 0.18, C.orange);
  s.addText('Admin Panel', {
    x: 0.5, y: 0.55, w: 8, h: 0.55, fontSize: 32, bold: true, color: C.white,
  });
  s.addText('Full control over users, courses, classrooms and analytics', {
    x: 0.5, y: 1.12, w: 8, h: 0.35, fontSize: 13, color: C.medGray,
  });

  const features = [
    ['👥', 'User Management', 'Create, update, deactivate students & lecturers. Bulk CSV import with auto password.'],
    ['📚', 'Course Management', 'Create courses, assign lecturers, track enrollment counts per course.'],
    ['🏫', 'Classroom Management', 'GPS coordinates + configurable geofence radius per classroom.'],
    ['📊', 'Live Analytics', 'Overall rate, weekly trend chart, at-risk students table, per-course bar chart.'],
  ];

  features.forEach(([icon, title, desc], i) => {
    const x = i % 2 === 0 ? 0.4 : 7.0;
    const y = 1.6 + Math.floor(i / 2) * 1.65;
    s.addShape(pptx.ShapeType.roundRect, {
      x, y, w: 6.2, h: 1.45, rectRadius: 0.12,
      fill: { color: '1A0F00' }, line: { color: C.orange, width: 1 },
    });
    s.addText(icon + '  ' + title, {
      x: x + 0.2, y: y + 0.12, w: 5.8, h: 0.38,
      fontSize: 14, bold: true, color: C.white,
    });
    s.addText(desc, {
      x: x + 0.2, y: y + 0.52, w: 5.8, h: 0.75,
      fontSize: 11, color: C.medGray,
    });
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// SLIDE 6 — LECTURER PANEL
// ═══════════════════════════════════════════════════════════════════════════
{
  const s = pptx.addSlide();
  darkBg(s);
  s.addShape(pptx.ShapeType.rect, { x: 0, y: 0, w: '100%', h: 0.06, fill: { color: C.accent } });

  chip(s, '🎓  LECTURER PANEL', 0.5, 0.18, C.blue);
  s.addText('Lecturer Panel', {
    x: 0.5, y: 0.55, w: 8, h: 0.55, fontSize: 32, bold: true, color: C.white,
  });
  s.addText('Start sessions, monitor check-ins live, manage students & reports', {
    x: 0.5, y: 1.12, w: 8, h: 0.35, fontSize: 13, color: C.medGray,
  });

  const features = [
    ['⚡', 'One-Click Sessions', 'Choose course + classroom, get a 6-character session code instantly.'],
    ['📡', 'Live Monitor', 'Real-time check-in feed via Socket.io — watch students arrive live.'],
    ['🔔', 'Absent Alerts', 'Absent list updates live. Send individual or bulk push + SMS reminders.'],
    ['📋', 'Reports & Export', 'Attendance bar chart, CSV export, per-student warning system.'],
  ];

  features.forEach(([icon, title, desc], i) => {
    const x = i % 2 === 0 ? 0.4 : 7.0;
    const y = 1.6 + Math.floor(i / 2) * 1.65;
    s.addShape(pptx.ShapeType.roundRect, {
      x, y, w: 6.2, h: 1.45, rectRadius: 0.12,
      fill: { color: '050F1A' }, line: { color: C.accent, width: 1 },
    });
    s.addText(icon + '  ' + title, {
      x: x + 0.2, y: y + 0.12, w: 5.8, h: 0.38,
      fontSize: 14, bold: true, color: C.white,
    });
    s.addText(desc, {
      x: x + 0.2, y: y + 0.52, w: 5.8, h: 0.75,
      fontSize: 11, color: C.medGray,
    });
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// SLIDE 7 — STUDENT MOBILE APP
// ═══════════════════════════════════════════════════════════════════════════
{
  const s = pptx.addSlide();
  darkBg(s);
  s.addShape(pptx.ShapeType.rect, { x: 0, y: 0, w: '100%', h: 0.06, fill: { color: C.green } });

  chip(s, '📱  STUDENT APP', 0.5, 0.18, C.green);
  s.addText('Student Mobile App', {
    x: 0.5, y: 0.55, w: 8, h: 0.55, fontSize: 32, bold: true, color: C.white,
  });
  s.addText('Flutter app — GPS check-in, calendar history, analytics, profile', {
    x: 0.5, y: 1.12, w: 8, h: 0.35, fontSize: 13, color: C.medGray,
  });

  const screens = [
    ['🏠', 'Dashboard', 'Today\'s sessions, overall attendance ring, enrolled courses count.'],
    ['📍', 'GPS Check-in', 'Geofence validation + 6-char code confirms physical presence.'],
    ['📅', 'History', 'Calendar with green/red dots per day. Filter by course.'],
    ['📈', 'Analytics', 'Per-course breakdown, streak tracker, at-risk alert banners.'],
    ['👤', 'Profile', 'Live data from /auth/me. Notification prefs. Password reset.'],
    ['🔔', 'Notifications', 'FCM push for sessions, absences & confirmations.'],
  ];

  screens.forEach(([icon, title, desc], i) => {
    const col = i % 3;
    const row = Math.floor(i / 3);
    const x = 0.4 + col * 4.45;
    const y = 1.6 + row * 1.55;
    s.addShape(pptx.ShapeType.roundRect, {
      x, y, w: 4.1, h: 1.35, rectRadius: 0.12,
      fill: { color: '071A0A' }, line: { color: C.green, width: 1 },
    });
    s.addText(icon + '  ' + title, {
      x: x + 0.15, y: y + 0.1, w: 3.8, h: 0.38,
      fontSize: 13, bold: true, color: C.white,
    });
    s.addText(desc, {
      x: x + 0.15, y: y + 0.5, w: 3.8, h: 0.7,
      fontSize: 10.5, color: C.medGray,
    });
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// SLIDE 8 — REAL-TIME & NOTIFICATIONS
// ═══════════════════════════════════════════════════════════════════════════
{
  const s = pptx.addSlide();
  darkBg(s);
  s.addShape(pptx.ShapeType.rect, { x: 0, y: 0, w: '100%', h: 0.06, fill: { color: C.accent } });

  chip(s, '⚡  REAL-TIME', 0.5, 0.18, C.blue);
  s.addText('Real-Time & Notifications', {
    x: 0.5, y: 0.55, w: 12, h: 0.55, fontSize: 32, bold: true, color: C.white,
  });

  const items = [
    { icon: '🔌', title: 'Socket.io Rooms', desc: 'Lecturers join session:{id} · Students join course:{id} · Events routed per room', color: C.accent },
    { icon: '📡', title: 'Session Started Event', desc: 'All enrolled students receive instant socket event when lecturer starts class', color: C.blue },
    { icon: '🔔', title: 'Firebase Cloud Messaging', desc: 'Push notifications for session start, absence recorded & attendance confirmed', color: C.orange },
    { icon: '📱', title: 'Twilio SMS Fallback', desc: 'Students without the app get SMS alerts · Rwanda +250 formatting built-in', color: C.green },
    { icon: '📨', title: 'Nodemailer Email', desc: 'SMTP password reset emails with styled HTML template via Gmail', color: C.red },
    { icon: '⚙️', title: 'Bulk Async Delivery', desc: 'Bulk warnings queued in background — no HTTP timeout for large classes', color: C.medGray },
  ];

  items.forEach(({ icon, title, desc, color }, i) => {
    const col = i % 3, row = Math.floor(i / 3);
    const x = 0.4 + col * 4.45, y = 1.35 + row * 1.65;
    s.addShape(pptx.ShapeType.roundRect, {
      x, y, w: 4.1, h: 1.45, rectRadius: 0.12,
      fill: { color: '080E1A' }, line: { color, width: 1 },
    });
    s.addText(icon + '  ' + title, {
      x: x + 0.15, y: y + 0.1, w: 3.8, h: 0.38,
      fontSize: 12, bold: true, color,
    });
    s.addText(desc, {
      x: x + 0.15, y: y + 0.5, w: 3.8, h: 0.82,
      fontSize: 10.5, color: C.medGray,
    });
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// SLIDE 9 — SECURITY HIGHLIGHTS
// ═══════════════════════════════════════════════════════════════════════════
{
  const s = pptx.addSlide();
  darkBg(s);
  s.addShape(pptx.ShapeType.rect, { x: 0, y: 0, w: '100%', h: 0.06, fill: { color: C.orange } });

  chip(s, '🔒  SECURITY', 0.5, 0.18, C.orange);
  s.addText('Security Highlights', {
    x: 0.5, y: 0.55, w: 12, h: 0.55, fontSize: 32, bold: true, color: C.white,
  });

  const secItems = [
    ['🎭', 'Role-Enforced Login', 'admin, lecturer and student roles validated server-side on every login — cross-role access blocked'],
    ['🔑', 'JWT Token Pair', 'Access token (1h) + Refresh token (7d) · Refresh stored as bcrypt hash in database'],
    ['🔄', 'Silent Token Refresh', 'All three clients (Admin, Lecturer, Student) auto-refresh on 401 without logging out'],
    ['📍', 'Two-Factor Presence', 'GPS geofence + session code together = physical presence verified on every check-in'],
    ['🛡', 'HTTP Security', 'Rate limiting on auth routes · Helmet headers · CORS restricted to whitelisted origins'],
    ['🚪', 'Protected Warning Routes', 'Authentication + role middleware on all notification endpoints — no open access'],
  ];

  secItems.forEach(([icon, title, desc], i) => {
    const col = i % 2, row = Math.floor(i / 2);
    const x = 0.4 + col * 6.8, y = 1.4 + row * 1.2;
    s.addShape(pptx.ShapeType.roundRect, {
      x, y, w: 6.4, h: 1.05, rectRadius: 0.1,
      fill: { color: '1A0F00' }, line: { color: C.orange, width: 1 },
    });
    s.addText(icon + '  ' + title, {
      x: x + 0.2, y: y + 0.08, w: 6.0, h: 0.32,
      fontSize: 13, bold: true, color: C.white,
    });
    s.addText(desc, {
      x: x + 0.2, y: y + 0.42, w: 6.0, h: 0.55,
      fontSize: 10.5, color: C.medGray,
    });
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// SLIDE 10 — TECH STACK
// ═══════════════════════════════════════════════════════════════════════════
{
  const s = pptx.addSlide();
  darkBg(s);
  s.addShape(pptx.ShapeType.rect, { x: 0, y: 0, w: '100%', h: 0.06, fill: { color: C.blue } });

  chip(s, '⚙️  TECH STACK', 0.5, 0.18, C.blue);
  s.addText('Tech Stack', {
    x: 0.5, y: 0.55, w: 12, h: 0.55, fontSize: 32, bold: true, color: C.white,
  });

  const stacks = [
    {
      title: '🖥  Backend', color: C.blue,
      items: ['Node.js 24  ·  Express 5', 'MySQL 8  ·  Socket.io 4', 'Firebase Admin  ·  Twilio', 'Nodemailer  ·  bcrypt  ·  JWT'],
    },
    {
      title: '🌐  Admin & Lecturer', color: C.accent,
      items: ['React 18  ·  Vite', 'Tailwind CSS  ·  Recharts', 'Axios  ·  JWT refresh', 'Token auto-refresh on 401'],
    },
    {
      title: '📱  Student App', color: C.green,
      items: ['Flutter 3  ·  Dart', 'Riverpod  ·  Dio', 'Geolocator  ·  FCM', 'table_calendar  ·  fl_chart'],
    },
    {
      title: '🔧  Infrastructure', color: C.orange,
      items: ['pnpm monorepo', 'express-validator', 'Helmet  ·  Morgan', 'express-rate-limit'],
    },
  ];

  stacks.forEach(({ title, color, items }, i) => {
    const x = 0.4 + i * 3.3, y = 1.35;
    s.addShape(pptx.ShapeType.roundRect, {
      x, y, w: 3.1, h: 3.0, rectRadius: 0.12,
      fill: { color: '08131F' }, line: { color, width: 1.5 },
    });
    s.addShape(pptx.ShapeType.rect, {
      x, y, w: 3.1, h: 0.45,
      fill: { color }, line: { color, width: 0 },
    });
    s.addText(title, {
      x, y, w: 3.1, h: 0.45,
      fontSize: 12, bold: true, color: C.white, align: 'center', valign: 'middle',
    });
    items.forEach((item, j) => {
      s.addText('▸  ' + item, {
        x: x + 0.15, y: y + 0.55 + j * 0.55, w: 2.8, h: 0.48,
        fontSize: 11, color: 'CBD5E1',
      });
    });
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// SLIDE 11 — KEY IMPACT METRICS
// ═══════════════════════════════════════════════════════════════════════════
{
  const s = pptx.addSlide();
  darkBg(s);
  s.addShape(pptx.ShapeType.rect, { x: 0, y: 0, w: '100%', h: 0.06, fill: { color: C.green } });

  chip(s, '📊  IMPACT', 0.5, 0.18, C.green);
  s.addText('Key Impact Metrics', {
    x: 0.5, y: 0.55, w: 12, h: 0.55, fontSize: 32, bold: true, color: C.white,
  });

  const metrics = [
    { icon: '⏱', value: '< 30s', label: 'Check-in Time', sub: 'vs 5–10 min manually', color: C.green },
    { icon: '🚫', value: '100%', label: 'Proxy Eliminated', sub: 'GPS + code = physical proof', color: C.red },
    { icon: '⚡', value: 'Real-time', label: 'Admin Visibility', sub: 'Live across all courses', color: C.accent },
    { icon: '📱', value: 'Seconds', label: 'Warning Delivery', sub: 'Push + SMS after session close', color: C.orange },
    { icon: '📋', value: '1+ hr/week', label: 'Lecturer Time Saved', sub: 'No manual register processing', color: C.blue },
    { icon: '🎯', value: '75%', label: 'At-Risk Threshold', sub: 'Auto-detected and alerted', color: C.orange },
  ];

  metrics.forEach(({ icon, value, label, sub, color }, i) => {
    const col = i % 3, row = Math.floor(i / 3);
    const x = 0.4 + col * 4.45, y = 1.35 + row * 1.75;
    s.addShape(pptx.ShapeType.roundRect, {
      x, y, w: 4.1, h: 1.5, rectRadius: 0.14,
      fill: { color: '080E1A' }, line: { color, width: 1.5 },
    });
    s.addText(icon, { x, y: y + 0.1, w: 4.1, h: 0.42, fontSize: 20, align: 'center' });
    s.addText(value, {
      x, y: y + 0.5, w: 4.1, h: 0.38,
      fontSize: 18, bold: true, color, align: 'center',
    });
    s.addText(label, {
      x, y: y + 0.86, w: 4.1, h: 0.28,
      fontSize: 11, bold: true, color: C.white, align: 'center',
    });
    s.addText(sub, {
      x, y: y + 1.14, w: 4.1, h: 0.28,
      fontSize: 9.5, color: C.medGray, align: 'center',
    });
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// SLIDE 12 — ROADMAP
// ═══════════════════════════════════════════════════════════════════════════
{
  const s = pptx.addSlide();
  darkBg(s);
  s.addShape(pptx.ShapeType.rect, { x: 0, y: 0, w: '100%', h: 0.06, fill: { color: C.blue } });

  chip(s, '🗺  ROADMAP', 0.5, 0.18, C.blue);
  s.addText('Roadmap — What Is Next', {
    x: 0.5, y: 0.55, w: 12, h: 0.55, fontSize: 32, bold: true, color: C.white,
  });

  const roadmap = [
    { icon: '📷', title: 'QR Code Check-in', desc: 'Scan instead of type the session code', status: 'Planned', color: C.accent },
    { icon: '✏️', title: 'Manual Attendance', desc: 'Lecturer marks a student present after the fact', status: 'Planned', color: C.accent },
    { icon: '⏰', title: 'Session Auto-close', desc: 'Cron job closes sessions when expires_at is reached', status: 'Planned', color: C.orange },
    { icon: '📧', title: 'Weekly Reports', desc: 'Automated Sunday attendance summary per student', status: 'Planned', color: C.orange },
    { icon: '📅', title: 'Semester Filtering', desc: 'Analytics filtered by academic period / semester', status: 'Future', color: C.medGray },
    { icon: '📄', title: 'PDF Export', desc: 'Formal attendance report for administration', status: 'Future', color: C.medGray },
    { icon: '🔕', title: 'Notification Prefs', desc: 'Respect per-student alert opt-outs server-side', status: 'Future', color: C.medGray },
  ];

  roadmap.forEach(({ icon, title, desc, status, color }, i) => {
    const col = i % 4, row = Math.floor(i / 4);
    const x = 0.35 + col * 3.35, y = 1.45 + row * 1.55;
    if (i >= 4) { /* second row */ }
    const xf = i < 4 ? 0.35 + i * 3.35 : 0.35 + (i - 4) * 3.35 + 1.6;
    const yf = i < 4 ? 1.45 : 3.1;
    s.addShape(pptx.ShapeType.roundRect, {
      x: xf, y: yf, w: 3.1, h: 1.35, rectRadius: 0.1,
      fill: { color: '08131F' }, line: { color, width: 1 },
    });
    s.addShape(pptx.ShapeType.roundRect, {
      x: xf + 1.95, y: yf + 0.08, w: 0.95, h: 0.25, rectRadius: 0.06,
      fill: { color: status === 'Planned' ? '0D2550' : '1A1A1A' },
      line: { color: status === 'Planned' ? C.accent : C.medGray, width: 0.5 },
    });
    s.addText(status, {
      x: xf + 1.95, y: yf + 0.08, w: 0.95, h: 0.25,
      fontSize: 8, color: status === 'Planned' ? C.accent : C.medGray,
      align: 'center', valign: 'middle',
    });
    s.addText(icon + '  ' + title, {
      x: xf + 0.12, y: yf + 0.08, w: 1.85, h: 0.38,
      fontSize: 11, bold: true, color: C.white,
    });
    s.addText(desc, {
      x: xf + 0.12, y: yf + 0.5, w: 2.86, h: 0.7,
      fontSize: 10, color: C.medGray,
    });
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// SAVE
// ═══════════════════════════════════════════════════════════════════════════
const outputPath = path.join(__dirname, '..', '..', '..', 'attendx', 'AttendX_Presentation.pptx');

pptx.writeFile({ fileName: outputPath })
  .then(() => console.log('✅ Saved:', outputPath))
  .catch(e => console.error('❌ Error:', e.message));
