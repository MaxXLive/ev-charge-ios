import { useTranslations, useLocale, useFormatter } from "next-intl";
import { getTranslations } from "next-intl/server";
import Image from "next/image";
import {
  Activity,
  SlidersHorizontal,
  Heart,
  ShieldCheck,
  Search,
  ArrowUpRight,
  Check,
} from "lucide-react";
import { AppStoreBadge } from "@/components/marketing/app-store-badge";
import { GithubButton } from "@/components/marketing/github-button";
import { PhoneShot } from "@/components/marketing/phone-shot";
import { CarPlayIcon } from "@/components/marketing/carplay-icon";
import { siteConfig } from "@/lib/site-config";

const SOURCE_LINKS = {
  ge: { url: "https://www.goingelectric.de", domain: "goingelectric.de" },
  ocm: { url: "https://openchargemap.org", domain: "openchargemap.org" },
  nobil: { url: "https://nobil.no", domain: "nobil.no" },
} as const;

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "meta" });
  return {
    title: t("homeTitle"),
    description: t("homeDescription"),
    alternates: {
      canonical: `${siteConfig.url}/${locale}`,
      languages: {
        de: `${siteConfig.url}/de`,
        en: `${siteConfig.url}/en`,
        "x-default": `${siteConfig.url}/en`,
      },
    },
  };
}

