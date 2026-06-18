import { defineRouting } from "next-intl/routing";

export const routing = defineRouting({
  locales: ["de", "en", "cs", "fr", "it", "nl", "no", "pt", "ro", "sv"],
  defaultLocale: "en",
  // Auto-detect system/browser language, fall back to English.
  localeDetection: true,
});
