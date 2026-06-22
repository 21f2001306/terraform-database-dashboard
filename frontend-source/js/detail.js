// Fetch and render details for a single database

let currentInstanceName = null;

document.addEventListener("DOMContentLoaded", () => {
  const params = new URLSearchParams(window.location.search);
  currentInstanceName = params.get("instance");

  if (!currentInstanceName) {
    showError("No instance specified in URL");
    return;
  }

  loadDatabaseDetail(currentInstanceName);
  document
    .getElementById("metadataForm")
    .addEventListener("submit", handleFormSubmit);
});

async function loadDatabaseDetail(instanceName) {
  const loadingEl = document.getElementById("loading");
  const detailContainer = document.getElementById("detailContainer");

  try {
    const response = await apiFetch(
      // <-- changed
      `${API_BASE_URL}/databases/${encodeURIComponent(instanceName)}`,
    );
    if (!response) return; // redirecting due to 401
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }

    const data = await response.json();
    const db = data.database;

    document.getElementById("breadcrumbName").textContent =
      db.databaseName || db.instanceName;
    document.title = `WHATS'ON - ${db.databaseName || db.instanceName}`;

    setText("databaseName", db.databaseName);
    setText("instanceName", db.instanceName);
    setText("status", db.status);
    setText("endpoint", db.endpoint);
    setText("creationDate", db.creationDate);
    setText("sourceSnapshot", db.sourceSnapshot, "(not recorded)");
    setText("sourceInstance", db.sourceInstance, "(not recorded)");
    setText("latestRestorableTime", db.latestRestorableTime);
    setText("databaseVersion", db.databaseVersion);

    document.getElementById("applicationVersion").value =
      db.applicationVersion || "";
    document.getElementById("lastUpgradeDate").value = db.lastUpgradeDate || "";
    document.getElementById("environment").value = db.environment || "";
    document.getElementById("owner").value = db.owner || "";
    document.getElementById("functionality").value = db.functionality || "";

    loadingEl.classList.add("hidden");
    detailContainer.classList.remove("hidden");
  } catch (err) {
    console.error("Error loading database detail:", err);
    showError(`Failed to load database details: ${err.message}`);
  }
}

function setText(id, value, fallback = "") {
  const el = document.getElementById(id);
  if (value) {
    el.textContent = value;
    el.classList.remove("muted");
  } else {
    el.textContent = fallback;
    if (fallback) el.classList.add("muted");
  }
}

async function handleFormSubmit(event) {
  event.preventDefault();

  const applyBtn = document.getElementById("applyBtn");
  const messageEl = document.getElementById("formMessage");

  const payload = {
    applicationVersion: document.getElementById("applicationVersion").value,
    lastUpgradeDate: document.getElementById("lastUpgradeDate").value,
    environment: document.getElementById("environment").value,
    owner: document.getElementById("owner").value,
    functionality: document.getElementById("functionality").value,
  };

  applyBtn.disabled = true;
  applyBtn.textContent = "Saving...";
  messageEl.innerHTML = "";

  try {
    const response = await apiFetch(
      // <-- changed
      `${API_BASE_URL}/databases/${encodeURIComponent(currentInstanceName)}/metadata`,
      {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      },
    );

    if (!response) return; // redirecting due to 401
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }

    await response.json();

    messageEl.innerHTML = `<div class="message success">âœ“ Metadata saved successfully</div>`;
    // Auto-hide after 5 seconds
    setTimeout(() => {
      messageEl.innerHTML = "";
    }, 5000);
  } catch (err) {
    console.error("Error updating metadata:", err);
    messageEl.innerHTML = `<div class="message error">âœ— Failed to save: ${err.message}</div>`;
  } finally {
    applyBtn.disabled = false;
    applyBtn.textContent = "Apply";
  }
}

function showError(message) {
  const loadingEl = document.getElementById("loading");
  const errorEl = document.getElementById("error");
  loadingEl.classList.add("hidden");
  errorEl.textContent = message;
  errorEl.classList.remove("hidden");
}
