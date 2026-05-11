const express = require("express");
const cors = require("cors");
const crypto = require("crypto");
require("dotenv").config();

const pool = require("./db");
const { locationCatalog, serviceCatalog, siteColors } = require("./config/catalog");
const { sendEmail } = require("./email");

const app = express();
app.use(cors());
app.use(express.json());

const PORT = Number(process.env.PORT || 5003);
const NORMAL_USER_AUTH_API_URL =
  process.env.NORMAL_USER_AUTH_API_URL || "http://45.114.143.183:83/api/auth/login";
const NORMAL_USER_AUTH_CLIENT_ID = process.env.NORMAL_USER_AUTH_CLIENT_ID || "internal-portal";
const SUPER_ADMIN_EMAIL = process.env.SUPER_ADMIN_EMAIL || process.env.ADMIN_NOTIFY_EMAIL;
const sessionRefreshTokens = new Map();
const passwordResetCodes = new Map();
const registrationCodes = new Map();
let catalogTablesReady = null;

const DEFAULT_SITE_AREAS = Object.keys(locationCatalog);

function makeCode() {
  return String(crypto.randomInt(100000, 1000000));
}

function makeToken() {
  return crypto.randomBytes(32).toString("hex");
}

function normalizeEmail(value) {
  return String(value || "").trim().toLowerCase();
}

function setTemporary(map, key, value, ttlMs = 10 * 60 * 1000) {
  const existing = map.get(key);
  if (existing?.timeoutId) clearTimeout(existing.timeoutId);
  const timeoutId = setTimeout(() => map.delete(key), ttlMs);
  map.set(key, { ...value, timeoutId, expiresAt: Date.now() + ttlMs });
}

function clearTemporary(entry) {
  if (entry?.timeoutId) clearTimeout(entry.timeoutId);
}

function mapDbUser(row) {
  return {
    id: row.id,
    fullName: row.full_name,
    email: row.email,
    role: row.role,
  };
}

function mapExternalNormalUser(payload, fallbackEmail) {
  const source = payload?.user || payload?.data?.user || payload?.data || payload || {};
  return {
    employeeId: source.employeeId || source.employee_id || source.id || null,
    fullName: source.name || source.fullName || source.full_name || source.employeeName || fallbackEmail,
    email: source.email || fallbackEmail,
    departmentId: source.departmentId || source.department_id || null,
    departmentName: source.departmentName || source.department_name || null,
    gradeId: source.gradeId || source.grade_id || null,
    gradeCode: source.gradeCode || source.grade_code || null,
    gradeTitle: source.gradeTitle || source.grade_title || null,
    mobileNumber: source.mobileNumber || source.mobile_number || null,
    aadharNumber: source.aadharNumber || source.aadhar_number || null,
    userType: source.userType || source.user_type || "Employee",
    emailVerified: source.emailVerified ?? source.email_verified ?? null,
    contractorAgencyName: source.contractorAgencyName || source.contractor_agency_name || null,
  };
}

function getRefreshToken(payload) {
  return (
    payload?.refreshToken ||
    payload?.refresh_token ||
    payload?.data?.refreshToken ||
    payload?.data?.refresh_token ||
    payload?.tokens?.refreshToken ||
    payload?.tokens?.refresh_token ||
    null
  );
}

async function ensureNormalUser(externalUser) {
  const email = normalizeEmail(externalUser.email);
  const [rows] = await pool.query(
    "SELECT id, full_name, email, role FROM users WHERE email = ? LIMIT 1",
    [email]
  );

  if (rows.length) {
    if (rows[0].role !== "normal_user") {
      throw new Error("This email belongs to a portal staff account.");
    }

    await pool.query("UPDATE users SET full_name = ? WHERE id = ?", [externalUser.fullName, rows[0].id]);
    return { ...mapDbUser(rows[0]), fullName: externalUser.fullName, externalProfile: externalUser };
  }

  const [result] = await pool.query(
    "INSERT INTO users (full_name, email, password, role) VALUES (?, ?, ?, 'normal_user')",
    [externalUser.fullName, email, "external-auth"]
  );
  return {
    id: result.insertId,
    fullName: externalUser.fullName,
    email,
    role: "normal_user",
    externalProfile: externalUser,
  };
}

async function loginNormalUser(email, password) {
  const response = await fetch(NORMAL_USER_AUTH_API_URL, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      email,
      password,
      clientId: NORMAL_USER_AUTH_CLIENT_ID,
    }),
  });

  let payload = null;
  try {
    payload = await response.json();
  } catch (_err) {
    payload = null;
  }

  if (!response.ok) {
    const message = payload?.message || `Normal user auth failed (${response.status}).`;
    const error = new Error(message);
    error.status = response.status;
    throw error;
  }

  const externalUser = mapExternalNormalUser(payload, email);
  const user = await ensureNormalUser(externalUser);
  return { user, refreshToken: getRefreshToken(payload), externalAuth: payload };
}

function buildTicketNumber(siteArea, id) {
  const prefix = siteArea.substring(0, 3).toUpperCase();
  const now = new Date();
  const ymd = `${now.getFullYear()}${String(now.getMonth() + 1).padStart(2, "0")}${String(now.getDate()).padStart(2, "0")}`;
  return `${prefix}-${ymd}-${String(id).padStart(5, "0")}`;
}

function mapTicket(row) {
  return {
    id: row.id,
    ticketNumber: row.ticket_number,
    siteArea: row.site_area,
    serviceType: row.service_type,
    serviceName: row.service_name,
    locationName: row.location_name,
    remarks: row.remarks,
    status: row.status,
    adminRemark: row.admin_remark,
    pendingServiceStatus: row.pending_service_status,
    pendingServiceRemark: row.pending_service_remark,
    pendingServiceUpdatedAt: row.pending_service_updated_at,
    assignedPerson: row.assigned_person_id
      ? {
          id: row.assigned_person_id,
          fullName: row.assigned_person_name,
          email: row.assigned_person_email,
        }
      : null,
    reopenCount: row.reopen_count ?? 0,
    escalationLevel: row.escalation_level ?? 0,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    requestedBy: row.requested_by,
    requestedByEmail: row.requested_by_email,
    siteColor: siteColors[row.site_area] || "#c62828",
  };
}

