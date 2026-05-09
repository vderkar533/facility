import React, { useEffect, useState } from "react";
import { MDBBtn, MDBIcon, MDBSpinner } from "mdb-react-ui-kit";
import {
  addCatalogLocation,
  addCatalogService,
  assignTicket,
  createServicePerson,
  deleteCatalogLocation,
  deleteCatalogService,
  deleteServicePerson,
  getAssignees,
  getCatalogOptions,
  getServicePeople,
  getTicketEvents,
  getTickets,
  registerAdmin,
  requestRegistrationCodes,
  updateTicketStatus,
} from "./api/client";

const ADMIN_ROLES = ["admin", "admin_user", "super_admin"];
const SITE_KEYS = ["Plant", "Guesthouse", "Colony", "Hostel"];
const NAV_ITEMS = [
  ["home", "Home", "chart-line"],
  ["plant", "Plant", "industry"],
  ["guesthouse", "Guesthouse", "hotel"],
  ["colony", "Colony", "city"],
  ["hostel", "Hostel", "building"],
  ["escalations", "Escalations", "triangle-exclamation"],
  ["catalog", "Service Management", "sliders"],
  ["service", "Service Group", "users"],
];

function titleCase(value) {
  return String(value || "").replace(/_/g, " ").replace(/\b\w/g, (char) => char.toUpperCase());
}

function formatDate(value) {
  if (!value) return "-";
  try {
    return new Intl.DateTimeFormat("en-IN", { dateStyle: "medium", timeStyle: "short" }).format(new Date(value));
  } catch {
    return value;
  }
}

function countBy(items, keyFn) {
  return items.reduce((acc, item) => {
    const key = keyFn(item);
    acc[key] = (acc[key] || 0) + 1;
    return acc;
  }, {});
}

function summaryFor(tickets) {
  const statuses = countBy(tickets, (item) => item.status || "Unknown");
  const sites = countBy(tickets, (item) => item.siteArea || "Unknown");
  const services = countBy(tickets, (item) => `${item.serviceType} / ${item.serviceName}`);

  return {
    total: tickets.length,
    open: statuses.Open || 0,
    hold: statuses.Hold || 0,
    resolved: statuses.Resolved || 0,
    cancelled: statuses.Cancelled || 0,
    escalated: tickets.filter((item) => Number(item.escalationLevel) > 0).length,
    assigned: tickets.filter((item) => item.assignedPerson).length,
    sites,
    topServices: Object.entries(services)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5),
  };
}

function uniqueValues(values) {
  return Array.from(new Set(values.filter(Boolean)));
}

function buildServiceExplorer(servicePeople) {
  const sites = uniqueValues(servicePeople.map((person) => person.siteArea));

  return sites.map((siteArea) => {
    const sitePeople = servicePeople.filter((person) => person.siteArea === siteArea);
    const serviceTypes = uniqueValues(sitePeople.map((person) => person.serviceType)).map((serviceType) => {
      const typePeople = sitePeople.filter((person) => person.serviceType === serviceType);
      const serviceNames = uniqueValues(
        typePeople.map((person) => person.serviceName || "General Assignment")
      );

      const services = serviceNames.map((serviceName) => {
        const servicePeopleForName = typePeople.filter((person) => {
          const currentName = person.serviceName || "General Assignment";
          return currentName === serviceName;
        });

        const locations = uniqueValues(
          servicePeopleForName.map((person) => person.locationName || "All Locations")
        ).map((locationName) => {
          const members = servicePeopleForName.filter((person) => {
            const currentLocation = person.locationName || "All Locations";
            return currentLocation === locationName;
          });

          return {
            locationName,
            members,
            count: members.length,
          };
        });

        return {
          serviceName,
          count: servicePeopleForName.length,
          members: servicePeopleForName,
          locations,
        };
      });

      return {
        serviceType,
        count: typePeople.length,
        members: typePeople,
        services,
      };
    });

    return {
      siteArea,
      count: sitePeople.length,
      serviceTypes,
    };
  });
}

function getSiteMatrixSummary(siteNode) {
  if (!siteNode) {
    return { totalPeople: 0, coveredTypes: 0, coveredServices: 0 };
  }

  return {
    totalPeople: siteNode.count,
    coveredTypes: siteNode.serviceTypes.filter((serviceType) => serviceType.count > 0).length,
    coveredServices: siteNode.serviceTypes.reduce(
      (total, serviceType) => total + serviceType.services.filter((service) => service.count > 0).length,
      0
    ),
  };
}

