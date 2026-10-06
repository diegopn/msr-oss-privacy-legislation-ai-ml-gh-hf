(() => {
  "use strict";
  const languageKey = "privacy-site-language";
  const themeKey = "privacy-site-theme";
  let language = document.documentElement.lang === "en-US" ? "en-US" : "pt-BR";
  let preference = document.documentElement.dataset.themePreference || "auto";
  let copy = {};
  const media = window.matchMedia("(prefers-color-scheme: dark)");
  const save = (key, value) => { try { localStorage.setItem(key, value); } catch {} };

  function theme() {
    const value = preference === "auto" ? (media.matches ? "dark" : "light") : preference;
    document.documentElement.dataset.theme = value;
    document.documentElement.dataset.themePreference = preference;
    document.documentElement.style.colorScheme = value;
    const button = document.querySelector(".site-theme-toggle");
    if (button) button.textContent = copy[`theme_${preference}`] || preference;
  }

  async function translate(choice) {
    try {
      const response = await fetch(new URL(`site/locales/${choice}.json`, document.baseURI));
      if (!response.ok) throw new Error("locale unavailable");
      const next = await response.json();
      language = choice;
      copy = next;
      document.documentElement.lang = language;
      document.querySelectorAll("[data-i18n]").forEach(element => {
        if (copy[element.dataset.i18n]) element.textContent = copy[element.dataset.i18n];
      });
      const summary = await fetch(new URL("site/summary.json", document.baseURI));
      if (summary.ok) {
        const state = await summary.json();
        const status = document.querySelector("#collection-status");
        if (status && copy[state.status]) status.textContent = copy[state.status];
        const rq3Status = document.querySelector("#rq3-status");
        if (rq3Status && copy["rq3_" + state.rq3_status]) rq3Status.textContent = copy["rq3_" + state.rq3_status];
      }
      document.querySelectorAll("[data-language]").forEach(button => {
        button.classList.toggle("is-active", button.dataset.language === language);
        button.setAttribute("aria-pressed", String(button.dataset.language === language));
      });
      save(languageKey, language);
      theme();
    } catch (error) {
      console.warn("Could not load site translations.");
    }
  }

  function controls() {
    const container = document.querySelector(".navbar-container") || document.querySelector("#quarto-header .navbar");
    if (!container) return;
    const group = document.createElement("div");
    group.className = "site-controls";
    group.setAttribute("aria-label", "Idioma / Language / Tema");
    for (const [value, label] of [["pt-BR", "PT"], ["en-US", "EN"]]) {
      const button = document.createElement("button");
      button.type = "button";
      button.dataset.language = value;
      button.textContent = label;
      button.setAttribute("aria-label", value === "pt-BR" ? "Português" : "English");
      button.addEventListener("click", () => translate(value));
      group.append(button);
    }
    const toggle = document.createElement("button");
    toggle.type = "button";
    toggle.className = "site-theme-toggle";
    toggle.setAttribute("aria-label", "Alternar tema / Toggle theme");
    toggle.addEventListener("click", () => {
      const modes = ["auto", "light", "dark"];
      preference = modes[(modes.indexOf(preference) + 1) % modes.length];
      save(themeKey, preference);
      theme();
    });
    group.append(toggle);
    container.append(group);
    translate(language);
    theme();
  }
  media.addEventListener("change", theme);
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", controls);
  else controls();
})();
