import { useTranslations, useLocale } from "next-intl";
import { getTranslations } from "next-intl/server";
import Link from "next/link";
import { ShieldCheck } from "lucide-react";
import { ObfuscatedEmail } from "@/components/marketing/obfuscated-email";
import { siteConfig } from "@/lib/site-config";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "privacy" });
  return {
    title: t("title"),
    description: t("intro"),
    alternates: {
      canonical: `${siteConfig.url}/${locale}/privacy`,
      languages: {
        de: `${siteConfig.url}/de/privacy`,
        en: `${siteConfig.url}/en/privacy`,
        "x-default": `${siteConfig.url}/en/privacy`,
      },
    },
  };
}

const SERVICES = [
  { name: "GoingElectric", url: "https://www.goingelectric.de" },
  { name: "Open Charge Map", url: "https://openchargemap.org" },
  { name: "Nobil", url: "https://nobil.no" },
  { name: "EnBW", url: "https://www.enbw.com" },
  { name: "Chargeprice", url: "https://www.chargeprice.app" },
] as const;

export default function PrivacyPage() {
  const t = useTranslations("privacy");
  const locale = useLocale();

  return (
    <div className="px-4 py-16 sm:px-6">
      <div className="mx-auto max-w-2xl">
        <div className="mb-10 text-center">
          <div className="mb-4 inline-flex h-14 w-14 items-center justify-center rounded-2xl bg-accent/10">
            <ShieldCheck className="h-7 w-7 text-accent" />
          </div>
          <h1 className="text-3xl font-bold sm:text-4xl">{t("title")}</h1>
          <p className="mt-3 text-sm text-muted">{t("lastUpdated")}</p>
        </div>

        <div className="space-y-8 text-foreground/90">
          <p className="text-lg font-medium text-foreground">{t("intro")}</p>

          <section>
            <h2 className="mb-3 text-xl font-bold">{t("dataYouEnterTitle")}</h2>
            <ul className="space-y-3">
              {(["location", "tesla", "filters"] as const).map((key) => (
                <li key={key} className="rounded-xl border border-border bg-surface p-4 text-sm leading-relaxed text-muted">
                  <span className="font-semibold text-foreground">{t(`dataYouEnter.${key}.label`)}: </span>
                  {t(`dataYouEnter.${key}.desc`)}
                </li>
              ))}
            </ul>
          </section>

          <section>
            <h2 className="mb-3 text-xl font-bold">{t("thirdPartyTitle")}</h2>
            <p className="mb-4 text-sm text-muted">{t("thirdPartyIntro")}</p>
            <div className="overflow-hidden rounded-xl border border-border">
              <table className="w-full text-left text-sm">
                <thead className="bg-surface-2 text-muted">
                  <tr>
                    <th className="px-4 py-3 font-medium">{t("thirdPartyService")}</th>
                    <th className="px-4 py-3 font-medium">{t("thirdPartyPurpose")}</th>
                  </tr>
                </thead>
                <tbody>
                  {SERVICES.map((s, i) => (
                    <tr key={s.name} className="border-t border-border">
                      <td className="px-4 py-3">
                        <a href={s.url} target="_blank" rel="noopener noreferrer" className="text-accent hover:underline">
                          {s.name}
                        </a>
                      </td>
                      <td className="px-4 py-3 text-muted">{t(`thirdPartyRows.${i}`)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </section>

          <section>
            <h2 className="mb-3 text-xl font-bold">{t("analyticsTitle")}</h2>
            <p className="text-sm text-muted">{t("analyticsBody")}</p>
          </section>

          <section>
            <h2 className="mb-3 text-xl font-bold">{t("contactTitle")}</h2>
            <p className="text-sm text-muted">
              Max Ermackov ·{" "}
              <Link href={`/${locale}/support`} className="text-accent hover:underline">
                {t("contactSupportCta")}
              </Link>{" "}
              ·{" "}
              <ObfuscatedEmail className="text-accent hover:underline" />
            </p>
          </section>
        </div>
      </div>
    </div>
  );
}