export default function HomePage() {
  const t = useTranslations("home");
  const locale = useLocale();
  const format = useFormatter();
  const shot = (name: string) => `/screenshots/${locale}/${name}.png`;

  const features = [
    { key: "availability", icon: Activity },
    { key: "carplay", icon: CarPlayIcon },
    { key: "search", icon: Search },
    { key: "filters", icon: SlidersHorizontal },
    { key: "favorites", icon: Heart },
    { key: "privacy", icon: ShieldCheck },
  ] as const;

  const stats = ["sources", "languages", "price", "trackers"] as const;
  const priceValue = format.number(0, {
    style: "currency",
    currency: t("stats.price.currency"),
    maximumFractionDigits: 0,
  });
  const highlightRows = ["availability", "filters", "free"] as const;

  return (
    <div>
      {/* ----------------------------------------------------------------- Hero */}
      <section className="mx-auto grid max-w-6xl items-center gap-12 px-5 pb-16 pt-12 sm:px-6 lg:grid-cols-[1.05fr_0.95fr] lg:gap-10 lg:pb-24 lg:pt-20">
        <div className="max-w-xl">
          <p className="eyebrow">{t("heroEyebrow")}</p>
          <h1 className="mt-4 text-4xl font-bold leading-[1.08] tracking-tight sm:text-5xl lg:text-6xl">
            {t("heroTitle")}
          </h1>
          <p className="mt-5 max-w-md text-lg leading-relaxed text-muted">
            {t("heroSubtitle")}
          </p>

          <div className="mt-8 flex flex-wrap items-center gap-3">
            <AppStoreBadge />
            <GithubButton />
          </div>
          <p className="mt-4 text-sm text-muted">{t("heroNote")}</p>
        </div>

        <div className="relative mx-auto w-full max-w-[280px] lg:max-w-[300px]">
          <PhoneShot src={shot("map")} alt={t("shotMapAlt")} priority />
        </div>
      </section>

      {/* ------------------------------------------------------------ Stats band */}
      <section className="border-y border-border bg-surface">
        <div className="mx-auto grid max-w-5xl grid-cols-2 px-5 py-9 sm:grid-cols-4 sm:px-6">
          {stats.map((s) => (
            <div key={s} className="px-2 text-center">
              <div className="text-3xl font-bold tracking-tight sm:text-4xl">
                {s === "price" ? priceValue : t(`stats.${s}.value`)}
              </div>
              <div className="mt-1 text-sm text-muted">{t(`stats.${s}.label`)}</div>
            </div>
          ))}
        </div>
      </section>

      {/* ------------------------------------------------------ Highlight split */}
      <section className="mx-auto grid max-w-6xl items-center gap-12 px-5 py-20 sm:px-6 lg:grid-cols-2 lg:gap-16 lg:py-28">
        <div className="order-2 mx-auto w-full max-w-[260px] lg:order-1 lg:mx-0">
          <PhoneShot src={shot("detail")} alt={t("shotDetailAlt")} />
        </div>
        <div className="order-1 max-w-lg lg:order-2">
          <p className="eyebrow">{t("highlightEyebrow")}</p>
          <h2 className="mt-4 text-3xl font-bold tracking-tight sm:text-4xl">{t("highlightTitle")}</h2>
          <p className="mt-4 text-lg leading-relaxed text-muted">{t("highlightBody")}</p>

          <ul className="mt-8 space-y-5">
            {highlightRows.map((key) => (
              <li key={key} className="flex gap-3.5">
                <span className="mt-0.5 flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-accent-soft">
                  <Check className="h-3.5 w-3.5 text-accent-deep" strokeWidth={3} />
                </span>
                <div>
                  <p className="font-semibold">{t(`features.${key}.title`)}</p>
                  <p className="mt-0.5 text-sm leading-relaxed text-muted">{t(`features.${key}.desc`)}</p>
                </div>
              </li>
            ))}
          </ul>
        </div>
      </section>

      {/* --------------------------------------------------------------- Features */}
      <section id="features" className="border-t border-border bg-surface py-20 sm:py-28">
        <div className="mx-auto max-w-6xl px-5 sm:px-6">
          <div className="max-w-2xl">
            <p className="eyebrow">{t("featuresEyebrow")}</p>
            <h2 className="mt-4 text-3xl font-bold tracking-tight sm:text-4xl">{t("featuresTitle")}</h2>
            <p className="mt-4 text-lg text-muted">{t("featuresSubtitle")}</p>
          </div>

          <div className="mt-12 grid gap-px overflow-hidden rounded-2xl border border-border bg-border sm:grid-cols-2 lg:grid-cols-3">
            {features.map(({ key, icon: Icon }) => (
              <div key={key} className="bg-background p-7">
                <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-accent-soft">
                  <Icon className="h-5 w-5 text-accent-deep" />
                </div>
                <h3 className="mt-4 text-lg font-semibold">{t(`features.${key}.title`)}</h3>
                <p className="mt-1.5 text-sm leading-relaxed text-muted">{t(`features.${key}.desc`)}</p>
              </div>
            ))}
          </div>
          <p className="mt-6 max-w-2xl text-sm text-muted">{t("featuresMore")}</p>
        </div>
      </section>

      {/* ------------------------------------------------------------ Screenshots */}
      <section id="screenshots" className="py-20 sm:py-28">
        <div className="mx-auto max-w-6xl px-5 sm:px-6">
          <div className="max-w-2xl">
            <p className="eyebrow">{t("screensEyebrow")}</p>
            <h2 className="mt-4 text-3xl font-bold tracking-tight sm:text-4xl">{t("screensTitle")}</h2>
            <p className="mt-4 text-lg text-muted">{t("screensSubtitle")}</p>
          </div>

          <div className="mt-14 grid grid-cols-2 gap-6 sm:gap-10 lg:grid-cols-3">
            {(["map", "detail", "filter"] as const).map((name, i) => (
              <div key={name} className={`mx-auto w-full max-w-[240px] ${i === 2 ? "col-span-2 lg:col-span-1" : ""}`}>
                <PhoneShot src={shot(name)} alt={t(`shot${name[0].toUpperCase()}${name.slice(1)}Alt`)} />
                <p className="mt-4 text-center text-sm font-medium text-muted">{t(`screens.${name}`)}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ----------------------------------------------------------- Data sources */}
      <section id="sources" className="border-t border-border bg-surface py-20 sm:py-28">
        <div className="mx-auto max-w-6xl px-5 sm:px-6">
          <div className="max-w-2xl">
            <p className="eyebrow">{t("sourcesEyebrow")}</p>
            <h2 className="mt-4 text-3xl font-bold tracking-tight sm:text-4xl">{t("sourcesTitle")}</h2>
            <p className="mt-4 text-lg text-muted">{t("sourcesSubtitle")}</p>
          </div>

          <div className="mt-12 grid gap-5 sm:grid-cols-3">
            {(["ge", "ocm", "nobil"] as const).map((key) => (
              <a
                key={key}
                href={SOURCE_LINKS[key].url}
                target="_blank"
                rel="noopener noreferrer"
                className="group flex flex-col rounded-2xl border border-border bg-background p-7 transition-all hover:-translate-y-0.5 hover:border-accent/40 hover:shadow-md"
              >
                <div className="flex items-start justify-between">
                  <h3 className="text-lg font-semibold">{t(`sources.${key}.name`)}</h3>
                  <ArrowUpRight className="h-5 w-5 text-muted transition-colors group-hover:text-accent" />
                </div>
                <p className="mt-1 text-sm text-muted">{t(`sources.${key}.region`)}</p>
                <span className="mt-4 text-sm font-medium text-accent">{SOURCE_LINKS[key].domain}</span>
              </a>
            ))}
          </div>
          <p className="mt-6 max-w-2xl text-sm text-muted">{t("sourcesNote")}</p>
        </div>
      </section>

      {/* --------------------------------------------------- Open source / Android */}
      <section className="py-20 sm:py-28">
        <div className="mx-auto max-w-5xl px-5 sm:px-6">
          <div className="rounded-3xl border border-border p-8 sm:p-12">
            <div className="grid items-center gap-10 lg:grid-cols-[1.4fr_1fr]">
              <div>
                <p className="eyebrow">{t("openSourceBadge")}</p>
                <h2 className="mt-4 text-2xl font-bold tracking-tight sm:text-3xl">{t("openSourceTitle")}</h2>
                <p className="mt-4 max-w-xl leading-relaxed text-muted">{t("openSourceBody")}</p>

                <div className="mt-7 flex flex-wrap gap-3">
                  <a
                    href={siteConfig.androidUrl}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="inline-flex h-[52px] items-center gap-2 rounded-[9px] bg-accent px-5 text-[15px] font-semibold text-white transition-transform hover:scale-[1.03]"
                  >
                    {t("openSourceAndroidCta")}
                    <ArrowUpRight className="h-5 w-5" />
                  </a>
                  <GithubButton href={siteConfig.androidGithubUrl} />
                </div>
              </div>

              <figure className="mx-auto w-full max-w-[250px]">
                <div className="phone-shadow relative w-full" style={{ aspectRatio: "1198 / 2409" }}>
                  {/* Nexus 5X device frame (opaque black display, transparent outside) */}
                  <Image
                    src="/android/frame-nexus-5x.png"
                    alt=""
                    aria-hidden
                    fill
                    sizes="(max-width: 768px) 60vw, 250px"
                    className="pointer-events-none object-contain"
                  />
                  {/* Screenshot sits on top, inside the display window */}
                  <div
                    className="absolute overflow-hidden"
                    style={{ top: "9.67%", left: "4.59%", width: "90.15%", height: "79.7%" }}
                  >
                    <Image
                      src={`/android/map-${locale === "de" ? "de" : "en"}.png`}
                      alt={t("androidShotAlt")}
                      fill
                      sizes="(max-width: 768px) 60vw, 250px"
                      className="object-cover"
                    />
                  </div>
                </div>
                <figcaption className="mt-3 text-center text-sm text-muted">{t("androidShotCaption")}</figcaption>
              </figure>
            </div>
          </div>
        </div>
      </section>

      {/* ---------------------------------------------------------------- Final CTA */}
      <section className="px-5 pb-24 sm:px-6">
        <div className="mx-auto max-w-5xl rounded-3xl bg-ink px-6 py-16 text-center sm:py-20">
          <h2 className="text-3xl font-bold tracking-tight text-white sm:text-4xl">{t("ctaTitle")}</h2>
          <p className="mx-auto mt-4 max-w-md text-white/70">{t("ctaSubtitle")}</p>
          <div className="mt-9 flex justify-center">
            <AppStoreBadge />
          </div>
        </div>
      </section>
    </div>
  );
}