function normalizeOptionalValue(value) {
  if (value === undefined || value === null) return null;
  const trimmed = String(value).trim();
  return trimmed ? trimmed : null;
}

function normalizeCatalogText(value) {
  return String(value || "").trim().replace(/\s+/g, " ");
}

function assertValidSiteArea(siteArea) {
  if (!DEFAULT_SITE_AREAS.includes(siteArea)) {
    const error = new Error("Valid siteArea is required.");
    error.status = 400;
    throw error;
  }
}

async function ensureCatalogTables() {
  if (!catalogTablesReady) {
    catalogTablesReady = Promise.all([
      pool.query(`
        CREATE TABLE IF NOT EXISTS catalog_locations (
          id INT AUTO_INCREMENT PRIMARY KEY,
          site_area VARCHAR(40) NOT NULL,
          location_name VARCHAR(120) NOT NULL,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          UNIQUE KEY uq_catalog_location (site_area, location_name)
        )
      `),
      pool.query(`
        CREATE TABLE IF NOT EXISTS catalog_services (
          id INT AUTO_INCREMENT PRIMARY KEY,
          site_area VARCHAR(40) NOT NULL,
          service_type VARCHAR(60) NOT NULL,
          service_name VARCHAR(80) NOT NULL,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          UNIQUE KEY uq_catalog_service (site_area, service_type, service_name)
        )
      `),
      pool.query(`
        CREATE TABLE IF NOT EXISTS catalog_disabled_locations (
          id INT AUTO_INCREMENT PRIMARY KEY,
          site_area VARCHAR(40) NOT NULL,
          location_name VARCHAR(120) NOT NULL,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          UNIQUE KEY uq_disabled_catalog_location (site_area, location_name)
        )
      `),
      pool.query(`
        CREATE TABLE IF NOT EXISTS catalog_disabled_services (
          id INT AUTO_INCREMENT PRIMARY KEY,
          site_area VARCHAR(40) NOT NULL,
          service_type VARCHAR(60) NOT NULL,
          service_name VARCHAR(80) NOT NULL,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          UNIQUE KEY uq_disabled_catalog_service (site_area, service_type, service_name)
        )
      `),
    ]);
  }

  return catalogTablesReady;
}

function sortUnique(values) {
  return Array.from(new Set(values.filter(Boolean))).sort((left, right) => left.localeCompare(right));
}

async function getCatalogOptionsData() {
  await ensureCatalogTables();
  const [locationRows] = await pool.query(
    "SELECT site_area, location_name FROM catalog_locations ORDER BY site_area ASC, location_name ASC"
  );
  const [serviceRows] = await pool.query(
    "SELECT site_area, service_type, service_name FROM catalog_services ORDER BY site_area ASC, service_type ASC, service_name ASC"
  );
  const [disabledLocationRows] = await pool.query(
    "SELECT site_area, location_name FROM catalog_disabled_locations"
  );
  const [disabledServiceRows] = await pool.query(
    "SELECT site_area, service_type, service_name FROM catalog_disabled_services"
  );
  const disabledLocations = new Set(disabledLocationRows.map((row) => `${row.site_area}||${row.location_name}`));
  const disabledServices = new Set(
    disabledServiceRows.map((row) => `${row.site_area}||${row.service_type}||${row.service_name}`)
  );

  const mergedLocations = {};
  const mergedServices = {};

  DEFAULT_SITE_AREAS.forEach((siteArea) => {
    mergedLocations[siteArea] = [...(locationCatalog[siteArea] || [])];
    mergedServices[siteArea] = {};
    Object.entries(serviceCatalog[siteArea] || {}).forEach(([serviceType, serviceNames]) => {
      mergedServices[siteArea][serviceType] = [...serviceNames];
    });
  });

  locationRows.forEach((row) => {
    if (!mergedLocations[row.site_area]) mergedLocations[row.site_area] = [];
    mergedLocations[row.site_area].push(row.location_name);
  });

  serviceRows.forEach((row) => {
    if (!mergedServices[row.site_area]) mergedServices[row.site_area] = {};
    if (!mergedServices[row.site_area][row.service_type]) mergedServices[row.site_area][row.service_type] = [];
    mergedServices[row.site_area][row.service_type].push(row.service_name);
  });

  Object.keys(mergedLocations).forEach((siteArea) => {
    mergedLocations[siteArea] = sortUnique(
      mergedLocations[siteArea].filter((locationName) => !disabledLocations.has(`${siteArea}||${locationName}`))
    );
  });

  Object.keys(mergedServices).forEach((siteArea) => {
    Object.keys(mergedServices[siteArea]).forEach((serviceType) => {
      mergedServices[siteArea][serviceType] = sortUnique(
        mergedServices[siteArea][serviceType].filter(
          (serviceName) => !disabledServices.has(`${siteArea}||${serviceType}||${serviceName}`)
        )
      );
      if (!mergedServices[siteArea][serviceType].length) {
        delete mergedServices[siteArea][serviceType];
      }
    });
  });

  return {
    sites: DEFAULT_SITE_AREAS,
    serviceCatalog: mergedServices,
    locationCatalog: mergedLocations,
  };
}

function mapServicePerson(row) {
  return {
    id: row.id,
    fullName: row.full_name,
    email: row.email,
    siteArea: row.site_area,
    serviceType: row.service_type,
    serviceName: row.service_name,
    locationName: row.location_name,
    active: !!row.active,
    createdAt: row.created_at,
  };
}

function optionalText(value, fallback = "-") {
  if (value === undefined || value === null) return fallback;
  const text = String(value).trim();
  return text || fallback;
}

function buildTicketEmailDetails(row, extraLines = []) {
  const lines = [
    `Ticket: ${optionalText(row.ticket_number)}`,
    `Site Area: ${optionalText(row.site_area)}`,
    `Service: ${optionalText(row.service_type)} / ${optionalText(row.service_name)}`,
    `Location: ${optionalText(row.location_name)}`,
    `Status: ${optionalText(row.status)}`,
    `Requested By: ${optionalText(row.requested_by)}`,
    `Assigned To: ${row.assigned_person_name ? optionalText(row.assigned_person_name) : "-"}`,
  ];

  return [...extraLines.filter(Boolean), "", ...lines].join("\n");
}

