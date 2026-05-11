import React, { useState } from "react";
import { MDBSpinner } from "mdb-react-ui-kit";
import {
  confirmPasswordReset,
  createServicePerson,
  login,
  registerAdmin,
  requestPasswordReset,
  requestRegistrationCodes,
} from "./api/client";

function isValidEmail(value) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(value || "").trim());
}

export default function Login({ onLoginSuccess }) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [remember, setRemember] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [resetOpen, setResetOpen] = useState(false);
  const [resetCode, setResetCode] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [registerOpen, setRegisterOpen] = useState(false);
  const [registrationRequested, setRegistrationRequested] = useState(false);
  const [registerForm, setRegisterForm] = useState({
    role: "admin_user",
    fullName: "",
    email: "",
    password: "",
    siteArea: "",
    serviceType: "",
    serviceName: "",
    locationName: "",
    superAdminCode: "",
  });

  const canSubmit = isValidEmail(email) && password && !busy;
  const loginRole = "admin_user";
  const resetRole = "admin_user";
  const isServiceRegistration = registerForm.role === "service_person";

  function updateRegisterForm(field, value) {
    setRegisterForm((current) => ({ ...current, [field]: value }));
  }

  function switchRegistrationRole(nextRole) {
    setRegisterForm((current) => ({
      ...current,
      role: nextRole,
      password: "",
      siteArea: "",
      serviceType: "",
      serviceName: "",
      locationName: "",
      superAdminCode: "",
    }));
    setRegistrationRequested(false);
  }

  async function handleSubmit(event) {
    event.preventDefault();
    if (!canSubmit) return;

    setBusy(true);
    setError("");

    try {
      const response = await login({
        email: String(email).trim(),
        password,
        role: loginRole,
      });

      if (response?.user) {
        if (response.sessionId) sessionStorage.setItem("ism_session_id", response.sessionId);
        if (response.refreshToken) sessionStorage.setItem("ism_refresh_token", response.refreshToken);
        onLoginSuccess(response.user, remember);
      } else {
        setError("Login response did not include a user.");
      }
    } catch (err) {
      setError(err.message || "Unable to sign in right now.");
    } finally {
      setBusy(false);
    }
  }

  async function handleResetRequest() {
    if (!isValidEmail(email)) {
      setError("Enter your staff email first.");
      return;
    }

    setBusy(true);
    setError("");
    setNotice("");
    try {
      const response = await requestPasswordReset({ email: String(email).trim(), role: resetRole });
      setResetOpen(true);
      setNotice(response.message || "Reset code sent.");
    } catch (err) {
      setError(err.message || "Unable to send reset code.");
    } finally {
      setBusy(false);
    }
  }

  async function handleRegistrationCodeRequest() {
    if (!registerForm.fullName.trim() || !isValidEmail(registerForm.email)) {
      setError("Enter the staff name and valid email for registration.");
      return;
    }

    setBusy(true);
    setError("");
    setNotice("");
    try {
      const response = await requestRegistrationCodes({
        fullName: registerForm.fullName.trim(),
        email: registerForm.email.trim(),
        role: registerForm.role,
      });
      setRegistrationRequested(true);
      setNotice(response.message || "Registration OTP sent to super admin email.");
    } catch (err) {
      setError(err.message || "Unable to send registration codes.");
    } finally {
      setBusy(false);
    }
  }

  async function handleRegistrationSubmit() {
    const trimmedEmail = registerForm.email.trim();
    if (
      !registerForm.fullName.trim() ||
      !isValidEmail(trimmedEmail) ||
      !registerForm.password ||
      !registerForm.superAdminCode
    ) {
      setError("Enter registration details and the super admin OTP.");
      return;
    }
    if (isServiceRegistration && (!registerForm.siteArea.trim() || !registerForm.serviceType.trim())) {
      setError("Enter service area and service type for the service person.");
      return;
    }

    setBusy(true);
    setError("");
    setNotice("");
    try {
      const commonPayload = {
        fullName: registerForm.fullName.trim(),
        email: trimmedEmail,
        password: registerForm.password,
        superAdminCode: registerForm.superAdminCode.trim(),
      };
      const response = isServiceRegistration
        ? await createServicePerson({
            ...commonPayload,
            siteArea: registerForm.siteArea.trim(),
            serviceType: registerForm.serviceType.trim(),
            serviceName: registerForm.serviceName.trim(),
            locationName: registerForm.locationName.trim(),
            active: true,
          })
        : await registerAdmin({
            ...commonPayload,
            role: "admin_user",
          });

      setNotice(response.message || "Registration completed.");
      setRegisterForm({
        role: "admin_user",
        fullName: "",
        email: "",
        password: "",
        siteArea: "",
        serviceType: "",
        serviceName: "",
        locationName: "",
        superAdminCode: "",
      });
      setRegistrationRequested(false);
      setRegisterOpen(false);
    } catch (err) {
      setError(err.message || "Unable to complete registration.");
    } finally {
      setBusy(false);
    }
  }

  async function handleResetConfirm() {
    if (!resetCode || !newPassword) {
      setError("Enter the reset code and new password.");
      return;
    }

    setBusy(true);
    setError("");
    setNotice("");
    try {
      const response = await confirmPasswordReset({
        email: String(email).trim(),
        role: resetRole,
        code: resetCode,
        newPassword,
      });
      setNotice(response.message || "Password reset successfully.");
      setResetOpen(false);
      setResetCode("");
      setNewPassword("");
      setPassword("");
    } catch (err) {
      setError(err.message || "Unable to reset password.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="login-shell">
      <section className="login-left-panel">
        <div className="pattern-circle one" aria-hidden="true" />
        <div className="pattern-circle two" aria-hidden="true" />
        <div className="pattern-wave" aria-hidden="true" />

        <div className="login-left-content">
          <div className="login-brand-mark">
            <img
              src={`${process.env.PUBLIC_URL}/lloyds-metals-logo.svg`}
              alt="Lloyds Metals & Energy"
            />
          </div>

          <div className="login-copy-block">
            <p className="login-kicker">Admin Portal</p>
            <h1>MY VOICE</h1>
            <p>
              Monitor tickets, manage teams, and coordinate admin operations across plant,
              guesthouse, colony, and hostel services.
            </p>
          </div>
        </div>
      </section>

      <section className="login-right-panel">
        <div className="login-card">
          <div className="login-card-header">
            <p>Welcome back</p>
            <h2>Login to continue</h2>
          </div>

          <form className="login-form" onSubmit={handleSubmit}>
            <label>
              <span>Email address</span>
              <input
                type="email"
                placeholder="Enter your email"
                value={email}
                onChange={(event) => setEmail(event.target.value)}
                autoComplete="username"
                disabled={busy}
                required
              />
            </label>

            <label>
              <span>Password</span>
              <input
                type="password"
                placeholder="Enter your password"
                value={password}
                onChange={(event) => setPassword(event.target.value)}
                autoComplete="current-password"
                disabled={busy}
                required
              />
            </label>

            <div className="login-meta-row">
              <label className="remember-check">
                <input
                  type="checkbox"
                  checked={remember}
                  onChange={(event) => setRemember(event.target.checked)}
                  disabled={busy}
                />
                <span>Remember me</span>
              </label>

              <button
                type="button"
                className="link-button"
                onClick={handleResetRequest}
                disabled={busy}
              >
                Forgot password?
              </button>
            </div>

            {notice ? <div className="login-inline-alert success">{notice}</div> : null}
            {error ? <div className="login-inline-alert">{error}</div> : null}

            {resetOpen ? (
              <div className="reset-panel">
                <label>
                  <span>Reset code</span>
                  <input
                    value={resetCode}
                    onChange={(event) => setResetCode(event.target.value)}
                    placeholder="Enter email code"
                    disabled={busy}
                  />
                </label>
                <label>
                  <span>New password</span>
                  <input
                    type="password"
                    value={newPassword}
                    onChange={(event) => setNewPassword(event.target.value)}
                    placeholder="Enter new password"
                    disabled={busy}
                  />
                </label>
                <button className="login-secondary-btn" type="button" onClick={handleResetConfirm} disabled={busy}>
                  Reset password
                </button>
              </div>
            ) : null}

            <button className="login-primary-btn" type="submit" disabled={!canSubmit}>
              {busy ? (
                <>
                  <MDBSpinner size="sm" className="me-2" />
                  Signing in
                </>
              ) : (
                "Login"
              )}
            </button>

            <button
              className="login-secondary-btn"
              type="button"
              onClick={() => {
                setRegisterOpen((current) => !current);
                setError("");
                setNotice("");
              }}
              disabled={busy}
            >
              {registerOpen ? "Close registration" : "Register admin or service person"}
            </button>

            {registerOpen ? (
              <div className="registration-panel">
                <div className="registration-mode-row">
                  <button
                    type="button"
                    className={registerForm.role === "admin_user" ? "registration-mode active" : "registration-mode"}
                    onClick={() => switchRegistrationRole("admin_user")}
                    disabled={busy}
                  >
                    Admin
                  </button>
                  <button
                    type="button"
                    className={registerForm.role === "service_person" ? "registration-mode active" : "registration-mode"}
                    onClick={() => switchRegistrationRole("service_person")}
                    disabled={busy}
                  >
                    Service person
                  </button>
                </div>

                <label>
                  <span>Full name</span>
                  <input
                    value={registerForm.fullName}
                    onChange={(event) => updateRegisterForm("fullName", event.target.value)}
                    placeholder="Enter full name"
                    disabled={busy}
                  />
                </label>
                <label>
                  <span>Email address</span>
                  <input
                    type="email"
                    value={registerForm.email}
                    onChange={(event) => updateRegisterForm("email", event.target.value)}
                    placeholder="Enter staff email"
                    disabled={busy}
                  />
                </label>

                <button
                  className="login-secondary-btn"
                  type="button"
                  onClick={handleRegistrationCodeRequest}
                  disabled={busy || !registerForm.fullName.trim() || !isValidEmail(registerForm.email)}
                >
                  Send registration OTP
                </button>

                {registrationRequested ? (
                  <>
                    <label>
                      <span>Password</span>
                      <input
                        type="password"
                        value={registerForm.password}
                        onChange={(event) => updateRegisterForm("password", event.target.value)}
                        placeholder="Create password"
                        disabled={busy}
                      />
                    </label>
                    <label>
                      <span>Super admin OTP</span>
                      <input
                        value={registerForm.superAdminCode}
                        onChange={(event) => updateRegisterForm("superAdminCode", event.target.value)}
                        placeholder="Code sent to super admin"
                        disabled={busy}
                      />
                    </label>

                    {isServiceRegistration ? (
                      <div className="registration-code-grid">
                        <label>
                          <span>Service area</span>
                          <input
                            value={registerForm.siteArea}
                            onChange={(event) => updateRegisterForm("siteArea", event.target.value)}
                            placeholder="Plant, colony, hostel..."
                            disabled={busy}
                          />
                        </label>
                        <label>
                          <span>Service type</span>
                          <input
                            value={registerForm.serviceType}
                            onChange={(event) => updateRegisterForm("serviceType", event.target.value)}
                            placeholder="Electrical, housekeeping..."
                            disabled={busy}
                          />
                        </label>
                        <label>
                          <span>Service name</span>
                          <input
                            value={registerForm.serviceName}
                            onChange={(event) => updateRegisterForm("serviceName", event.target.value)}
                            placeholder="Optional"
                            disabled={busy}
                          />
                        </label>
                        <label>
                          <span>Location</span>
                          <input
                            value={registerForm.locationName}
                            onChange={(event) => updateRegisterForm("locationName", event.target.value)}
                            placeholder="Optional"
                            disabled={busy}
                          />
                        </label>
                      </div>
                    ) : null}

                    <button className="login-primary-btn" type="button" onClick={handleRegistrationSubmit} disabled={busy}>
                      Complete registration
                    </button>
                  </>
                ) : null}
              </div>
            ) : null}

            <div className="login-footnote"></div>
          </form>

          
        </div>
      </section>
    </div>
  );
}
