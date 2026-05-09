const DEFAULT_API_BASE_URL =
  process.env.NODE_ENV === "development" ? "http://localhost:4000" : "";
const API_BASE_URL = (process.env.REACT_APP_API_BASE_URL || DEFAULT_API_BASE_URL).replace(/\/+$/, "");

async function request(path, options = {}) {
  const url = `${API_BASE_URL}${path}`;
  const response = await fetch(url, {
    headers: {
      "Content-Type": "application/json",
      ...(options.headers || {}),
    },
    ...options,
  });

  let data = null;
  try {
    data = await response.json();
  } catch {
    data = null;
  }

  if (!response.ok) {
    const message = data?.message || `Request failed (${response.status})`;
    const error = new Error(message);
    error.status = response.status;
    error.data = data;
    throw error;
  }

  return data;
}

export async function login({ email, password, role }) {
  return request("/api/auth/login", {
    method: "POST",
    body: JSON.stringify({ email, password, role }),
  });
}

export async function logout(sessionId) {
  return request("/api/auth/logout", {
    method: "POST",
    body: JSON.stringify({ sessionId }),
  });
}

export async function requestPasswordReset(payload) {
  return request("/api/auth/password-reset/request", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export async function confirmPasswordReset(payload) {
  return request("/api/auth/password-reset/confirm", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export async function requestRegistrationCodes(payload) {
  return request("/api/auth/registration/request", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export async function registerAdmin(payload) {
  return request("/api/admin-users/register", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export async function getCatalogOptions() {
  return request("/api/catalog/options");
}

export async function addCatalogLocation(payload) {
  return request("/api/catalog/locations", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export async function addCatalogService(payload) {
  return request("/api/catalog/services", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export async function deleteCatalogLocation(payload) {
  const query = new URLSearchParams();
  query.set("siteArea", payload.siteArea);
  query.set("locationName", payload.locationName);
  return request(`/api/catalog/locations?${query.toString()}`, {
    method: "DELETE",
  });
}

export async function deleteCatalogService(payload) {
  const query = new URLSearchParams();
  query.set("siteArea", payload.siteArea);
  query.set("serviceType", payload.serviceType);
  query.set("serviceName", payload.serviceName);
  return request(`/api/catalog/services?${query.toString()}`, {
    method: "DELETE",
  });
}

export async function getTickets(params = {}) {
  const query = new URLSearchParams();
  Object.entries(params).forEach(([key, value]) => {
    if (value !== undefined && value !== null && value !== "") {
      query.set(key, value);
    }
  });

  const path = query.toString() ? `/api/tickets?${query.toString()}` : "/api/tickets";
  return request(path);
}

export async function getTicketEvents(ticketId) {
  return request(`/api/tickets/${ticketId}/events`);
}

export async function getAssignees(params = {}) {
  const query = new URLSearchParams();
  Object.entries(params).forEach(([key, value]) => {
    if (value !== undefined && value !== null && value !== "") {
      query.set(key, value);
    }
  });

  return request(`/api/assignees?${query.toString()}`);
}

export async function assignTicket(ticketId, payload) {
  return request(`/api/tickets/${ticketId}/assign`, {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export async function updateTicketStatus(ticketId, payload) {
  return request(`/api/tickets/${ticketId}/status`, {
    method: "PATCH",
    body: JSON.stringify(payload),
  });
}

export async function getServicePeople(params = {}) {
  const query = new URLSearchParams();
  Object.entries(params).forEach(([key, value]) => {
    if (value !== undefined && value !== null && value !== "") {
      query.set(key, value);
    }
  });

  const path = query.toString() ? `/api/service-people?${query.toString()}` : "/api/service-people";
  return request(path);
}

export async function createServicePerson(payload) {
  return request("/api/service-people", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export async function deleteServicePerson(id) {
  return request(`/api/service-people/${id}`, {
    method: "DELETE",
  });
}