function notifyTicketEmail({ to, subject, introLines = [], ticketRow }) {
  return sendEmail({
    to,
    subject,
    text: buildTicketEmailDetails(ticketRow, introLines),
  }).catch((err) => console.log("[email:error]", err.message));
}

function buildServicePeopleTree(rows) {
  const tree = {};

  rows.forEach((row) => {
    const siteArea = row.site_area;
    const serviceType = row.service_type;
    const serviceName = row.service_name || "All Services";
    const locationName = row.location_name || "All Locations";

    if (!tree[siteArea]) {
      tree[siteArea] = { count: 0, serviceTypes: {} };
    }
    tree[siteArea].count += 1;

    if (!tree[siteArea].serviceTypes[serviceType]) {
      tree[siteArea].serviceTypes[serviceType] = { count: 0, serviceNames: {} };
    }
    tree[siteArea].serviceTypes[serviceType].count += 1;

    if (!tree[siteArea].serviceTypes[serviceType].serviceNames[serviceName]) {
      tree[siteArea].serviceTypes[serviceType].serviceNames[serviceName] = {
        count: 0,
        locations: {},
      };
    }
    tree[siteArea].serviceTypes[serviceType].serviceNames[serviceName].count += 1;

    if (!tree[siteArea].serviceTypes[serviceType].serviceNames[serviceName].locations[locationName]) {
      tree[siteArea].serviceTypes[serviceType].serviceNames[serviceName].locations[locationName] = {
        count: 0,
        members: [],
      };
    }

    tree[siteArea].serviceTypes[serviceType].serviceNames[serviceName].locations[locationName].count += 1;
    tree[siteArea].serviceTypes[serviceType].serviceNames[serviceName].locations[locationName].members.push(
      mapServicePerson(row)
    );
  });

  return tree;
}

function buildServiceCombinationSummary(rows) {
  const combos = new Map();

  rows.forEach((row) => {
    const key = [
      row.site_area,
      row.service_type,
      row.service_name || "All Services",
      row.location_name || "All Locations",
    ].join("||");

    if (!combos.has(key)) {
      combos.set(key, {
        siteArea: row.site_area,
        serviceType: row.service_type,
        serviceName: row.service_name || "All Services",
        locationName: row.location_name || "All Locations",
        peopleCount: 0,
        people: [],
      });
    }

    const combo = combos.get(key);
    combo.peopleCount += 1;
    combo.people.push({
      id: row.id,
      fullName: row.full_name,
      email: row.email,
      active: !!row.active,
    });
  });

  return Array.from(combos.values()).sort((left, right) => {
    return (
      left.siteArea.localeCompare(right.siteArea) ||
      left.serviceType.localeCompare(right.serviceType) ||
      left.serviceName.localeCompare(right.serviceName) ||
      left.locationName.localeCompare(right.locationName)
    );
  });
}

