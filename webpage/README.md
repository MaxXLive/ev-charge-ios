# EVMap iOS — Marketing Website

Single-page promo site for the EVMap iOS app with App Store download button,
feature overview, privacy policy and support form.

- **Framework:** Next.js 16 (App Router) + next-intl + Tailwind v4
- **Languages:** German + English (auto-detect via browser language, English fallback)
- **URLs:** `evmap-ios.ermackov.de/<locale>` · `/de/privacy` · `/en/support` …
- **Theme:** green accents matching the app logo (`#4caf50`)

## Pages

| Route | Content |
|---|---|
| `/[locale]` | Landing: hero + App Store badge, features, data sources, open-source/Android origin, CTA |
| `/[locale]/privacy` | Privacy policy (from `PRIVACY.md`, localized) |
| `/[locale]/support` | Support/feedback form |

## Support form / feedback API

Reuses the same feedback portal backend as `vehicle-service-history` (PitStop).
`src/app/api/feedback/route.ts` proxies to `FEEDBACK_HOST`, verifies Cloudflare
Turnstile, and forwards to `/api/v1/feedback`. If `NEXT_PUBLIC_TURNSTILE_SITE_KEY`
is unset, the CAPTCHA is skipped (dev convenience).

## Setup

```bash
npm install
cp .env.example .env.local   # fill in feedback + Turnstile keys
npm run dev                  # http://localhost:3000
npm run build && npm run start
```

## TODO before launch

- Set the real numeric App Store ID in `src/lib/site-config.ts` (`appStoreUrl`).
- Configure env vars on Vercel: `FEEDBACK_API_KEY`, `NEXT_PUBLIC_TURNSTILE_SITE_KEY`,
  `TURNSTILE_SECRET_KEY` (and optionally `FEEDBACK_HOST`).
- Point `evmap-ios.ermackov.de` at the Vercel deployment.

## Screenshots

The framed iPhone screenshots come straight from the app's fastlane output.
`npm run gen:screenshots` reads `../evmap/fastlane/screenshots/<locale>/iPhone 17
Pro-*_framed.png`, removes the opaque white padding (flood-fill + auto-crop) and
writes `public/screenshots/<locale>/{map,detail,filter}.png` for **all** locales
fastlane produced (currently 10). Re-run it after every `fastlane screenshots`;
commit the result. Requires Pillow (`pip3 install Pillow`).

## Adding languages (i18n)

1. Add the locale to `src/i18n/routing.ts` (`locales`).
2. Create `src/messages/<locale>.json` (copy `en.json` as template).
3. Screenshots for that locale already exist (see above) — no extra work.
4. The navbar language switcher and metadata `alternates` pick it up automatically.

The app ships in 11 languages; the website starts with `de` + `en` and the
screenshot pipeline is ready for the rest.
