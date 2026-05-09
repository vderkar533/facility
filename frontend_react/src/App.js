import React, { useState } from "react";
import "@fortawesome/fontawesome-free/css/all.min.css";
import "mdb-react-ui-kit/dist/css/mdb.min.css";
import "./Login.css";
import Login from "./Login";
import Dashboard from "./Dashboard";
import { logout } from "./api/client";

export default function App() {
  const [user, setUser] = useState(() => {
    try {
      const raw = localStorage.getItem("ism_user");
      return raw ? JSON.parse(raw) : null;
    } catch {
      return null;
    }
  });

  function handleLoginSuccess(nextUser, remember) {
    setUser(nextUser);
    if (remember) {
      localStorage.setItem("ism_user", JSON.stringify(nextUser));
    } else {
      localStorage.removeItem("ism_user");
    }
  }

  async function handleLogout() {
    const sessionId = sessionStorage.getItem("ism_session_id");
    try {
      if (sessionId) await logout(sessionId);
    } catch (_err) {
      // Local logout should still complete if the backend is unavailable.
    }
    localStorage.removeItem("ism_user");
    sessionStorage.removeItem("ism_session_id");
    sessionStorage.removeItem("ism_refresh_token");
    setUser(null);
  }

  if (!user) {
    return <Login onLoginSuccess={handleLoginSuccess} />;
  }

  return <Dashboard user={user} onLogout={handleLogout} />;
}
