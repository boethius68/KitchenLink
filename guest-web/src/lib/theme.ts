export type Theme = "light" | "dark";

export const THEME_STORAGE_KEY = "kitchenlink-theme";

/**
 * Returns the stored theme from localStorage if valid, or null.
 */
export function getStoredTheme(): Theme | null {
  if (typeof window === "undefined" || !window.localStorage) {
    return null;
  }
  try {
    const stored = window.localStorage.getItem(THEME_STORAGE_KEY);
    if (stored === "light" || stored === "dark") {
      return stored;
    }
  } catch {
    // Ignore storage errors in restricted contexts
  }
  return null;
}

/**
 * Returns the system preferred theme via media query.
 */
export function getSystemTheme(): Theme {
  if (typeof window === "undefined" || !window.matchMedia) {
    return "light";
  }
  return window.matchMedia("(prefers-color-scheme: dark)").matches
    ? "dark"
    : "light";
}

/**
 * Resolves the effective theme (stored preference takes precedence over system).
 */
export function getInitialTheme(): Theme {
  return getStoredTheme() ?? getSystemTheme();
}

const listeners = new Set<() => void>();

function notifyThemeListeners(): void {
  for (const listener of listeners) {
    listener();
  }
}

/**
 * Sets the theme attribute on documentElement and saves preference.
 */
export function setTheme(theme: Theme): void {
  if (typeof document !== "undefined") {
    document.documentElement.setAttribute("data-theme", theme);
  }
  if (typeof window !== "undefined" && window.localStorage) {
    try {
      window.localStorage.setItem(THEME_STORAGE_KEY, theme);
    } catch {
      // Ignore storage errors
    }
  }
  notifyThemeListeners();
}

/**
 * Subscribes to theme changes (custom events, storage, and system media query changes).
 */
export function subscribeToTheme(callback: () => void): () => void {
  listeners.add(callback);

  let mediaQuery: MediaQueryList | null = null;
  const handleMediaChange = () => {
    // Only apply if user hasn't chosen an explicit theme in localStorage
    if (!getStoredTheme()) {
      const system = getSystemTheme();
      if (typeof document !== "undefined") {
        document.documentElement.setAttribute("data-theme", system);
      }
      callback();
    }
  };

  if (typeof window !== "undefined") {
    window.addEventListener("storage", callback);
    if (window.matchMedia) {
      mediaQuery = window.matchMedia("(prefers-color-scheme: dark)");
      mediaQuery.addEventListener?.("change", handleMediaChange);
    }
  }

  return () => {
    listeners.delete(callback);
    if (typeof window !== "undefined") {
      window.removeEventListener("storage", callback);
      mediaQuery?.removeEventListener?.("change", handleMediaChange);
    }
  };
}

export function getThemeSnapshot(): Theme {
  return getInitialTheme();
}

export function getThemeServerSnapshot(): Theme {
  return "light";
}

/**
 * Returns the opposite theme for toggling.
 */
export function toggleThemeValue(current: Theme): Theme {
  return current === "dark" ? "light" : "dark";
}
