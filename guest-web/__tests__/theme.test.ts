import { beforeEach, describe, expect, it, vi } from "vitest";
import {
  THEME_STORAGE_KEY,
  getInitialTheme,
  getStoredTheme,
  getSystemTheme,
  setTheme,
  toggleThemeValue,
} from "@/lib/theme";

describe("theme utility", () => {
  let mockStorage: Record<string, string> = {};
  let rootAttributes: Record<string, string> = {};

  beforeEach(() => {
    mockStorage = {};
    rootAttributes = {};

    const localStorageMock: Storage = {
      getItem: (key: string) => mockStorage[key] ?? null,
      setItem: (key: string, value: string) => {
        mockStorage[key] = value;
      },
      removeItem: (key: string) => {
        delete mockStorage[key];
      },
      clear: () => {
        mockStorage = {};
      },
      get length() {
        return Object.keys(mockStorage).length;
      },
      key: (index: number) => Object.keys(mockStorage)[index] ?? null,
    };

    const documentMock = {
      documentElement: {
        setAttribute: (key: string, value: string) => {
          rootAttributes[key] = value;
        },
        getAttribute: (key: string) => rootAttributes[key] ?? null,
        removeAttribute: (key: string) => {
          delete rootAttributes[key];
        },
      },
    };

    // Cast via unknown to mock window in node environment
    (globalThis as unknown as { window: unknown }).window = {
      localStorage: localStorageMock,
      matchMedia: vi.fn().mockReturnValue({ matches: false }),
    };
    (globalThis as unknown as { document: unknown }).document = documentMock;
  });

  describe("toggleThemeValue", () => {
    it("toggles dark to light and vice versa", () => {
      expect(toggleThemeValue("dark")).toBe("light");
      expect(toggleThemeValue("light")).toBe("dark");
    });
  });

  describe("getStoredTheme", () => {
    it("returns null when no preference is saved", () => {
      expect(getStoredTheme()).toBeNull();
    });

    it("returns stored valid theme", () => {
      window.localStorage.setItem(THEME_STORAGE_KEY, "dark");
      expect(getStoredTheme()).toBe("dark");

      window.localStorage.setItem(THEME_STORAGE_KEY, "light");
      expect(getStoredTheme()).toBe("light");
    });

    it("returns null for invalid stored values", () => {
      window.localStorage.setItem(THEME_STORAGE_KEY, "invalid-theme");
      expect(getStoredTheme()).toBeNull();
    });
  });

  describe("getSystemTheme", () => {
    it("defaults to light when prefers-color-scheme does not match dark", () => {
      vi.spyOn(window, "matchMedia").mockReturnValue({
        matches: false,
      } as unknown as MediaQueryList);
      expect(getSystemTheme()).toBe("light");
    });

    it("returns dark when prefers-color-scheme matches dark", () => {
      vi.spyOn(window, "matchMedia").mockReturnValue({
        matches: true,
      } as unknown as MediaQueryList);
      expect(getSystemTheme()).toBe("dark");
    });
  });

  describe("getInitialTheme", () => {
    it("uses stored theme if present", () => {
      window.localStorage.setItem(THEME_STORAGE_KEY, "dark");
      vi.spyOn(window, "matchMedia").mockReturnValue({
        matches: false,
      } as unknown as MediaQueryList);
      expect(getInitialTheme()).toBe("dark");
    });

    it("falls back to system preference if no stored theme", () => {
      vi.spyOn(window, "matchMedia").mockReturnValue({
        matches: true,
      } as unknown as MediaQueryList);
      expect(getInitialTheme()).toBe("dark");
    });
  });

  describe("setTheme", () => {
    it("sets data-theme attribute on documentElement and saves to localStorage", () => {
      setTheme("dark");
      expect(document.documentElement.getAttribute("data-theme")).toBe("dark");
      expect(window.localStorage.getItem(THEME_STORAGE_KEY)).toBe("dark");

      setTheme("light");
      expect(document.documentElement.getAttribute("data-theme")).toBe("light");
      expect(window.localStorage.getItem(THEME_STORAGE_KEY)).toBe("light");
    });
  });
});
