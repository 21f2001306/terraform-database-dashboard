// Fetch and render the list of databases on the main page

document.addEventListener("DOMContentLoaded", () => {
  loadDatabases();
  document
    .getElementById("refreshBtn")
    .addEventListener("click", loadDatabases);
});

async function loadDatabases() {
  const loadingEl = document.getElementById("loading");
  const errorEl = document.getElementById("error");
  const tableContainer = document.getElementById("tableContainer");
  const tbody = document.getElementById("databasesTableBody");

  // Reset UI
  loadingEl.classList.remove("hidden");
  errorEl.classList.add("hidden");
  tableContainer.classList.add("hidden");

  try {
    const response = await apiFetch(`${API_BASE_URL}/databases`); // <-- changed
    if (!response) return; // redirecting due to 401
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }

    const data = await response.json();
    const databases = data.databases || [];

    tbody.innerHTML = "";

    if (databases.length === 0) {
      tbody.innerHTML =
        '<tr><td colspan="11" style="text-align:center; padding:20px;">No databases found</td></tr>';
    } else {
      databases.forEach((db) => {
        const row = document.createElement("tr");
        row.innerHTML = `
                    <td><a href="detail.html?instance=${encodeURIComponent(db.instanceName)}">${escapeHtml(db.databaseName) || "(no name)"}</a></td>
                    <td>${escapeHtml(db.instanceName)}</td>
                    <td>${renderStatusBadge(db.status)}</td>
                    <td>${escapeHtml(db.environment)}</td>
                    <td>${escapeHtml(db.creationDate)}</td>
                    <td>${escapeHtml(db.sourceInstance)}</td>
                    <td>${escapeHtml(db.owner)}</td>
                    <td>${escapeHtml(db.functionality)}</td>
                    <td>${escapeHtml(db.appVersion)}</td>
                    <td>${escapeHtml(db.lastUpgrade)}</td>
                    <td>${escapeHtml(db.oracleVersion)}</td>
                `;
        tbody.appendChild(row);
      });
    }

    loadingEl.classList.add("hidden");
    tableContainer.classList.remove("hidden");
  } catch (err) {
    console.error("Error loading databases:", err);
    loadingEl.classList.add("hidden");
    errorEl.textContent = `Failed to load databases: ${err.message}`;
    errorEl.classList.remove("hidden");
  }
}

function renderStatusBadge(status) {
  if (!status) return "";
  const statusClass =
    status === "available"
      ? "status-badge"
      : status === "stopped"
        ? "status-badge status-stopped"
        : "status-badge status-pending";
  return `<span class="${statusClass}">${escapeHtml(status)}</span>`;
}

function escapeHtml(str) {
  if (str === null || str === undefined) return "";
  return String(str)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}