async function addTicketEvent({
  ticketId,
  actorRole,
  actorId = null,
  action,
  fromStatus = null,
  toStatus = null,
  note = null,
}) {
  await pool.query(
    `INSERT INTO ticket_events (ticket_id, actor_role, actor_id, action, from_status, to_status, note)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
    [ticketId, actorRole, actorId, action, fromStatus, toStatus, note]
  );
}

app.get("/api/health", async (_req, res) => {
  try {
    await pool.query("SELECT 1");
    res.json({ ok: true, message: "API and database are reachable." });
  } catch (error) {
    res.status(500).json({ ok: false, message: "Database connection failed.", error: error.message });
  }
});

app.post("/api/auth/login", async (req, res) => {
  const { email, password, role } = req.body;
  const normalizedEmail = normalizeEmail(email);

  if (!normalizedEmail || !password) {
    return res.status(400).json({ message: "Email and password are required." });
  }

  try {
    if (role === "normal_user" || role === "employee") {
      const normalLogin = await loginNormalUser(normalizedEmail, password);
      const sessionId = makeToken();
      if (normalLogin.refreshToken) {
        sessionRefreshTokens.set(sessionId, {
          refreshToken: normalLogin.refreshToken,
          userId: normalLogin.user.id,
          role: "normal_user",
          createdAt: Date.now(),
        });
      }

      return res.json({
        message: "Login successful.",
        user: normalLogin.user,
        sessionId,
        refreshToken: normalLogin.refreshToken || null,
      });
    }

    const [rows] = await pool.query(
      "SELECT id, full_name, email, role, password FROM users WHERE email = ? LIMIT 1",
      [normalizedEmail]
    );

    if (
      rows.length &&
      ["admin_user", "admin", "super_admin"].includes(String(rows[0].role || "").toLowerCase()) &&
      rows[0].password === password
    ) {
      const user = rows[0];
      const sessionId = makeToken();
      return res.json({
        message: "Login successful.",
        user: mapDbUser(user),
        sessionId,
      });
    }

    const [serviceRows] = await pool.query(
      "SELECT id, full_name, email, password, active FROM service_people WHERE email = ? LIMIT 1",
      [normalizedEmail]
    );

    if (!serviceRows.length || Number(serviceRows[0].active ?? 1) === 0 || serviceRows[0].password !== password) {
      return res.status(401).json({ message: "Invalid credentials." });
    }

    const serviceUser = serviceRows[0];
    const sessionId = makeToken();
    return res.json({
      message: "Login successful.",
      user: {
        id: serviceUser.id,
        fullName: serviceUser.full_name,
        email: serviceUser.email,
        role: "service_person",
      },
      sessionId,
    });
  } catch (error) {
    return res.status(error.status || 500).json({ message: "Unable to login.", error: error.message });
  }
});

app.post("/api/auth/logout", (req, res) => {
  const { sessionId } = req.body;
  if (sessionId) sessionRefreshTokens.delete(sessionId);
  return res.json({ message: "Logged out successfully." });
});

app.post("/api/auth/password-reset/request", async (req, res) => {
  const { email, role } = req.body;
  const normalizedEmail = normalizeEmail(email);
  const normalizedRole = String(role || "").toLowerCase();

  if (!normalizedEmail || !["admin_user", "admin", "super_admin", "service_person"].includes(normalizedRole)) {
    return res.status(400).json({ message: "Valid staff email and role are required." });
  }

  try {
    let accountRows = [];
    if (normalizedRole === "service_person") {
      [accountRows] = await pool.query(
        "SELECT id, full_name, email FROM service_people WHERE email = ? AND active = 1 LIMIT 1",
        [normalizedEmail]
      );
    } else {
      [accountRows] = await pool.query(
        "SELECT id, full_name, email FROM users WHERE email = ? AND role IN ('admin_user', 'admin', 'super_admin') LIMIT 1",
        [normalizedEmail]
      );
    }

    if (!accountRows.length) {
      return res.status(404).json({ message: "Staff account not found." });
    }

    const code = makeCode();
    setTemporary(passwordResetCodes, `${normalizedRole}:${normalizedEmail}`, {
      email: normalizedEmail,
      role: normalizedRole,
      code,
    });

    await sendEmail({
      to: normalizedEmail,
      subject: "MY VOICE password reset code",
      text: `Your password reset code is ${code}. It expires in 10 minutes.`,
    });

    return res.json({ message: "Password reset code sent to registered email." });
  } catch (error) {
    return res.status(500).json({ message: "Unable to start password reset.", error: error.message });
  }
});

app.post("/api/auth/password-reset/confirm", async (req, res) => {
  const { email, role, code, newPassword } = req.body;
  const normalizedEmail = normalizeEmail(email);
  const normalizedRole = String(role || "").toLowerCase();
  const key = `${normalizedRole}:${normalizedEmail}`;
  const entry = passwordResetCodes.get(key);

  if (!normalizedEmail || !normalizedRole || !code || !newPassword) {
    return res.status(400).json({ message: "Email, role, code, and new password are required." });
  }

  if (!entry || entry.code !== String(code).trim()) {
    return res.status(400).json({ message: "Invalid or expired reset code." });
  }

  try {
    if (normalizedRole === "service_person") {
      await pool.query("UPDATE service_people SET password = ? WHERE email = ?", [
        String(newPassword).trim(),
        normalizedEmail,
      ]);
    } else {
      await pool.query(
        "UPDATE users SET password = ? WHERE email = ? AND role IN ('admin_user', 'admin', 'super_admin')",
        [String(newPassword).trim(), normalizedEmail]
      );
    }

    clearTemporary(entry);
    passwordResetCodes.delete(key);
    return res.json({ message: "Password reset successfully." });
  } catch (error) {
    return res.status(500).json({ message: "Unable to reset password.", error: error.message });
  }
});

app.post("/api/auth/registration/request", async (req, res) => {
  const { fullName, email, role } = req.body;
  const normalizedEmail = normalizeEmail(email);
  const normalizedRole = String(role || "").toLowerCase();

  if (!fullName || !normalizedEmail || !["admin_user", "admin", "super_admin", "service_person"].includes(normalizedRole)) {
    return res.status(400).json({ message: "fullName, email, and staff role are required." });
  }
  if (!SUPER_ADMIN_EMAIL) {
    return res.status(500).json({ message: "SUPER_ADMIN_EMAIL or ADMIN_NOTIFY_EMAIL is not configured." });
  }

  try {
    const superAdminCode = makeCode();
    setTemporary(registrationCodes, `${normalizedRole}:${normalizedEmail}`, {
      fullName: String(fullName).trim(),
      email: normalizedEmail,
      role: normalizedRole,
      superAdminCode,
    });

    await sendEmail({
      to: SUPER_ADMIN_EMAIL,
      subject: "MY VOICE staff registration approval code",
      text: `${fullName} (${normalizedEmail}) requested ${normalizedRole} registration. Approval code: ${superAdminCode}.`,
    });

    return res.json({ message: "Registration OTP sent to super admin email." });
  } catch (error) {
    return res.status(500).json({ message: "Unable to send registration codes.", error: error.message });
  }
});

app.post("/api/admin-users/register", async (req, res) => {
  const { fullName, email, password, role, superAdminCode } = req.body;
  const normalizedEmail = normalizeEmail(email);
  const normalizedRole = String(role || "admin_user").toLowerCase();
  const key = `${normalizedRole}:${normalizedEmail}`;
  const entry = registrationCodes.get(key);

  if (!fullName || !normalizedEmail || !password || !superAdminCode) {
    return res.status(400).json({ message: "Registration details and super admin OTP are required." });
  }
  if (!["admin_user", "admin", "super_admin"].includes(normalizedRole)) {
    return res.status(400).json({ message: "Only admin roles can use this endpoint." });
  }
  if (!entry || entry.superAdminCode !== String(superAdminCode).trim()) {
    return res.status(400).json({ message: "Invalid or expired super admin OTP." });
  }

  try {
    const [existingRows] = await pool.query("SELECT id FROM users WHERE email = ? LIMIT 1", [normalizedEmail]);
    if (existingRows.length) {
      return res.status(409).json({ message: "A user with this email already exists." });
    }

    const [result] = await pool.query(
      "INSERT INTO users (full_name, email, password, role) VALUES (?, ?, ?, ?)",
      [String(fullName).trim(), normalizedEmail, String(password).trim(), normalizedRole]
    );

    clearTemporary(entry);
    registrationCodes.delete(key);
    return res.status(201).json({
      message: "Admin registered successfully.",
      user: { id: result.insertId, fullName: String(fullName).trim(), email: normalizedEmail, role: normalizedRole },
    });
  } catch (error) {
    return res.status(500).json({ message: "Unable to register admin.", error: error.message });
  }
});

app.get("/api/catalog/options", async (_req, res) => {
  try {
    return res.json(await getCatalogOptionsData());
  } catch (error) {
    return res.status(500).json({ message: "Unable to fetch catalog options.", error: error.message });
  }
});

app.post("/api/catalog/locations", async (req, res) => {
  const siteArea = normalizeCatalogText(req.body.siteArea);
  const locationName = normalizeCatalogText(req.body.locationName);

  try {
    assertValidSiteArea(siteArea);
    if (!locationName) {
      return res.status(400).json({ message: "locationName is required." });
    }

    await ensureCatalogTables();
    await pool.query(
      "DELETE FROM catalog_disabled_locations WHERE site_area = ? AND location_name = ?",
      [siteArea, locationName]
    );
    await pool.query(
      "INSERT IGNORE INTO catalog_locations (site_area, location_name) VALUES (?, ?)",
      [siteArea, locationName]
    );

    return res.status(201).json({
      message: "Location added to service catalog.",
      catalog: await getCatalogOptionsData(),
    });
  } catch (error) {
    return res.status(error.status || 500).json({ message: "Unable to add location.", error: error.message });
  }
});

app.delete("/api/catalog/locations", async (req, res) => {
  const siteArea = normalizeCatalogText(req.query.siteArea);
  const locationName = normalizeCatalogText(req.query.locationName);

  try {
    assertValidSiteArea(siteArea);
    if (!locationName) {
      return res.status(400).json({ message: "locationName is required." });
    }

    await ensureCatalogTables();
    await pool.query(
      "DELETE FROM catalog_locations WHERE site_area = ? AND location_name = ?",
      [siteArea, locationName]
    );
    await pool.query(
      "INSERT IGNORE INTO catalog_disabled_locations (site_area, location_name) VALUES (?, ?)",
      [siteArea, locationName]
    );

    return res.json({
      message: "Location removed from service catalog.",
      catalog: await getCatalogOptionsData(),
    });
  } catch (error) {
    return res.status(error.status || 500).json({ message: "Unable to delete location.", error: error.message });
  }
});

app.post("/api/catalog/services", async (req, res) => {
  const siteArea = normalizeCatalogText(req.body.siteArea);
  const serviceType = normalizeCatalogText(req.body.serviceType);
  const serviceName = normalizeCatalogText(req.body.serviceName);

  try {
    assertValidSiteArea(siteArea);
    if (!serviceType || !serviceName) {
      return res.status(400).json({ message: "serviceType and serviceName are required." });
    }

    await ensureCatalogTables();
    await pool.query(
      "DELETE FROM catalog_disabled_services WHERE site_area = ? AND service_type = ? AND service_name = ?",
      [siteArea, serviceType, serviceName]
    );
    await pool.query(
      "INSERT IGNORE INTO catalog_services (site_area, service_type, service_name) VALUES (?, ?, ?)",
      [siteArea, serviceType, serviceName]
    );

    return res.status(201).json({
      message: "Service added to service catalog.",
      catalog: await getCatalogOptionsData(),
    });
  } catch (error) {
    return res.status(error.status || 500).json({ message: "Unable to add service.", error: error.message });
  }
});

app.delete("/api/catalog/services", async (req, res) => {
  const siteArea = normalizeCatalogText(req.query.siteArea);
  const serviceType = normalizeCatalogText(req.query.serviceType);
  const serviceName = normalizeCatalogText(req.query.serviceName);

  try {
    assertValidSiteArea(siteArea);
    if (!serviceType || !serviceName) {
      return res.status(400).json({ message: "serviceType and serviceName are required." });
    }

    await ensureCatalogTables();
    await pool.query(
      "DELETE FROM catalog_services WHERE site_area = ? AND service_type = ? AND service_name = ?",
      [siteArea, serviceType, serviceName]
    );
    await pool.query(
      "INSERT IGNORE INTO catalog_disabled_services (site_area, service_type, service_name) VALUES (?, ?, ?)",
      [siteArea, serviceType, serviceName]
    );

    return res.json({
      message: "Service removed from service catalog.",
      catalog: await getCatalogOptionsData(),
    });
  } catch (error) {
    return res.status(error.status || 500).json({ message: "Unable to delete service.", error: error.message });
  }
});

app.get("/api/assignees", async (req, res) => {
  const { siteArea, serviceType, serviceName, locationName } = req.query;

  if (!siteArea || !serviceType) {
    return res.status(400).json({ message: "siteArea and serviceType are required." });
  }

  try {
    const [rows] = await pool.query(
      `SELECT id, full_name AS fullName, email
       FROM service_people
       WHERE active = 1
         AND site_area = ?
         AND service_type = ?
         AND (service_name IS NULL OR service_name = ?)
         AND (location_name IS NULL OR location_name = ?)
       ORDER BY full_name ASC`,
      [siteArea, serviceType, serviceName || null, locationName || null]
    );
    return res.json({ assignees: rows });
  } catch (error) {
    return res.status(500).json({ message: "Unable to fetch assignees.", error: error.message });
  }
});

app.get("/api/service-people", async (req, res) => {
  const {
    siteArea,
    serviceType,
    serviceName,
    locationName,
    includeInactive,
  } = req.query;

  try {
    let query = `
      SELECT id, full_name, email, site_area, service_type, service_name, location_name, active, created_at
      FROM service_people
    `;
    const params = [];
    const clauses = [];

    if (includeInactive !== "true") {
      clauses.push("active = 1");
    }
    if (siteArea) {
      clauses.push("site_area = ?");
      params.push(siteArea);
    }
    if (serviceType) {
      clauses.push("service_type = ?");
      params.push(serviceType);
    }
    if (serviceName) {
      clauses.push("COALESCE(service_name, '') = ?");
      params.push(serviceName);
    }
    if (locationName) {
      clauses.push("COALESCE(location_name, '') = ?");
      params.push(locationName);
    }

    if (clauses.length) {
      query += ` WHERE ${clauses.join(" AND ")}`;
    }

    query += " ORDER BY site_area ASC, service_type ASC, service_name ASC, location_name ASC, full_name ASC";

    const [rows] = await pool.query(query, params);
    return res.json({
      servicePeople: rows.map(mapServicePerson),
      combinationSummary: buildServiceCombinationSummary(rows),
      tree: buildServicePeopleTree(rows),
    });
  } catch (error) {
    return res.status(500).json({ message: "Unable to fetch service people.", error: error.message });
  }
});

app.post("/api/service-people", async (req, res) => {
  const {
    fullName,
    email,
    password,
    siteArea,
    serviceType,
    serviceName,
    locationName,
    active,
    superAdminCode,
  } = req.body;
  const normalizedEmail = normalizeEmail(email);
  const registrationEntry = registrationCodes.get(`service_person:${normalizedEmail}`);

  if (!fullName || !normalizedEmail || !siteArea || !serviceType) {
    return res.status(400).json({
      message: "fullName, email, siteArea, and serviceType are required.",
    });
  }
  if (
    !registrationEntry ||
    registrationEntry.superAdminCode !== String(superAdminCode || "").trim()
  ) {
    return res.status(400).json({ message: "Valid super admin registration OTP is required." });
  }

  let created = false;
  try {
    const [existingRows] = await pool.query(
      `SELECT id FROM service_people
       WHERE email = ? AND site_area = ? AND service_type = ?
         AND COALESCE(service_name, '') = COALESCE(?, '')
         AND COALESCE(location_name, '') = COALESCE(?, '')
       LIMIT 1`,
      [
        normalizedEmail,
        siteArea,
        serviceType,
        normalizeOptionalValue(serviceName),
        normalizeOptionalValue(locationName),
      ]
    );

    if (existingRows.length) {
      return res.status(409).json({ message: "A service person with this assignment already exists." });
    }

    const [result] = await pool.query(
      `INSERT INTO service_people
       (full_name, email, password, site_area, service_type, service_name, location_name, active)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        String(fullName).trim(),
        normalizedEmail,
        String(password || "service123").trim(),
        siteArea,
        serviceType,
        normalizeOptionalValue(serviceName),
        normalizeOptionalValue(locationName),
        active === false ? 0 : 1,
      ]
    );

    const [rows] = await pool.query(
      `SELECT id, full_name, email, site_area, service_type, service_name, location_name, active, created_at
       FROM service_people
       WHERE id = ? LIMIT 1`,
      [result.insertId]
    );

    created = true;
    return res.status(201).json({
      message: "Service person registered successfully.",
      servicePerson: mapServicePerson(rows[0]),
    });
  } catch (error) {
    return res.status(500).json({ message: "Unable to register service person.", error: error.message });
  } finally {
    const latestEntry = registrationCodes.get(`service_person:${normalizedEmail}`);
    if (created && latestEntry) {
      clearTemporary(latestEntry);
      registrationCodes.delete(`service_person:${normalizedEmail}`);
    }
  }
});

