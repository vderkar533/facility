import React, { useMemo, useState } from "react";
import { login } from "../api/client";

function isValidEmail(value) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(value || "").trim());
}

export default function Login() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [remember, setRemember] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [user, setUser] = useState(() => {
    try {
      const raw = localStorage.getItem("ism_user");
      return raw ? JSON.parse(raw) : null;
    } catch {
      return null;
    }
  });

  const canSubmit = useMemo(() => {
    return isValidEmail(email) && String(password).length >= 1 && !busy;
  }, [email, password, busy]);

  async function onSubmit(event) {
    event.preventDefault();
    setError("");
    setBusy(true);
    try {
      const result = await login({ email: String(email).trim(), password });
      setUser(result.user);
      if (remember) {
        localStorage.setItem("ism_user", JSON.stringify(result.user));
      } else {
        localStorage.removeItem("ism_user");
      }
    } catch (err) {
      setUser(null);
      setError(err?.message || "Unable to login.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="page">
      <div className="bgGlow" aria-hidden="true" />

      <main className="card" role="main">
        <header className="brand">
          <img
            className="logo"
            src={`${process.env.PUBLIC_URL}/lloyds-metals-logo.svg`}
            alt="Lloyds Metals & Energy"
          />
          <div className="brandText">
            <h1>MY VOICE</h1>
            <p>Sign in to continue</p>
          </div>
        </header>

        {user ? (
          <section className="success" aria-live="polite">
            <div className="successTitle">Login successful</div>
            <div className="successBody">
              Signed in as <strong>{user.fullName}</strong> ({user.role})
            </div>
            <div className="successHint">
              Next: hook this screen to your dashboard routes.
            </div>
          </section>
        ) : (
          <form className="form" onSubmit={onSubmit}>
            <label className="field">
              <span>Email</span>
              <input
                type="email"
                inputMode="email"
                autoComplete="username"
                placeholder="name@company.com"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                disabled={busy}
                required
              />
            </label>

            <label className="field">
              <span>Password</span>
              <input
                type="password"
                autoComplete="current-password"
                placeholder="..."
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                disabled={busy}
                required
              />
            </label>

            <div className="row">
              <label className="checkbox">
                <input
                  type="checkbox"
                  checked={remember}
                  onChange={(e) => setRemember(e.target.checked)}
                  disabled={busy}
                />
                <span>Remember me</span>
              </label>

              <div className="meta">Backend: `POST /api/auth/login`</div>
            </div>

            {error ? (
              <div className="error" role="alert">
                {error}
              </div>
            ) : null}

            <button className="button" type="submit" disabled={!canSubmit}>
              {busy ? "Signing in..." : "Sign in"}
            </button>

            <div className="footnote">
              If you're running the backend locally, start it with{" "}
              <code>npm run dev</code> in <code>backend</code>.
            </div>
          </form>
        )}
      </main>

      <footer className="footer">
        Copyright {new Date().getFullYear()} Lloyds Metals - MY VOICE
      </footer>
    </div>
  );
}
