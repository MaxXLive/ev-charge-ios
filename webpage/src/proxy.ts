import createMiddleware from "next-intl/middleware";
import { routing } from "./i18n/routing";

// Auto-detects browser/system language, redirects "/" → "/<locale>",
// English fallback for unsupported languages.
export default createMiddleware(routing);

export const config = {
  matcher: ["/((?!_next|api|favicon.ico|.*\\..*).*)"],
};