app.delete("/api/service-people/:id", async (req, res) => {
  const { id } = req.params;

  try {
    const [rows] = await pool.query(
      `SELECT id, full_name, active
       FROM service_people
       WHERE id = ? LIMIT 1`,
      [id]
    );

    if (!rows.length) {
      return res.status(404).json({ message: "Service person not found." });
    }

    await pool.query("UPDATE service_people SET active = 0 WHERE id = ?", [id]);

    return res.json({
      message: `${rows[0].full_name} removed from active service assignments.`,
    });
  } catch (error) {
    return res.status(500).json({ message: "Unable to delete service person.", error: error.message });
  }
});

app.post("/api/tickets", async (req, res) => {
  const { userId, siteArea, serviceType, serviceName, locationName, remarks } = req.body;

  if (!userId || !siteArea || !serviceType || !serviceName || !locationName) {
    return res.status(400).json({ message: "Missing required ticket fields." });
  }

  try {
    const [result] = await pool.query(
      `INSERT INTO tickets
      (user_id, site_area, service_type, service_name, location_name, remarks, status)
      VALUES (?, ?, ?, ?, ?, ?, 'Open')`,
      [userId, siteArea, serviceType, serviceName, locationName, remarks || null]
    );

    const ticketNumber = buildTicketNumber(siteArea, result.insertId);
    await pool.query("UPDATE tickets SET ticket_number = ? WHERE id = ?", [ticketNumber, result.insertId]);

    await addTicketEvent({
      ticketId: result.insertId,
      actorRole: "normal_user",
      actorId: userId,
      action: "CREATED",
      fromStatus: null,
      toStatus: "Open",
      note: remarks || null,
    });

    const [rows] = await pool.query(
      `SELECT t.*, u.full_name AS requested_by, u.email AS requested_by_email,
              sp.id AS assigned_person_id, sp.full_name AS assigned_person_name, sp.email AS assigned_person_email
       FROM tickets t
       INNER JOIN users u ON u.id = t.user_id
       LEFT JOIN service_people sp ON sp.id = t.assigned_person_id
       WHERE t.id = ?`,
      [result.insertId]
    );

    notifyTicketEmail({
      to: [process.env.ADMIN_NOTIFY_EMAIL, rows[0].requested_by_email].filter(Boolean),
      subject: `Ticket ${ticketNumber} created`,
      introLines: [
        "A new ticket has been created by a normal user.",
        `Creation Remark: ${optionalText(remarks)}`,
      ],
      ticketRow: rows[0],
    });

    return res.status(201).json({
      message: "Ticket created successfully.",
      ticket: mapTicket(rows[0]),
    });
  } catch (error) {
    return res.status(500).json({ message: "Unable to create ticket.", error: error.message });
  }
});

