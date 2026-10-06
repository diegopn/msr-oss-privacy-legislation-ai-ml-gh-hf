(() => {
  "use strict";

  const languageKey = "privacy-site-language";
  const themeKey = "privacy-site-theme";
  const languages = ["pt-BR", "en-US"];
  const themes = ["auto", "light", "dark"];
  const navigationLabels = {
    "#visao-geral": "nav_project",
    "#metodologia": "nav_method",
    "#dados": "nav_sample",
    "#rq3": "nav_rq3",
    "#reproducao": "nav_execution",
    "#limites": "nav_limits",
    "#referencias-metodologicas": "nav_references"
  };
  let language = document.documentElement.lang === "en-US" ? "en-US" : "pt-BR";
  let preference = document.documentElement.dataset.themePreference || "auto";
  if (!themes.includes(preference)) preference = "auto";
  let copy = {};
  const media = window.matchMedia ? window.matchMedia("(prefers-color-scheme: dark)") : null;
  const save = (key, value) => { try { localStorage.setItem(key, value); } catch {} };

  function theme() {
    const value = preference === "auto" && media?.matches ? "dark" :
      preference === "auto" ? "light" : preference;
    document.documentElement.dataset.theme = value;
    document.documentElement.dataset.themePreference = preference;
    document.documentElement.style.colorScheme = value;

    const button = document.querySelector("[data-theme-toggle]");
    if (!button) return;
    button.textContent = value === "dark" ? "☾" : "☀";
    const themeName = copy[`theme_${preference}`] || preference;
    const label = (copy.theme_button || "Theme: {theme}").replace("{theme}", themeName);
    button.setAttribute("aria-label", label);
    button.setAttribute("title", label);
    button.dataset.themePreference = preference;
  }

  async function translate(choice) {
    const nextLanguage = languages.includes(choice) ? choice : "pt-BR";
    try {
      const response = await fetch(new URL(`site/locales/${nextLanguage}.json`, document.baseURI));
      if (!response.ok) throw new Error("locale unavailable");
      copy = await response.json();
      language = nextLanguage;
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
        const rq3Key = `rq3_${state.rq3_status}`;
        if (rq3Status && copy[rq3Key]) rq3Status.textContent = copy[rq3Key];
      }

      document.querySelectorAll("#quarto-header .navbar-nav .nav-link").forEach(link => {
        const href = link.getAttribute("href") || "";
        const hash = new URL(href, document.baseURI).hash;
        const key = navigationLabels[hash];
        if (key && copy[key]) link.textContent = copy[key];
      });

      document.querySelectorAll("[data-language]").forEach(button => {
        const selected = button.dataset.language === language;
        button.classList.toggle("is-active", selected);
        button.setAttribute("aria-pressed", String(selected));
        button.setAttribute("aria-label", (copy.language_button || "Change language to {language}")
          .replace("{language}", copy[button.dataset.language === "pt-BR" ? "language_pt" : "language_en"] || button.dataset.language));
      });

      const controls = document.querySelector(".site-controls");
      if (controls) controls.setAttribute("aria-label", copy.control_group || "Language and theme");
      save(languageKey, language);
      theme();
    } catch (error) {
      console.warn("Could not load site translations.");
    }
  }

  function controls() {
    if (document.querySelector(".site-controls")) return;
    const host = document.querySelector("#quarto-header .quarto-navbar-tools") ||
      document.querySelector("#quarto-header .navbar-collapse");
    if (!host) return;

    const group = document.createElement("div");
    group.className = "site-controls";
    group.setAttribute("role", "group");
    group.setAttribute("aria-label", "Language and theme");
    group.innerHTML = `
      <button type="button" data-language="pt-BR">PT</button>
      <button type="button" data-language="en-US">EN</button>
      <button type="button" class="site-theme-toggle" data-theme-toggle>☀</button>`;

    group.querySelectorAll("[data-language]").forEach(button => {
      button.addEventListener("click", () => { void translate(button.dataset.language); });
    });
    group.querySelector("[data-theme-toggle]").addEventListener("click", () => {
      preference = themes[(themes.indexOf(preference) + 1) % themes.length];
      save(themeKey, preference);
      theme();
    });
    host.append(group);
    void translate(language);
    theme();
  }

  media?.addEventListener?.("change", () => {
    if (preference === "auto") theme();
  });
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", controls);
  else controls();
})();
