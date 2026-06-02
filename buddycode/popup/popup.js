// ── BuddyCode — Popup Controller ──────────────────────────────────
document.addEventListener("DOMContentLoaded", () => {
  const toggles = {
    enabled:    document.getElementById("toggle-enabled"),
    complexity: document.getElementById("toggle-complexity"),
    companies:  document.getElementById("toggle-companies"),
    elo:        document.getElementById("toggle-elo"),
    freq:       document.getElementById("toggle-freq"),
    submission: document.getElementById("toggle-submission"),
  };

  const defaults = {
    enabled: true,
    showComplexity: true,
    showCompanies: true,
    showElo: true,
    showFreq: true,
    showSubmission: true,
  };

  function loadConfig(cb) {
    chrome.storage.local.get(["buddycode_config"], (result) => {
      const config = result.buddycode_config || {};
      cb(Object.assign({}, defaults, config));
    });
  }

  function saveConfig(config) {
    chrome.storage.local.set({ buddycode_config: config });
  }

  function applyUI(config) {
    toggles.enabled.checked = config.enabled;
    toggles.complexity.checked = config.showComplexity;
    toggles.companies.checked = config.showCompanies;
    toggles.elo.checked = config.showElo;
    toggles.freq.checked = config.showFreq;
    toggles.submission.checked = config.showSubmission;
  }

  loadConfig((config) => {
    applyUI(config);

    toggles.enabled.addEventListener("change", () => {
      config.enabled = toggles.enabled.checked;
      saveConfig(config);
    });

    toggles.complexity.addEventListener("change", () => {
      config.showComplexity = toggles.complexity.checked;
      saveConfig(config);
    });

    toggles.companies.addEventListener("change", () => {
      config.showCompanies = toggles.companies.checked;
      saveConfig(config);
    });

    toggles.elo.addEventListener("change", () => {
      config.showElo = toggles.elo.checked;
      saveConfig(config);
    });

    toggles.freq.addEventListener("change", () => {
      config.showFreq = toggles.freq.checked;
      saveConfig(config);
    });

    toggles.submission.addEventListener("change", () => {
      config.showSubmission = toggles.submission.checked;
      saveConfig(config);
    });
  });
});