app.get("/api/tickets", async (req, res) => {
  const { userId, role, siteArea } = req.query;

  try {
    let query = `
      SELECT t.*, u.full_name AS requested_by, u.email AS requested_by_email,
             sp.id AS assigned_person_id, sp.full_name AS assigned_person_name, sp.email AS assigned_person_email
      FROM tickets t
      INNER JOIN users u ON u.id = t.user_id
      LEFT JOIN service_people sp ON sp.id = t.assigned_person_id
    `;
    const params = [];
    const clauses = [];

    if (role === "normal_user" && userId) {
      clauses.push("t.user_id = ?");
      params.push(userId);
    }

    if (role === "service_person" && userId) {
      clauses.push("t.assigned_person_id = ?");
      params.push(userId);
    }

    if (siteArea) {
      clauses.push("t.site_area = ?");
      params.push(siteArea);
    }

    if (clauses.length) {
      query += ` WHERE ${clauses.join(" AND ")}`;
    }

    query += " ORDER BY t.updated_at DESC, t.created_at DESC";

    const [rows] = await pool.query(query, params);
    return res.json({ tickets: rows.map(mapTicket) });
  } catch (error) {
    return res.status(500).json({ message: "Unable to fetch tickets.", error: error.message });
  }
});

app.get("/api/tickets/:id/events", async (req, res) => {
  const { id } = req.params;
  try {
    const [rows] = await pool.query(
      `SELECT id, actor_role AS actorRole, actor_id AS actorId, action, from_status AS fromStatus,
              to_status AS toStatus, note, created_at AS createdAt
       FROM ticket_events
       WHERE ticket_id = ?
       ORDER BY created_at ASC, id ASC`,
      [id]
    );
    return res.json({ events: rows });
  } catch (error) {
    return res.status(500).json({ message: "Unable to fetch ticket events.", error: error.message });
  }
});

