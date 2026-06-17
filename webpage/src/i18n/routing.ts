import { defineRouting } from "next-intl/routing";

export const routing = defineRouting({
  locales: ["de", "en"],
  defaultLocale: "en",
  // Auto-detect system/browser language, fall back to English.
  localeDetection: true,
});
