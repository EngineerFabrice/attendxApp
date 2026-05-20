require("dotenv").config();

// -- Production safety checks --------------------------------------------------
if (process.env.NODE_ENV === "production") {
  if (!process.env.JWT_SECRET || process.env.JWT_SECRET === "dev_secret") {
    console.error("FATAL: JWT_SECRET must be set in production");
    process.exit(1);
  }
  if (
    !process.env.JWT_REFRESH_SECRET ||
    process.env.JWT_REFRESH_SECRET === "dev_refresh_secret"
  ) {
    console.error("FATAL: JWT_REFRESH_SECRET must be set in production");
    process.exit(1);
  }
}

const express   = require("express");
const http      = require("http");
const { Server } = require("socket.io");
const cron      = require("node-cron");
const { version: API_VERSION } = require('./package.json');
const cors = require("cors");
const helmet = require("helmet");
const morgan = require("morgan");

const { testConnection } = require("./src/config/database");
const { initSocket } = require("./src/socket/socket.handler");
const { errorHandler } = require("./src/middleware/errorHandler");
const { generalLimiter, authLimiter } = require("./src/middleware/rateLimiter");
const vpnGuard   = require("./src/middleware/vpn-guard");
const notify     = require("./src/services/notification.service");

const authRoutes     = require("./src/routes/auth.routes");
const adminRoutes    = require("./src/routes/admin.routes");
const lecturerRoutes = require("./src/routes/lecturer.routes");
const studentRoutes  = require("./src/routes/student.routes");
const warningRoutes  = require("./src/routes/warningRoutes");
const appealRoutes   = require("./src/routes/appeal.routes");
const messageRoutes  = require("./src/routes/message.routes");

const app = express();
const server = http.createServer(app);

// -- Allowed origins -----------------------------------------------------------
const corsOrigins = process.env.CORS_ORIGIN
  ? process.env.CORS_ORIGIN.split(",")
  : [
      "http://localhost:5173",
      "http://localhost:3000",
      "http://localhost:5000",
      "http://127.0.0.1:5173",
      "http://127.0.0.1:5000",
      "http://172.17.254.84:5173",
      "http://172.17.254.84:5000",
    ];

console.log("CORS allowed origins:", corsOrigins);

// -- Socket.io -----------------------------------------------------------------
const io = new Server(server, {
  cors: {
    origin: corsOrigins,
    methods: ["GET", "POST"],
    credentials: true,
  },
});
initSocket(io);
app.set("io", io);

// -- Middleware ----------------------------------------------------------------
app.use(helmet({ contentSecurityPolicy: false }));
app.use(express.urlencoded({ extended: true })); 
app.use(express.json()); 
// CORS middleware - FIXED
app.use(
  cors({
    origin: function (origin, callback) {
      // Allow requests with no origin (mobile apps, Postman, curl)
      if (!origin) {
        return callback(null, true);
      }

      // Allow all origins in development (temporarily for testing)
      if (process.env.NODE_ENV !== "production") {
        return callback(null, true);
      }

      // Production: check against allowed origins
      if (corsOrigins.includes(origin)) {
        callback(null, true);
      } else {
        console.warn(`CORS blocked origin: ${origin}`);
        callback(new Error("CORS blocked: origin not allowed"));
      }
    },
    credentials: true,
    methods: ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
    allowedHeaders: [
      "Content-Type",
      "Authorization",
      "X-Requested-With",
      "Accept",
    ],
    exposedHeaders: ["Authorization"],
    optionsSuccessStatus: 200,
  }),
);

app.use(express.json());
app.use(morgan(process.env.NODE_ENV === "production" ? "combined" : "dev"));

// Apply general rate limiter to all routes
app.use(generalLimiter);

// -- Routes --------------------------------------------------------------------
// VPN guard on high-sensitivity endpoints (login + student check-in)
app.use("/api/auth/login",      authLimiter, vpnGuard);
app.use("/api/student/checkin", vpnGuard);

app.use("/api/auth",         authRoutes);
app.use("/api/admin",        adminRoutes);
app.use("/api/lecturer",     lecturerRoutes);
app.use("/api/student",      studentRoutes);
app.use("/api/notifications", warningRoutes);
app.use("/api/appeals",       appealRoutes);
app.use("/api/messages",      messageRoutes);

// Health check — reports DB connectivity and service versions
app.get("/api/health", async (req, res) => {
  const db = require("./src/config/database");
  let dbStatus = "ok";
  try { await db.query("SELECT 1"); } catch { dbStatus = "error"; }

  res.status(dbStatus === "ok" ? 200 : 503).json({
    status:    dbStatus === "ok" ? "ok" : "degraded",
    version:   API_VERSION,
    timestamp: new Date().toISOString(),
    services: {
      database: dbStatus,
      email:    process.env.SMTP_HOST ? "configured" : "disabled",
      fcm:      process.env.FCM_SERVICE_ACCOUNT_KEY ? "configured" : "disabled",
      vpnGuard: process.env.IPDATA_API_KEY ? "ipdata" : "ip-api-fallback",
    },
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    success: false,
    error: `Route ${req.method} ${req.path} not found`,
  });
});

// Error handler (must be last)
app.use(errorHandler);

// -- Start ---------------------------------------------------------------------
const PORT = Number(process.env.PORT) || 5000;

async function start() {
  try {
    await testConnection();
    require("./src/services/fcm.service").init();

    // ── Weekly attendance digest — every Monday at 07:00 ──────────────────
    const cronSchedule = process.env.WEEKLY_DIGEST_SCHEDULE || "0 7 * * 1"
    const cronTimezone = process.env.CRON_TIMEZONE          || "Africa/Kigali"
    cron.schedule(cronSchedule, () => {
      console.log("[Cron] Running weekly attendance digest...");
      notify.sendWeeklyDigests().catch(err =>
        console.error("[Cron] Weekly digest failed:", err.message)
      );
    }, { timezone: cronTimezone });

    server.listen(PORT, "0.0.0.0", () => {
      console.log(`\n AttendX API running on:`);
      console.log(`   Local: http://localhost:${PORT}`);
      console.log(`   Network: http://${getLocalIpAddress()}:${PORT}`);
      console.log(`   Environment: ${process.env.NODE_ENV || "development"}`);
      console.log(
        `   CORS: ${process.env.NODE_ENV !== "production" ? "All origins allowed (dev mode)" : "Restricted"}`,
      );
    });
  } catch (err) {
    console.error("Failed to start server:", err);
    process.exit(1);
  }
}

// Helper to get local IP address
function getLocalIpAddress() {
  const { networkInterfaces } = require("os");
  const nets = networkInterfaces();
  for (const name of Object.keys(nets)) {
    for (const net of nets[name]) {
      if (net.family === "IPv4" && !net.internal) {
        return net.address;
      }
    }
  }
  return "localhost";
}

start().catch((err) => {
  console.error(err);
  process.exit(1);
});
