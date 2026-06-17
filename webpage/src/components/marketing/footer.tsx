import { useTranslations, useLocale } from "next-intl";
import Link from "next/link";
import Image from "next/image";
import { siteConfig } from "@/lib/site-config";

export function MarketingFooter() {
  const t = useTranslations();
  const locale = useLocale();
  const year = new Date().getFullYear();
  const l = (path: string) => `/${locale}${path}`;

  return (
    <footer className="bg-ink">
      <div className="mx-auto max-w-6xl px-5 py-14 sm:px-6">
        <div className="flex flex-col gap-10 sm:flex-row sm:justify-between">
          <div className="max-w-xs">
            <div className="flex items-center gap-2.5">
              <Image src="/icon.png" alt="EVMap for iOS" width={34} height={34} className="rounded-[10px]" />
              <span className="text-lg font-bold text-white">EVMap <span className="font-semibold text-white/55">for iOS</span></span>
            </div>
            <p className="mt-3 text-sm leading-relaxed text-white/60">{t("footer.tagline")}</p>
          </div>

          <div className="grid grid-cols-2 gap-x-12 gap-y-3 text-sm sm:grid-cols-2">
            <div className="flex flex-col gap-3">
              <p className="text-xs font-semibold uppercase tracking-wider text-white/40">{t("footer.appCol")}</p>
              <Link href={l("/privacy")} className="text-white/70 transition-colors hover:text-white">
                {t("nav.privacy")}
              </Link>
              <Link href={l("/support")} className="text-white/70 transition-colors hover:text-white">
                {t("nav.support")}
              </Link>
            </div>
            <div className="flex flex-col gap-3">
              <p className="text-xs font-semibold uppercase tracking-wider text-white/40">{t("footer.projectCol")}</p>
              <a href={siteConfig.androidUrl} target="_blank" rel="noopener noreferrer" className="text-white/70 transition-colors hover:text-white">
                {t("footer.android")}
              </a>
              <a href={siteConfig.githubUrl} target="_blank" rel="noopener noreferrer" className="text-white/70 transition-colors hover:text-white">
                GitHub
              </a>
            </div>
          </div>
        </div>

        <div className="mt-12 flex flex-col gap-2 border-t border-white/10 pt-6 text-xs text-white/45 sm:flex-row sm:items-center sm:justify-between">
          <p>{t("footer.copyright", { year })}</p>
          <p>{t("footer.attribution")}</p>
        </div>
      </div>
    </footer>
  );
}