app.post("/api/tickets/:id/assign", async (req, res) => {
  const { id } = req.params;
  const { personId, adminUserId } = req.body;

  if (!personId) {
    return res.status(400).json({ message: "personId is required." });
  }

  try {
    const [ticketRows] = await pool.query(
      "SELECT id, site_area, service_type, service_name, location_name, ticket_number, status, user_id, remarks FROM tickets WHERE id = ? LIMIT 1",
      [id]
    );
    if (!ticketRows.length) return res.status(404).json({ message: "Ticket not found." });

    const ticket = ticketRows[0];
    if (!["Open", "Hold"].includes(ticket.status)) {
      return res.status(400).json({ message: "Only Open/Hold tickets can be assigned." });
    }

    const [personRows] = await pool.query(
      "SELECT id, full_name, email, site_area, service_type, service_name, location_name, active FROM service_people WHERE id = ? LIMIT 1",
      [personId]
    );
    if (!personRows.length || Number(personRows[0].active ?? 1) === 0) {
      return res.status(404).json({ message: "Assignee not found." });
    }
    const person = personRows[0];
    if (person.site_area !== ticket.site_area || person.service_type !== ticket.service_type) {
      return res.status(400).json({ message: "Assignee does not match site area/service type." });
    }
    if (person.service_name && person.service_name !== ticket.service_name) {
      return res.status(400).json({ message: "Assignee does not match specific service." });
    }
    if (person.location_name && person.location_name !== ticket.location_name) {
      return res.status(400).json({ message: "Assignee does not match location." });
    }

    await pool.query("UPDATE tickets SET assigned_person_id = ? WHERE id = ?", [personId, id]);
    await addTicketEvent({
      ticketId: id,
      actorRole: "admin_user",
      actorId: adminUserId || null,
      action: "ASSIGNED",
      fromStatus: ticket.status,
      toStatus: ticket.status,
      note: `Assigned to ${person.full_name} (${person.email})`,
    });

    const [rows] = await pool.query(
      `SELECT t.*, u.full_name AS requested_by, u.email AS requested_by_email,
              sp.id AS assigned_person_id, sp.full_name AS assigned_person_name, sp.email AS assigned_person_email
       FROM tickets t
       INNER JOIN users u ON u.id = t.user_id
       LEFT JOIN service_people sp ON sp.id = t.assigned_person_id
       WHERE t.id = ?`,
      [id]
    );

    notifyTicketEmail({
      to: [rows[0].requested_by_email, person.email, process.env.ADMIN_NOTIFY_EMAIL].filter(Boolean),
      subject: `Ticket ${ticket.ticket_number} assigned`,
      introLines: [
        "Admin has assigned this ticket to a service person.",
        `Assignment Note: Assigned to ${person.full_name} (${person.email})`,
      ],
      ticketRow: rows[0],
    });

    return res.json({ message: "Ticket assigned.", ticket: mapTicket(rows[0]) });
  } catch (error) {
    return res.status(500).json({ message: "Unable to assign ticket.", error: error.message });
  }
});

app.post("/api/tickets/:id/reopen", async (req, res) => {
  const { id } = req.params;
  const { userId, remark } = req.body;

  if (!userId) return res.status(400).json({ message: "userId is required." });
  if (!remark || !String(remark).trim()) {
    return res.status(400).json({ message: "Reopen remark is required." });
  }

  try {
    const [ticketRows] = await pool.query(
      "SELECT id, user_id, status, reopen_count, escalation_level, ticket_number FROM tickets WHERE id = ? LIMIT 1",
      [id]
    );
    if (!ticketRows.length) return res.status(404).json({ message: "Ticket not found." });

    const ticket = ticketRows[0];
    if (Number(ticket.user_id) !== Number(userId)) {
      return res.status(403).json({ message: "You can only reopen your own tickets." });
    }
    if (ticket.status !== "Resolved") {
      return res.status(400).json({ message: "Only Resolved tickets can be reopened." });
    }
    if (ticket.reopen_count >= 3) {
      return res.status(400).json({ message: "Maximum escalation level reached (3)." });
    }

    const nextReopen = Number(ticket.reopen_count) + 1;
    const nextEscalation = Math.max(Number(ticket.escalation_level) || 0, nextReopen);

    await pool.query(
      "UPDATE tickets SET status = 'Open', reopen_count = ?, escalation_level = ?, remarks = ? WHERE id = ?",
      [nextReopen, nextEscalation, String(remark).trim(), id]
    );

    await addTicketEvent({
      ticketId: id,
      actorRole: "normal_user",
      actorId: userId,
      action: "REOPENED",
      fromStatus: "Resolved",
      toStatus: "Open",
      note: String(remark).trim(),
    });

    const [rows] = await pool.query(
      `SELECT t.*, u.full_name AS requested_by, u.email AS requested_by_email,
              sp.id AS assigned_person_id, sp.full_name AS assigned_person_name, sp.email AS assigned_person_email
       FROM tickets t
       INNER JOIN users u ON u.id = t.user_id
       LEFT JOIN service_people sp ON sp.id = t.assigned_person_id
       WHERE t.id = ?`,
      [id]
    );

    notifyTicketEmail({
      to: [process.env.ADMIN_NOTIFY_EMAIL, rows[0].requested_by_email, rows[0].assigned_person_email].filter(Boolean),
      subject: `Ticket ${ticket.ticket_number} reopened and escalated to Level ${nextEscalation}`,
      introLines: [
        "A user has reopened this ticket.",
        `Reopen Remark: ${optionalText(remark)}`,
        `Escalation Triggered: Level ${nextEscalation}`,
      ],
      ticketRow: rows[0],
    });

    return res.json({ message: "Ticket reopened.", ticket: mapTicket(rows[0]) });
  } catch (error) {
    return res.status(500).json({ message: "Unable to reopen ticket.", error: error.message });
  }
});