export default function Dashboard({ user, onLogout }) {
  const isAdmin = ADMIN_ROLES.includes(String(user?.role || "").toLowerCase());
  const [sidebarOpen, setSidebarOpen] = useState(true);
  const [activeSection, setActiveSection] = useState("home");
  const [catalog, setCatalog] = useState({ sites: [], serviceCatalog: {}, locationCatalog: {} });
  const [tickets, setTickets] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [message, setMessage] = useState("");
  const [selectedTicket, setSelectedTicket] = useState(null);
  const [events, setEvents] = useState([]);
  const [eventsLoading, setEventsLoading] = useState(false);
  const [assignees, setAssignees] = useState([]);
  const [assigneesLoading, setAssigneesLoading] = useState(false);
  const [selectedAssigneeId, setSelectedAssigneeId] = useState("");
  const [statusDraft, setStatusDraft] = useState("");
  const [statusRemark, setStatusRemark] = useState("");
  const [servicePeopleData, setServicePeopleData] = useState({
    servicePeople: [],
    combinationSummary: [],
    tree: {},
  });
  const [servicePeopleLoading, setServicePeopleLoading] = useState(false);
  const [serviceForm, setServiceForm] = useState({
    fullName: "",
    email: "",
    password: "service123",
    siteArea: "Plant",
    serviceType: "",
    serviceName: "",
    locationName: "",
    active: true,
    superAdminCode: "",
  });
  const [catalogLocationForm, setCatalogLocationForm] = useState({
    siteArea: "Plant",
    locationName: "",
  });
  const [catalogServiceForm, setCatalogServiceForm] = useState({
    siteArea: "Plant",
    serviceType: "",
    serviceName: "",
  });
  const [adminForm, setAdminForm] = useState({
    fullName: "",
    email: "",
    password: "",
    role: "admin_user",
    superAdminCode: "",
  });
  const [serviceExplorer, setServiceExplorer] = useState({
    siteArea: "Plant",
    serviceType: "",
    serviceName: "",
  });
  const [deletePersonId, setDeletePersonId] = useState("");
  const [searchTerm, setSearchTerm] = useState("");

  function toggleTicket(ticket) {
    setSelectedTicket((current) => (current?.id === ticket.id ? null : ticket));
  }

  function setServiceExplorerFromSite(siteArea, tree = serviceExplorerTree) {
    const siteNode = tree.find((site) => site.siteArea === siteArea);
    setServiceExplorer({
      siteArea,
      serviceType: siteNode?.serviceTypes[0]?.serviceType || "",
      serviceName: siteNode?.serviceTypes[0]?.services[0]?.serviceName || "",
    });
  }

  async function loadServicePeopleData() {
    if (!isAdmin) return;
    setServicePeopleLoading(true);
    try {
      const response = await getServicePeople({ includeInactive: true });
      setServicePeopleData({
        servicePeople: response.servicePeople || [],
        combinationSummary: response.combinationSummary || [],
        tree: response.tree || {},
      });
    } catch (err) {
      setServicePeopleData({
        servicePeople: [],
        combinationSummary: [],
        tree: {},
      });
      setError(err.message || "Unable to load service people.");
    } finally {
      setServicePeopleLoading(false);
    }
  }

  async function loadData() {
    if (!isAdmin) return;
    setLoading(true);
    setError("");
    try {
      const [catalogResponse, ticketResponse] = await Promise.all([
        getCatalogOptions(),
        getTickets({ role: user.role, userId: user.id }),
      ]);
      setCatalog(catalogResponse);
      setTickets(ticketResponse.tickets || []);
      setServiceForm((current) => ({
        ...current,
        siteArea: catalogResponse.sites?.[0] || current.siteArea || "Plant",
      }));
      setServiceExplorer((current) => ({
        ...current,
        siteArea: catalogResponse.sites?.[0] || current.siteArea || "Plant",
      }));
      setCatalogLocationForm((current) => ({
        ...current,
        siteArea: catalogResponse.sites?.[0] || current.siteArea || "Plant",
      }));
      setCatalogServiceForm((current) => ({
        ...current,
        siteArea: catalogResponse.sites?.[0] || current.siteArea || "Plant",
      }));
    } catch (err) {
      setError(err.message || "Unable to load admin dashboard.");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadData();
  }, [user.id]);

  useEffect(() => {
    if (!selectedTicket || !isAdmin) {
      setEvents([]);
      setAssignees([]);
      return;
    }
    setStatusDraft(selectedTicket.status === "Open" ? "Hold" : "Resolved");
    setStatusRemark(selectedTicket.adminRemark || "");
    setSelectedAssigneeId(selectedTicket.assignedPerson?.id ? String(selectedTicket.assignedPerson.id) : "");

    setEventsLoading(true);
    getTicketEvents(selectedTicket.id)
      .then((response) => setEvents(response.events || []))
      .catch(() => setEvents([]))
      .finally(() => setEventsLoading(false));

    setAssigneesLoading(true);
    getAssignees({
      siteArea: selectedTicket.siteArea,
      serviceType: selectedTicket.serviceType,
      serviceName: selectedTicket.serviceName,
      locationName: selectedTicket.locationName,
    })
      .then((response) => setAssignees(response.assignees || []))
      .catch(() => setAssignees([]))
      .finally(() => setAssigneesLoading(false));
  }, [selectedTicket, isAdmin]);

  useEffect(() => {
    if (activeSection === "service") {
      loadServicePeopleData();
    }
  }, [activeSection, isAdmin]);

  useEffect(() => {
    setSelectedTicket(null);
  }, [activeSection]);

  useEffect(() => {
    if (!error && !message) return undefined;

    const timeoutId = window.setTimeout(() => {
      setError("");
      setMessage("");
    }, 3000);

    return () => window.clearTimeout(timeoutId);
  }, [error, message]);

  async function onAssign() {
    if (!selectedTicket || !selectedAssigneeId) return;
    setError("");
    setMessage("");
    try {
      const response = await assignTicket(selectedTicket.id, {
        personId: Number(selectedAssigneeId),
        adminUserId: user.id,
      });
      setMessage(response.message || "Ticket assigned.");
      setSelectedTicket(response.ticket);
      await loadData();
    } catch (err) {
      setError(err.message || "Unable to assign ticket.");
    }
  }

  async function onStatusUpdate() {
    if (!selectedTicket || !statusDraft) return;
    setError("");
    setMessage("");
    try {
      const response = await updateTicketStatus(selectedTicket.id, {
        status: statusDraft,
        adminRemark: statusRemark,
        adminUserId: user.id,
      });
      setMessage(response.message || "Ticket updated.");
      setSelectedTicket(response.ticket);
      await loadData();
    } catch (err) {
      setError(err.message || "Unable to update ticket.");
    }
  }

  async function onCreateServicePerson(event) {
    event.preventDefault();
    setError("");
    setMessage("");
    try {
      const response = await createServicePerson(serviceForm);
      setMessage(response.message || "Service person registered.");
      setServiceForm((current) => ({
        ...current,
        fullName: "",
        email: "",
        password: "service123",
        serviceName: "",
        locationName: "",
        superAdminCode: "",
      }));
      await loadServicePeopleData();
    } catch (err) {
      setError(err.message || "Unable to register service person.");
    }
  }

  async function onAddCatalogLocation(event) {
    event.preventDefault();
    setError("");
    setMessage("");
    try {
      const response = await addCatalogLocation(catalogLocationForm);
      setCatalog(response.catalog || catalog);
      setCatalogLocationForm((current) => ({ ...current, locationName: "" }));
      setMessage(response.message || "Location added.");
    } catch (err) {
      setError(err.message || "Unable to add location.");
    }
  }

  async function onAddCatalogService(event) {
    event.preventDefault();
    setError("");
    setMessage("");
    try {
      const response = await addCatalogService(catalogServiceForm);
      setCatalog(response.catalog || catalog);
      setServiceForm((current) => ({
        ...current,
        siteArea: catalogServiceForm.siteArea,
        serviceType: catalogServiceForm.serviceType,
        serviceName: catalogServiceForm.serviceName,
      }));
      setCatalogLocationForm((current) => ({ ...current, siteArea: catalogServiceForm.siteArea }));
      setCatalogServiceForm((current) => ({ ...current, serviceName: "" }));
      setMessage(response.message || "Service added.");
    } catch (err) {
      setError(err.message || "Unable to add service.");
    }
  }

  async function onDeleteCatalogLocation(locationName) {
    setError("");
    setMessage("");
    try {
      const response = await deleteCatalogLocation({
        siteArea: catalogLocationForm.siteArea,
        locationName,
      });
      setCatalog(response.catalog || catalog);
      setMessage(response.message || "Location deleted.");
    } catch (err) {
      setError(err.message || "Unable to delete location.");
    }
  }

  async function onDeleteCatalogService(serviceType, serviceName) {
    setError("");
    setMessage("");
    try {
      const response = await deleteCatalogService({
        siteArea: catalogLocationForm.siteArea,
        serviceType,
        serviceName,
      });
      setCatalog(response.catalog || catalog);
      setMessage(response.message || "Service deleted.");
    } catch (err) {
      setError(err.message || "Unable to delete service.");
    }
  }

  async function onRequestServiceCodes() {
    setError("");
    setMessage("");
    try {
      const response = await requestRegistrationCodes({
        fullName: serviceForm.fullName,
        email: serviceForm.email,
        role: "service_person",
      });
      setMessage(response.message || "Registration OTP sent to super admin email.");
    } catch (err) {
      setError(err.message || "Unable to send registration codes.");
    }
  }

  async function onRequestAdminCodes() {
    setError("");
    setMessage("");
    try {
      const response = await requestRegistrationCodes({
        fullName: adminForm.fullName,
        email: adminForm.email,
        role: adminForm.role,
      });
      setMessage(response.message || "Registration OTP sent to super admin email.");
    } catch (err) {
      setError(err.message || "Unable to send registration codes.");
    }
  }

  async function onCreateAdmin(event) {
    event.preventDefault();
    setError("");
    setMessage("");
    try {
      const response = await registerAdmin(adminForm);
      setMessage(response.message || "Admin registered.");
      setAdminForm({
        fullName: "",
        email: "",
        password: "",
        role: "admin_user",
        superAdminCode: "",
      });
    } catch (err) {
      setError(err.message || "Unable to register admin.");
    }
  }

  async function onDeleteServicePerson(id) {
    setError("");
    setMessage("");
    try {
      const response = await deleteServicePerson(id);
      setMessage(response.message || "Service person deleted.");
      setDeletePersonId("");
      await loadServicePeopleData();
    } catch (err) {
      setError(err.message || "Unable to delete service person.");
    }
  }

  if (!isAdmin) {
    return (
      <div className="admin-access-shell">
        <div className="admin-access-card">
          <div className="admin-access-badge">Admin View Only</div>
          <h1>This React portal is available for admin roles only.</h1>
          <p>Login worked, but this interface intentionally exposes only the administrator perspective.</p>
          <MDBBtn onClick={onLogout}>Sign out</MDBBtn>
        </div>
      </div>
    );
  }

  const summary = summaryFor(tickets);
  const currentSite = activeSection === "home" || activeSection === "escalations" || activeSection === "service" || activeSection === "catalog"
    ? null
    : titleCase(activeSection);
  const visibleTickets = currentSite ? tickets.filter((item) => item.siteArea === currentSite) : tickets;
  const serviceTypes = Object.keys(catalog.serviceCatalog?.[serviceForm.siteArea] || {});
  const serviceNames = catalog.serviceCatalog?.[serviceForm.siteArea]?.[serviceForm.serviceType] || [];
  const locations = catalog.locationCatalog?.[serviceForm.siteArea] || [];
  const catalogSites = catalog.sites?.length ? catalog.sites : SITE_KEYS;
  const catalogServiceTypes = Object.keys(catalog.serviceCatalog?.[catalogServiceForm.siteArea] || {});
  const selectedCatalogLocations = catalog.locationCatalog?.[catalogLocationForm.siteArea] || [];
  const selectedCatalogServices = catalog.serviceCatalog?.[catalogLocationForm.siteArea] || {};
  const escalatedTickets = tickets.filter((item) => Number(item.escalationLevel) > 0 || Number(item.reopenCount) > 0);
  const searchedTickets = (activeSection === "escalations" ? escalatedTickets : visibleTickets).filter((ticket) => {
    const needle = String(searchTerm || "").trim().toLowerCase();
    if (!needle) return true;

    return [
      ticket.ticketNumber,
      ticket.siteArea,
      ticket.serviceType,
      ticket.serviceName,
      ticket.locationName,
      ticket.status,
      ticket.requestedBy,
      ticket.assignedPerson?.fullName,
    ]
      .filter(Boolean)
      .some((value) => String(value).toLowerCase().includes(needle));
  });
  const serviceExplorerTree = buildServiceExplorer(servicePeopleData.servicePeople || []);

  useEffect(() => {
    if (!serviceExplorerTree.length) return;

    const hasCurrentSite = serviceExplorerTree.some((site) => site.siteArea === serviceExplorer.siteArea);
    if (hasCurrentSite) return;

    const firstSite = serviceExplorerTree[0];
    setServiceExplorer({
      siteArea: firstSite.siteArea,
      serviceType: firstSite.serviceTypes[0]?.serviceType || "",
      serviceName: firstSite.serviceTypes[0]?.services[0]?.serviceName || "",
    });
  }, [serviceExplorer.siteArea, serviceExplorerTree]);

  const selectedSiteNode =
    serviceExplorerTree.find((site) => site.siteArea === serviceExplorer.siteArea) || serviceExplorerTree[0];
  const selectedTypeNode =
    selectedSiteNode?.serviceTypes.find((type) => type.serviceType === serviceExplorer.serviceType) ||
    selectedSiteNode?.serviceTypes[0];
  const selectedServiceNode =
    selectedTypeNode?.services.find((service) => service.serviceName === serviceExplorer.serviceName) ||
    selectedTypeNode?.services[0];
  const peopleBySite = catalogSites.map((siteArea) => ({
    siteArea,
    count: servicePeopleData.servicePeople.filter((person) => person.siteArea === siteArea).length,
  }));
  const deleteCandidates = servicePeopleData.servicePeople
    .slice()
    .sort((a, b) => `${a.siteArea}${a.serviceType}${a.fullName}`.localeCompare(`${b.siteArea}${b.serviceType}${b.fullName}`));
  const selectedDeletePerson =
    deleteCandidates.find((person) => String(person.id) === String(deletePersonId)) || null;
  const allowedStatuses = selectedTicket?.status === "Open"
    ? ["Hold", "Resolved", "Cancelled"]
    : selectedTicket?.status === "Hold"
      ? ["Resolved", "Cancelled"]
      : [];
  const ticketPanelSections = ["home", "plant", "guesthouse", "colony", "hostel", "escalations"];
  const showTicketPanel = ticketPanelSections.includes(activeSection) && !!selectedTicket;
  const shouldShowTicketList = activeSection !== "service" && activeSection !== "catalog";

  return (
    <div className="admin-shell">
      <aside className={`admin-sidebar ${sidebarOpen ? "is-open" : "is-collapsed"}`}>
        <div className="sidebar-brand">
           {/* <div className="sidebar-logo">LMEL</div> */}
          {sidebarOpen ? (
            <div>
              <div className="sidebar-brand-title">MY VOICE</div>
              <div className="sidebar-brand-copy">Admin control panel</div>
            </div>
          ) : null} 
        </div>
        <nav className="sidebar-nav">
          {NAV_ITEMS.map(([key, label, icon]) => (
            <button key={key} type="button" className={`sidebar-link ${activeSection === key ? "active" : ""}`} onClick={() => setActiveSection(key)}>
              <MDBIcon fas icon={icon} className="sidebar-link-icon" />
              {sidebarOpen ? <span>{label}</span> : null}
            </button>
          ))}
        </nav>
        <div className="sidebar-footer">
          {sidebarOpen ? (
            <>
              <div className="sidebar-user-name">{user.fullName}</div>
              <div className="sidebar-user-role">{titleCase(user.role)}</div>
            </>
          ) : null}
          <button className="sidebar-ghost-link" type="button" onClick={onLogout}>
            <MDBIcon fas icon="right-from-bracket" className="sidebar-link-icon" />
            {sidebarOpen ? <span>Logout</span> : null}
          </button>
        </div>
      </aside>

      <main className="admin-content">
        <header className="admin-topbar">
          <div className="admin-topbar-left">
            <MDBBtn color="dark" className="admin-menu-button" onClick={() => setSidebarOpen((value) => !value)}>
              <MDBIcon fas icon="bars" />
            </MDBBtn>
          </div>
          <div className="admin-topbar-meta">
            {shouldShowTicketList ? (
              <label className="topbar-search">
                <MDBIcon fas icon="magnifying-glass" />
                <input
                  type="search"
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                  placeholder={
                    activeSection === "escalations"
                      ? "Search escalated tickets"
                      : currentSite
                        ? `Search ${currentSite} tickets`
                        : "Search tickets"
                  }
                />
              </label>
            ) : null}
            <button className="soft-chip" type="button" onClick={loadData}>
              <MDBIcon fas icon="arrows-rotate" className="me-2" />
              Refresh
            </button>
          </div>
        </header>

        {(error || message) ? (
          <div className="screen-alert-stack" aria-live="polite">
            {error ? <div className="admin-alert error">{error}</div> : null}
            {message ? <div className="admin-alert success">{message}</div> : null}
          </div>
        ) : null}

        {loading ? (
          <div className="loading-panel">
            <MDBSpinner grow color="primary" />
            <span>Loading admin dashboard from backend...</span>
          </div>
        ) : (
          <section className={`admin-main-grid ${showTicketPanel ? "with-detail-panel" : "without-detail-panel"}`}>
            <div className="admin-primary-column">
              {activeSection === "home" ? (
                <>
                  <section className="hero-panel">
                    <div>
                      <h3>ADMIN OVERVIEW</h3>
                      
                      <p>Track backend ticket flow, focus on escalations, and manage service delivery across all facilities.</p>
                    </div>
                    <div className="hero-stat-grid">
                      <StatCard label="Total tickets" value={summary.total} icon="ticket" />
                      <StatCard label="Open" value={summary.open} icon="folder-open" />
                      <StatCard label="Assigned" value={summary.assigned} icon="user-check" />
                      <StatCard label="Escalated" value={summary.escalated} icon="bolt" accent />
                    </div>
                  </section>
                  <section className="analytics-grid">
                    <div className="surface-card">
                      <div className="section-label">Status overview</div>
                      <div className="status-grid">
                        <StatusPill label="Open" value={summary.open} tone="blue" />
                        <StatusPill label="Hold" value={summary.hold} tone="amber" />
                        <StatusPill label="Resolved" value={summary.resolved} tone="green" />
                        <StatusPill label="Cancelled" value={summary.cancelled} tone="red" />
                      </div>
                    </div>
                    <div className="surface-card">
                      <div className="section-label">Site distribution</div>
                      <div className="metric-list">
                        {catalogSites.map((site) => <MetricRow key={site} label={site} value={summary.sites[site] || 0} total={summary.total || 1} />)}
                      </div>
                    </div>
                  </section>
                  <section className="surface-card">
                    <div className="section-header"><div><p className="section-label">Demand details</p><h3>Top service categories</h3></div></div>
                    <div className="metric-list">
                      {summary.topServices.map(([label, value]) => <MetricRow key={label} label={label} value={value} total={summary.total || 1} />)}
                    </div>
                  </section>
                </>
              ) : null}

              {currentSite ? (
                <>
                  <section className="site-hero-card">
                    <div>
                      <h3>{currentSite}</h3>
                      {/* <h2>{currentSite} admin workspace</h2> */}
                      <p>Admin-facing summary of services, locations, and backend ticket volume for {currentSite}.</p>
                    </div>
                    <div className="site-summary-strip">
                      <StatCard label="Tickets" value={visibleTickets.length} icon="layer-group" />
                      <StatCard label="Open" value={visibleTickets.filter((item) => item.status === "Open").length} icon="circle" />
                      <StatCard label="Escalations" value={visibleTickets.filter((item) => Number(item.escalationLevel) > 0).length} icon="triangle-exclamation" />
                    </div>
                  </section>
                </>
              ) : null}

              {activeSection === "escalations" ? (
                <section className="surface-card">
                  <div className="section-header"><div><h3>ESCALATIONS OVERVIEW</h3><h5>Tickets needing intervention</h5></div></div>
                  <div className="metric-list">
                    <MetricRow label="Reopened tickets" value={tickets.filter((item) => Number(item.reopenCount) > 0).length} total={tickets.length || 1} />
                    <MetricRow label="Active escalations" value={tickets.filter((item) => Number(item.escalationLevel) > 0).length} total={tickets.length || 1} />
                    <MetricRow label="Unassigned escalations" value={escalatedTickets.filter((item) => !item.assignedPerson).length} total={escalatedTickets.length || 1} />
                  </div>
                </section>
              ) : null}

              {activeSection === "catalog" ? (
                <>
                  <section className="surface-card">
                    <div className="section-header">
                      <div>
                        <p className="section-label">Service Management</p>
                        <h3>Add service locations and service names</h3>
                      </div>
                    </div>

                    <div className="catalog-management-grid">
                      <form className="surface-subcard service-form-grid catalog-form" onSubmit={onAddCatalogLocation}>
                        <div className="catalog-form-header">
                          <MDBIcon fas icon="location-dot" />
                          <div>
                            <strong>Add location</strong>
                            <span>Visible in ticket and service person dropdowns</span>
                          </div>
                        </div>
                        <label>
                          <span>Site area</span>
                          <select
                            value={catalogLocationForm.siteArea}
                            onChange={(e) =>
                              setCatalogLocationForm((current) => ({ ...current, siteArea: e.target.value }))
                            }
                          >
                            {catalogSites.map((site) => (
                              <option key={site} value={site}>{site}</option>
                            ))}
                          </select>
                        </label>
                        <label>
                          <span>Location name</span>
                          <input
                            value={catalogLocationForm.locationName}
                            onChange={(e) =>
                              setCatalogLocationForm((current) => ({ ...current, locationName: e.target.value }))
                            }
                            placeholder="Example: Admin Block Room 204"
                            required
                          />
                        </label>
                        <button className="primary-action" type="submit">Add location</button>
                      </form>

                      <form className="surface-subcard service-form-grid catalog-form" onSubmit={onAddCatalogService}>
                        <div className="catalog-form-header">
                          <MDBIcon fas icon="screwdriver-wrench" />
                          <div>
                            <strong>Add service</strong>
                            <span>Create a service inside a service type and area</span>
                          </div>
                        </div>
                        <label>
                          <span>Site area</span>
                          <select
                            value={catalogServiceForm.siteArea}
                            onChange={(e) =>
                              setCatalogServiceForm((current) => ({ ...current, siteArea: e.target.value, serviceType: "" }))
                            }
                          >
                            {catalogSites.map((site) => (
                              <option key={site} value={site}>{site}</option>
                            ))}
                          </select>
                        </label>
                        <label>
                          <span>Service type</span>
                          <input
                            list="catalog-service-types"
                            value={catalogServiceForm.serviceType}
                            onChange={(e) =>
                              setCatalogServiceForm((current) => ({ ...current, serviceType: e.target.value }))
                            }
                            placeholder="Example: Electrical"
                            required
                          />
                          <datalist id="catalog-service-types">
                            {catalogServiceTypes.map((type) => (
                              <option key={type} value={type} />
                            ))}
                          </datalist>
                        </label>
                        <label>
                          <span>Service name</span>
                          <input
                            value={catalogServiceForm.serviceName}
                            onChange={(e) =>
                              setCatalogServiceForm((current) => ({ ...current, serviceName: e.target.value }))
                            }
                            placeholder="Example: Switch Board Repair"
                            required
                          />
                        </label>
                        <button className="primary-action" type="submit">Add service</button>
                      </form>
                    </div>
                  </section>

                  <section className="surface-card">
                    <div className="section-header">
                      <div>
                        <p className="section-label">Current setup</p>
                        <h3>{catalogLocationForm.siteArea} locations and services</h3>
                      </div>
                    </div>
                    <div className="catalog-preview-grid">
                      <div className="surface-subcard">
                        <div className="catalog-preview-title">
                          <strong>Locations</strong>
                          <span>{selectedCatalogLocations.length}</span>
                        </div>
                        <div className="location-grid">
                          {selectedCatalogLocations.map((location) => (
                            <span key={location} className="location-pill removable-pill">
                              {location}
                              <button
                                type="button"
                                aria-label={`Delete ${location}`}
                                onClick={() => onDeleteCatalogLocation(location)}
                              >
                                <MDBIcon fas icon="xmark" />
                              </button>
                            </span>
                          ))}
                        </div>
                      </div>
                      <div className="surface-subcard">
                        <div className="catalog-preview-title">
                          <strong>Services</strong>
                          <span>{Object.keys(selectedCatalogServices).length}</span>
                        </div>
                        <div className="catalog-service-stack">
                          {Object.entries(selectedCatalogServices).map(([type, names]) => (
                            <article key={type} className="catalog-service-block">
                              <strong>{type}</strong>
                              <div className="people-chip-row">
                                {names.map((name) => (
                                  <span key={`${type}-${name}`} className="person-chip muted removable-pill service-removable-pill">
                                    {name}
                                    <button
                                      type="button"
                                      aria-label={`Delete ${name}`}
                                      onClick={() => onDeleteCatalogService(type, name)}
                                    >
                                      <MDBIcon fas icon="xmark" />
                                    </button>
                                  </span>
                                ))}
                              </div>
                            </article>
                          ))}
                        </div>
                      </div>
                    </div>
                  </section>
                </>
              ) : null}

              {activeSection === "service" ? (
                <>
                  <section className="surface-card">
                    <div className="section-header">
                      <div>
                        <p className="section-label">Service Mapping Matrix</p>
                        {/* <h3>Site-wise service mapping from service_people table</h3> */}
                      </div>
                    </div>
                    {!servicePeopleLoading && !(servicePeopleData.servicePeople || []).length ? (
                      <div className="backend-hint">
                        No service people are available from the `service_people` table right now.
                      </div>
                    ) : null}
                    <div className="service-stage-flow">
                      <div className="site-button-row">
                        {peopleBySite.map((site) => (
                          <button
                            key={site.siteArea}
                            type="button"
                            className={`site-filter-button ${selectedSiteNode?.siteArea === site.siteArea ? "active" : ""}`}
                            onClick={() => setServiceExplorerFromSite(site.siteArea)}
                          >
                            <strong>{site.siteArea}</strong>
                            <span>{site.count} people</span>
                          </button>
                        ))}
                      </div>

                      <div className="surface-subcard">
                        <div className="service-filter-row">
                          <label>
                            <span>Service type</span>
                            <select
                              value={selectedTypeNode?.serviceType || ""}
                              onChange={(e) => {
                                const type = selectedSiteNode?.serviceTypes.find(
                                  (item) => item.serviceType === e.target.value
                                );
                                setServiceExplorer((current) => ({
                                  ...current,
                                  serviceType: e.target.value,
                                  serviceName: type?.services[0]?.serviceName || "",
                                }));
                              }}
                            >
                              {(selectedSiteNode?.serviceTypes || []).map((type) => (
                                <option key={type.serviceType} value={type.serviceType}>
                                  {type.serviceType}
                                </option>
                              ))}
                            </select>
                          </label>
                        </div>

                        <div className="service-list-row">
                          {(selectedTypeNode?.services || []).map((service) => (
                            <button
                              key={`${selectedSiteNode?.siteArea}-${selectedTypeNode?.serviceType}-${service.serviceName}`}
                              type="button"
                              className={`service-pill-button ${selectedServiceNode?.serviceName === service.serviceName ? "active" : ""}`}
                              onClick={() =>
                                setServiceExplorer((current) => ({
                                  ...current,
                                  serviceName: service.serviceName,
                                }))
                              }
                            >
                              <span>{service.serviceName}</span>
                              <strong>{service.count}</strong>
                            </button>
                          ))}
                        </div>

                        <div className="service-person-panel">
                          <div className="section-header">
                            <div>
                              <p className="section-label">Selected service</p>
                              <h3>
                                {selectedSiteNode?.siteArea || "Site"} / {selectedTypeNode?.serviceType || "Service"} /{" "}
                                {selectedServiceNode?.serviceName || "Assignment"}
                              </h3>
                            </div>
                            <span className="tree-count-pill">{selectedServiceNode?.count || 0} people</span>
                          </div>

                          {(selectedServiceNode?.locations || []).length ? (
                            <div className="location-people-stack">
                              {selectedServiceNode.locations.map((location) => (
                                <article key={location.locationName} className="location-people-card">
                                  <div className="location-people-head">
                                    <strong>{location.locationName}</strong>
                                    <span className="tree-count-pill">{location.count}</span>
                                  </div>
                                  <div className="people-chip-row">
                                    {location.members.map((person) => (
                                      <span key={person.id} className="person-chip">
                                        {person.fullName}
                                      </span>
                                    ))}
                                  </div>
                                </article>
                              ))}
                            </div>
                          ) : (
                            <div className="empty-state">No people mapped for this service yet.</div>
                          )}
                        </div>
                      </div>
                    </div>
                  </section>
                  <section className="surface-card">
                    <div className="section-header">
                      <div>
                        
                        <h3>REGISTER AND DELETE SERVICE PEOPLE</h3>
                        <br></br>
                      </div>
                    </div>
                    <section className="surface-subcard auth-provision-panel">
                      <div className="section-header">
                        <div>
                          <p className="section-label">Admin registration</p>
                          <h3>Register admin with super admin OTP</h3>
                        </div>
                      </div>
                      <form className="service-form-grid" onSubmit={onCreateAdmin}>
                        <label><span>Full name</span><input value={adminForm.fullName} onChange={(e) => setAdminForm((current) => ({ ...current, fullName: e.target.value }))} placeholder="Enter full name" required /></label>
                        <label><span>Email</span><input type="email" value={adminForm.email} onChange={(e) => setAdminForm((current) => ({ ...current, email: e.target.value }))} placeholder="admin@company.com" required /></label>
                        <label><span>Password</span><input value={adminForm.password} onChange={(e) => setAdminForm((current) => ({ ...current, password: e.target.value }))} placeholder="Temporary password" required /></label>
                        <label><span>Role</span><select value={adminForm.role} onChange={(e) => setAdminForm((current) => ({ ...current, role: e.target.value }))}><option value="admin_user">Admin</option><option value="super_admin">Super admin</option></select></label>
                        <label><span>Super admin OTP</span><input value={adminForm.superAdminCode} onChange={(e) => setAdminForm((current) => ({ ...current, superAdminCode: e.target.value }))} placeholder="Code sent to super admin" required /></label>
                        <button className="login-secondary-btn" type="button" onClick={onRequestAdminCodes}>Send admin OTP</button>
                        <button className="primary-action" type="submit">Register admin</button>
                      </form>
                    </section>
                    <br></br>
                    <form className="service-form-grid" onSubmit={onCreateServicePerson}>
                      <label><span>Full name</span><input value={serviceForm.fullName} onChange={(e) => setServiceForm((current) => ({ ...current, fullName: e.target.value }))} placeholder="Enter full name" required /></label>
                      <label><span>Email</span><input type="email" value={serviceForm.email} onChange={(e) => setServiceForm((current) => ({ ...current, email: e.target.value }))} placeholder="name@company.com" required /></label>
                      <label><span>Password</span><input value={serviceForm.password} onChange={(e) => setServiceForm((current) => ({ ...current, password: e.target.value }))} placeholder="service123" required /></label>
                      <label><span>Site area</span><select value={serviceForm.siteArea} onChange={(e) => setServiceForm((current) => ({ ...current, siteArea: e.target.value, serviceType: "", serviceName: "", locationName: "" }))}>{catalogSites.map((site) => <option key={site} value={site}>{site}</option>)}</select></label>
                      <label><span>Service type</span><select value={serviceForm.serviceType} onChange={(e) => setServiceForm((current) => ({ ...current, serviceType: e.target.value, serviceName: "" }))} required><option value="">Select type</option>{serviceTypes.map((type) => <option key={type} value={type}>{type}</option>)}</select></label>
                      <label><span>Service name</span><select value={serviceForm.serviceName} onChange={(e) => setServiceForm((current) => ({ ...current, serviceName: e.target.value }))}><option value="">All Services</option>{serviceNames.map((name) => <option key={name} value={name}>{name}</option>)}</select></label>
                      <label><span>Location</span><select value={serviceForm.locationName} onChange={(e) => setServiceForm((current) => ({ ...current, locationName: e.target.value }))}><option value="">All Locations</option>{locations.map((location) => <option key={location} value={location}>{location}</option>)}</select></label>
                      <label className="service-form-checkbox">
                        <input type="checkbox" checked={serviceForm.active} onChange={(e) => setServiceForm((current) => ({ ...current, active: e.target.checked }))} />
                        <span>Active assignment</span>
                      </label>
                      <label><span>Super admin OTP</span><input value={serviceForm.superAdminCode} onChange={(e) => setServiceForm((current) => ({ ...current, superAdminCode: e.target.value }))} placeholder="Code sent to super admin" required /></label>
                      <button className="login-secondary-btn" type="button" onClick={onRequestServiceCodes}>Send service OTP</button>
                      <button className="primary-action" type="submit">Register service person</button>
                    </form>

                    <br></br>
                    <br></br>
                    <div className="delete-service-panel">
                      <label>
                        <span><h2>DELETE SERVICE PERSON</h2></span>
                        <select value={deletePersonId} onChange={(e) => setDeletePersonId(e.target.value)}>
                          <option value="">Select service person</option>
                          {deleteCandidates.map((person) => (
                            <option key={person.id} value={person.id}>
                              {person.fullName} - {person.siteArea} - {person.serviceType}
                              {person.serviceName ? ` - ${person.serviceName}` : ""}
                            </option>
                          ))}
                        </select>
                      </label>

                      {selectedDeletePerson ? (
                        <div className="delete-person-card">
                          <div>
                            <h4>{selectedDeletePerson.fullName}</h4>
                            <p>{selectedDeletePerson.email}</p>
                            <small>
                              {selectedDeletePerson.siteArea} / {selectedDeletePerson.serviceType} /{" "}
                              {selectedDeletePerson.serviceName || "All Services"} /{" "}
                              {selectedDeletePerson.locationName || "All Locations"}
                            </small>
                          </div>
                          <button
                            className="danger-action"
                            type="button"
                            onClick={() => onDeleteServicePerson(selectedDeletePerson.id)}
                          >
                            Delete service person
                          </button>
                        </div>
                      ) : null}
                    </div>
                    <br></br>
                    <br></br>
                  </section>
                </>
              ) : null}

              {shouldShowTicketList ? (
                <section className="surface-card">
                  <div className="section-header">
                    <div>
                      <p className="section-label">Operational details</p>
                      <h3>
                        {activeSection === "escalations"
                          ? "Escalated tickets"
                          : currentSite
                            ? `${currentSite} tickets`
                            : "Latest service tickets"}
                      </h3>
                    </div>
                  </div>
                  <div className="ticket-table">
                    {searchedTickets
                      .slice(0, activeSection === "home" ? 8 : 12)
                      .map((ticket) => (
                        <button
                          key={ticket.id}
                          type="button"
                          className={`ticket-row ${selectedTicket?.id === ticket.id ? "active" : ""}`}
                          onClick={() => toggleTicket(ticket)}
                        >
                          <div>
                            <strong>{ticket.ticketNumber || `Ticket #${ticket.id}`}</strong>
                            <p>{ticket.siteArea} - {ticket.serviceType} - {ticket.locationName}</p>
                          </div>
                          <div className="ticket-row-meta">
                            <span className={`ticket-badge status-${String(ticket.status || "").toLowerCase()}`}>
                              {ticket.status}
                            </span>
                            <small>{formatDate(ticket.updatedAt)}</small>
                          </div>
                        </button>
                      ))}
                  </div>
                </section>
              ) : null}

            </div>

            {showTicketPanel ? (
            <aside className="admin-secondary-column">
              <section className="surface-card sticky-panel">
                  <>
                    <div className="section-header">
                      <div><p className="section-label">Ticket details</p><h3>{selectedTicket.ticketNumber || `Ticket #${selectedTicket.id}`}</h3></div>
                      <div className="ticket-panel-actions">
                        <span className={`ticket-badge status-${String(selectedTicket.status || "").toLowerCase()}`}>{selectedTicket.status}</span>
                        <button type="button" className="ticket-panel-close" onClick={() => setSelectedTicket(null)}>
                          <MDBIcon fas icon="xmark" />
                        </button>
                      </div>
                    </div>
                    <div className="detail-stack">
                      <DetailRow label="Requested by" value={selectedTicket.requestedBy} />
                      <DetailRow label="Site area" value={selectedTicket.siteArea} />
                      <DetailRow label="Service type" value={selectedTicket.serviceType} />
                      <DetailRow label="Service name" value={selectedTicket.serviceName} />
                      <DetailRow label="Location" value={selectedTicket.locationName} />
                      <DetailRow label="Escalation" value={`Level ${selectedTicket.escalationLevel || 0} / Reopen ${selectedTicket.reopenCount || 0}`} />
                      <DetailRow label="Assigned person" value={selectedTicket.assignedPerson ? selectedTicket.assignedPerson.fullName : "Not assigned"} />
                      <DetailRow label="Created" value={formatDate(selectedTicket.createdAt)} />
                      <DetailRow label="Remarks" value={selectedTicket.remarks || "-"} />
                    </div>

                    {selectedTicket.pendingServiceStatus ? (
                      <div className="detail-form-block pending-request-block">
                        <h4>Service assignee update</h4>
                        <DetailRow label="Requested status" value={selectedTicket.pendingServiceStatus} />
                        <DetailRow label="Service remark" value={selectedTicket.pendingServiceRemark || "-"} />
                        <DetailRow label="Submitted" value={formatDate(selectedTicket.pendingServiceUpdatedAt)} />
                      </div>
                    ) : null}

                    <div className="detail-form-block">
                      <h4>Assign service person</h4>
                      <label><span>Available assignees</span><select value={selectedAssigneeId} onChange={(e) => setSelectedAssigneeId(e.target.value)} disabled={assigneesLoading || !assignees.length}><option value="">Select service person</option>{assignees.map((person) => <option key={person.id} value={person.id}>{person.fullName}</option>)}</select></label>
                      <button className="primary-action" type="button" onClick={onAssign} disabled={!selectedAssigneeId}>Assign ticket</button>
                    </div>

                    <div className="detail-form-block">
                      <h4>Update status</h4>
                      <label><span>Next status</span><select value={statusDraft} onChange={(e) => setStatusDraft(e.target.value)} disabled={!allowedStatuses.length}>{allowedStatuses.length ? null : <option value="">No further transition</option>}{allowedStatuses.map((status) => <option key={status} value={status}>{status}</option>)}</select></label>
                      <label><span>Admin remark</span><textarea rows="3" value={statusRemark} onChange={(e) => setStatusRemark(e.target.value)} placeholder="Add a note for hold, cancellation, or resolution." /></label>
                      <button className="primary-action secondary-tone" type="button" onClick={onStatusUpdate} disabled={!allowedStatuses.length || !statusDraft}>Update status</button>
                    </div>

                    <div className="detail-form-block">
                      <h4>Ticket history</h4>
                      {eventsLoading ? <div className="empty-state">Loading timeline...</div> : (
                        <div className="timeline-list">
                          {events.length ? events.map((event) => (
                            <div key={event.id} className="timeline-item">
                              <div className="timeline-dot" />
                              <div>
                                <strong>{titleCase(event.action)}</strong>
                                <p>{titleCase(event.actorRole)} - {formatDate(event.createdAt)}</p>
                                <span>{event.note || `${event.fromStatus || "-"} to ${event.toStatus || "-"}`}</span>
                              </div>
                            </div>
                          )) : <div className="empty-state">No event history yet.</div>}
                        </div>
                      )}
                    </div>
                  </>
              </section>
            </aside>
            ) : null}
          </section>
        )}
      </main>
    </div>
  );
}

function sectionTitle(activeSection) {
  return {
    home: "Service Tickets",
    plant: "Plant Admin",
    guesthouse: "Guesthouse Admin",
    colony: "Colony Admin",
    hostel: "Hostel Admin",
    escalations: "Escalations",
    catalog: "Service Management",
    service: "Service People Management",
  }[activeSection] || "";
}

function StatCard({ label, value, icon, accent }) {
  return <article className={`stat-card ${accent ? "accent" : ""}`}><div><p>{label}</p><strong>{value}</strong></div><MDBIcon fas icon={icon} /></article>;
}

function StatusPill({ label, value, tone }) {
  return <div className={`status-pill ${tone}`}><span>{label}</span><strong>{value}</strong></div>;
}

function MetricRow({ label, value, total }) {
  const percent = Math.round((value / total) * 100);
  return (
    <div className="metric-row">
      <div className="metric-row-top"><span>{label}</span><strong>{value}</strong></div>
      <div className="metric-bar-track"><div className="metric-bar-fill" style={{ width: `${Math.max(8, percent)}%` }} /></div>
    </div>
  );
}

function DetailRow({ label, value }) {
  return <div className="detail-row"><span>{label}</span><strong>{value}</strong></div>;
}
