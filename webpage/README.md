# EV Charge for iOS — Marketing Website

Single-page promo site for the EV Charge iOS app: App Store download, feature
overview, screenshots, data sources, the open-source Android origin, plus a
privacy policy and a support form.

- **Framework:** Next.js 16 (App Router) + next-intl + Tailwind v4
- **Languages:** German, English, Czech, French, Italian, Dutch, Norwegian, Portuguese, Romanian, Swedish (browser auto-detect, English fallback)
- **URLs:** `ev-charge.ermackov.de/<locale>` · `/de/privacy` · `/en/support`
- **Theme:** light, restrained, green accents from the app logo (`#15a34a` / `#00e676`)

## Pages

| Route | Content |
|---|---|
| `/[locale]` | Landing: hero + App Store badge, stats, feature highlight, feature grid, screenshots, data sources, Android origin, CTA |
| `/[locale]/privacy` | Privacy policy (localized, mirrors the app's `PRIVACY.md`) |
| `/[locale]/support` | Support / feedback form |

## Setup

```bash
npm install
cp .env.example .env.local   # fill in feedback + Turnstile keys
npm run dev                  # http://localhost:3000 (port 3000 is often taken → PORT=3210 npm run dev)
npm run build && npm run start
```

Env vars (`.env.local`, gitignored):

| Var | Purpose |
|---|---|
| `FEEDBACK_API_KEY` | Auth for the shared feedback portal |
| `FEEDBACK_HOST` | Portal base URL (defaults to `feedback-portal-mx.vercel.app`) |
| `NEXT_PUBLIC_TURNSTILE_SITE_KEY` | Cloudflare Turnstile site key (CAPTCHA) |
| `TURNSTILE_SECRET_KEY` | Turnstile secret (server-side verify) |

If the Turnstile keys are unset, the CAPTCHA is skipped (dev convenience).
Use Cloudflare test keys locally (`1x00000000000000000000AA`).

## Support form / feedback API

`src/app/api/feedback/route.ts` proxies to `FEEDBACK_HOST` (same backend as the
PitStop project), verifies Turnstile, and forwards to `/api/v1/feedback`. The key
never reaches the client.

## Screenshots

Framed iPhone screenshots come from the app's fastlane output. The Android shot
sits inside a real Nexus 5X frame (`public/android/frame-nexus-5x.png`).

```bash
npm run gen:screenshots   # needs Pillow: pip3 install Pillow
```

Reads `../evcharge/fastlane/screenshots/<locale>/iPhone 17 Pro-*_framed.png`, removes
the opaque white padding (flood-fill from corners + auto-crop), and writes
`public/screenshots/<locale>/{map,detail,filter}.png` for **all** locales fastlane
produced (currently 10). Re-run after every `fastlane screenshots`; commit the
result. The generated PNGs are committed so Vercel needs no access to `../evcharge`.

## Adding languages (i18n)

The app ships in 11 languages; 10 are live on the website (all except Estonian).

1. Add the locale code to `src/i18n/routing.ts` (`locales` array).
2. Add the native language name to `LOCALE_LABELS` in `src/components/marketing/navbar.tsx`.
3. Create `src/messages/<locale>.json` (copy `en.json`). Set `stats.price.currency`
   to that market's currency (e.g. `EUR`, `USD`, `GBP`).
4. Screenshots already exist for that locale if fastlane produced them — run
   `npm run gen:screenshots` to regenerate if needed.
5. App Store badge: copy the official SVG to `public/badges/app-store-<locale>.svg`
   (from `~/Downloads/Download-on-the-App-Store/<LOCALE_DIR>/…/Black_lockup/SVG/`)
   and add the mapping in `src/components/marketing/app-store-badge.tsx` (falls back to `en`).
6. The navbar dropdown and metadata `alternates` pick everything up automatically.

## Deploy (Vercel)

- **Root Directory = `webpage`** (the app is a subfolder of the iOS repo).
- Set the env vars above in Project → Settings → Environment Variables.
- Add domain `ev-charge.ermackov.de`.
- Enable Web Analytics in the Analytics tab (`@vercel/analytics` is already wired
  in `src/app/layout.tsx`).