app.patch("/api/tickets/:id/status", async (req, res) => {
  const { id } = req.params;
  const { status, adminRemark } = req.body;
  const { adminUserId } = req.body;

  const allowedStatuses = ["Open", "Hold", "Resolved", "Cancelled"];
  if (!allowedStatuses.includes(status)) {
    return res.status(400).json({ message: "Invalid status." });
  }

  if (status === "Cancelled" && !adminRemark) {
    return res.status(400).json({ message: "Cancellation remark is required." });
  }

  try {
    const [existingRows] = await pool.query(
      "SELECT status, ticket_number, user_id, assigned_person_id FROM tickets WHERE id = ? LIMIT 1",
      [id]
    );

    if (!existingRows.length) {
      return res.status(404).json({ message: "Ticket not found." });
    }

    const currentStatus = existingRows[0].status;
    const allowedTransitions = {
      Open: ["Hold", "Resolved", "Cancelled"],
      Hold: ["Resolved", "Cancelled"],
      Resolved: [],
      Cancelled: [],
    };

    if (!allowedTransitions[currentStatus]?.includes(status)) {
      return res.status(400).json({
        message: `Ticket in ${currentStatus} state cannot be changed to ${status}.`,
      });
    }

    await pool.query("UPDATE tickets SET status = ?, admin_remark = ?, pending_service_status = NULL, pending_service_remark = NULL, pending_service_updated_at = NULL WHERE id = ?", [
      status,
      adminRemark || null,
      id,
    ]);

    await addTicketEvent({
      ticketId: id,
      actorRole: "admin_user",
      actorId: adminUserId || null,
      action: "STATUS_CHANGED",
      fromStatus: currentStatus,
      toStatus: status,
      note: adminRemark || null,
    });

    const [rows] = await pool.query(
      `SELECT t.*, u.full_name AS requested_by, u.email AS requested_by_email,
              sp.id AS assigned_person_id, sp.full_name AS assigned_person_name, sp.email AS assigned_person_email
       FROM tickets t
       INNER JOIN users u ON u.id = t.user_id
       LEFT JOIN service_people sp ON sp.id = t.assigned_person_id
       WHERE t.id = ?`,
      [id]
    );

    const ticketNumber = existingRows[0].ticket_number || rows[0].ticket_number;
    notifyTicketEmail({
      to: [rows[0].requested_by_email, rows[0].assigned_person_email, process.env.ADMIN_NOTIFY_EMAIL].filter(Boolean),
      subject: `Ticket ${ticketNumber} status updated: ${status}`,
      introLines: [
        "Admin has updated the ticket status.",
        `Previous Status: ${currentStatus}`,
        `New Status: ${status}`,
        `Admin Action Remark: ${optionalText(adminRemark)}`,
      ],
      ticketRow: rows[0],
    });

    return res.json({
      message: "Ticket status updated.",
      ticket: mapTicket(rows[0]),
    });
  } catch (error) {
    return res.status(500).json({ message: "Unable to update ticket.", error: error.message });
  }
});

app.patch("/api/tickets/:id/service-status", async (req, res) => {
  const { id } = req.params;
  const { servicePersonId, status, remark } = req.body;

  if (!servicePersonId) {
    return res.status(400).json({ message: "servicePersonId is required." });
  }

  if (!["Resolved", "Not Resolved"].includes(status)) {
    return res.status(400).json({ message: "Invalid service status." });
  }

  if (!remark || !String(remark).trim()) {
    return res.status(400).json({ message: "Remark is required." });
  }

  try {
    const [ticketRows] = await pool.query(
      `SELECT id, status, ticket_number, assigned_person_id
       FROM tickets
       WHERE id = ? LIMIT 1`,
      [id]
    );

    if (!ticketRows.length) {
      return res.status(404).json({ message: "Ticket not found." });
    }

    const ticket = ticketRows[0];
    if (Number(ticket.assigned_person_id) !== Number(servicePersonId)) {
      return res.status(403).json({ message: "You can update only your assigned tickets." });
    }

    if (!["Open", "Hold"].includes(ticket.status)) {
      return res.status(400).json({ message: "Only Open or Hold tickets can be updated by a service assignee." });
    }

    await pool.query(
      `UPDATE tickets
       SET pending_service_status = ?, pending_service_remark = ?, pending_service_updated_at = CURRENT_TIMESTAMP
       WHERE id = ?`,
      [status, String(remark).trim(), id]
    );

    await addTicketEvent({
      ticketId: id,
      actorRole: "service_person",
      actorId: servicePersonId,
      action: "SERVICE_STATUS_REQUESTED",
      fromStatus: ticket.status,
      toStatus: status,
      note: String(remark).trim(),
    });

    const [rows] = await pool.query(
      `SELECT t.*, u.full_name AS requested_by, u.email AS requested_by_email,
              sp.id AS assigned_person_id, sp.full_name AS assigned_person_name, sp.email AS assigned_person_email
       FROM tickets t
       INNER JOIN users u ON u.id = t.user_id
       LEFT JOIN service_people sp ON sp.id = t.assigned_person_id
       WHERE t.id = ?`,
      [id]
    );

    notifyTicketEmail({
      to: [process.env.ADMIN_NOTIFY_EMAIL, rows[0].requested_by_email, rows[0].assigned_person_email].filter(Boolean),
      subject: `Ticket ${ticket.ticket_number} update requested by service assignee`,
      introLines: [
        "A service assignee has submitted a status update for admin approval.",
        `Requested Status: ${status}`,
        `Service Remark: ${optionalText(remark)}`,
      ],
      ticketRow: rows[0],
    });

    return res.json({
      message: "Status update submitted for admin approval.",
      ticket: mapTicket(rows[0]),
    });
  } catch (error) {
    return res.status(500).json({ message: "Unable to submit service status.", error: error.message });
  }
});

app.listen(PORT, () => {
  console.log(`Facility Service Management backend running on port ${PORT}`);
});
