"use client";

import { useState, useEffect, useRef } from "react";
import { useTranslations, useLocale } from "next-intl";
import Link from "next/link";
import Image from "next/image";
import { usePathname } from "next/navigation";
import { Menu, X, Globe, ChevronDown } from "lucide-react";
import { siteConfig } from "@/lib/site-config";
import { routing } from "@/i18n/routing";

const SECTION_IDS = ["features", "screenshots", "sources"] as const;

const LOCALE_LABELS: Record<string, string> = {
  de: "Deutsch",
  en: "English",
  cs: "Čeština",
  fr: "Français",
  it: "Italiano",
  nl: "Nederlands",
  es: "Español",
  no: "Norsk",
  pt: "Português",
  ro: "Română",
  sv: "Svenska",
};

export function MarketingNavbar() {
  const t = useTranslations("nav");
  const locale = useLocale();
  const [open, setOpen] = useState(false);
  const [langOpen, setLangOpen] = useState(false);
  const [active, setActive] = useState<string>("");
  const langRef = useRef<HTMLDivElement>(null);

  const pathname = usePathname();
  const l = (path: string) => `/${locale}${path}`;
  const pathWithoutLocale = pathname.replace(/^\/(de|en|cs|fr|it|nl|no|pt|ro|sv)/, "") || "/";

  const isHome = pathname === `/${locale}` || pathname === `/${locale}/`;
  const onPrivacy = pathname.startsWith(`/${locale}/privacy`);
  const onSupport = pathname.startsWith(`/${locale}/support`);

  // Close lang dropdown on outside click
  useEffect(() => {
    function handler(e: MouseEvent) {
      if (langRef.current && !langRef.current.contains(e.target as Node)) {
        setLangOpen(false);
      }
    }
    document.addEventListener("mousedown", handler);
    return () => document.removeEventListener("mousedown", handler);
  }, []);

  // Scroll-spy
  useEffect(() => {
    if (!isHome) { setActive(""); return; }
    const observer = new IntersectionObserver(
      (entries) => { entries.forEach((e) => { if (e.isIntersecting) setActive(e.target.id); }); },
      { rootMargin: "-45% 0px -50% 0px", threshold: 0 }
    );
    SECTION_IDS.forEach((id) => { const el = document.getElementById(id); if (el) observer.observe(el); });
    const onScroll = () => { if (window.scrollY < 120) setActive(""); };
    window.addEventListener("scroll", onScroll, { passive: true });
    onScroll();
    return () => { observer.disconnect(); window.removeEventListener("scroll", onScroll); };
  }, [isHome, pathname]);

  const sectionItems = [
    { id: "features", label: t("features") },
    { id: "screenshots", label: t("screenshots") },
    { id: "sources", label: t("sources") },
  ];
  const pageItems = [
    { href: l("/privacy"), label: t("privacy"), active: onPrivacy },
    { href: l("/support"), label: t("support"), active: onSupport },
  ];

  const itemBase = "rounded-full px-3.5 py-1.5 text-sm font-medium transition-colors";
  const activeCls = "bg-accent text-white shadow-sm";
  const idleCls = "text-muted hover:bg-surface-2 hover:text-foreground";

  function SectionLink({ id, label, mobile }: { id: string; label: string; mobile?: boolean }) {
    const isActive = isHome && active === id;
    const cls = `${mobile ? "rounded-lg px-3 py-2.5 text-sm font-medium transition-colors" : itemBase} ${isActive ? activeCls : idleCls}`;
    if (isHome) return <a href={`#${id}`} onClick={() => setOpen(false)} className={cls}>{label}</a>;
    return <Link href={`${l("/")}#${id}`} onClick={() => setOpen(false)} className={cls}>{label}</Link>;
  }

  return (
    <nav className="fixed inset-x-0 top-0 z-50 border-b border-border/70 bg-background/85 backdrop-blur-xl">
      <div className="mx-auto max-w-6xl px-4 sm:px-6">
        <div className="flex h-16 items-center justify-between">
          <Link href={l("/")} className="flex items-center gap-2.5">
            <Image src="/icon.png" alt="EVMap iOS" width={34} height={34} className="rounded-[10px] shadow-sm" />
            <span className="text-lg font-bold tracking-tight">
              EVMap <span className="font-semibold text-muted">for iOS</span>
            </span>
          </Link>

          <div className="hidden items-center gap-1 rounded-full border border-border bg-surface/70 px-1.5 py-1 md:flex">
            {sectionItems.map((item) => <SectionLink key={item.id} id={item.id} label={item.label} />)}
            {pageItems.map((item) => (
              <Link key={item.href} href={item.href} className={`${itemBase} ${item.active ? activeCls : idleCls}`}>
                {item.label}
              </Link>
            ))}
          </div>

          <div className="hidden items-center gap-2 md:flex">
            {/* Language switcher dropdown */}
            <div ref={langRef} className="relative">
              <button
                onClick={() => setLangOpen(!langOpen)}
                className="flex items-center gap-1.5 rounded-full px-3 py-2 text-sm font-medium text-muted transition-colors hover:bg-surface-2 hover:text-foreground"
                aria-label="Change language"
              >
                <Globe className="h-4 w-4" />
                <span>{locale.toUpperCase()}</span>
                <ChevronDown className={`h-3.5 w-3.5 transition-transform ${langOpen ? "rotate-180" : ""}`} />
              </button>
              {langOpen && (
                <div className="absolute right-0 top-full mt-1.5 w-36 overflow-hidden rounded-xl border border-border bg-background shadow-lg">
                  {routing.locales.map((loc) => (
                    <Link
                      key={loc}
                      href={`/${loc}${pathWithoutLocale}`}
                      onClick={() => setLangOpen(false)}
                      className={`flex items-center justify-between px-4 py-2.5 text-sm transition-colors hover:bg-surface ${
                        loc === locale ? "font-semibold text-accent" : "text-foreground"
                      }`}
                    >
                      {LOCALE_LABELS[loc]}
                      {loc === locale && <span className="h-1.5 w-1.5 rounded-full bg-accent" />}
                    </Link>
                  ))}
                </div>
              )}
            </div>
            <a
              href={siteConfig.appStoreUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-2 rounded-full bg-accent px-4 py-2 text-sm font-semibold text-white shadow-sm transition-colors hover:bg-accent-hover"
            >
              {t("download")}
            </a>
          </div>

          <button
            onClick={() => setOpen(!open)}
            className="rounded-lg p-2 text-muted transition-colors hover:bg-surface-2 hover:text-foreground md:hidden"
            aria-label="Menu"
          >
            {open ? <X className="h-5 w-5" /> : <Menu className="h-5 w-5" />}
          </button>
        </div>
      </div>

      {open && (
        <div className="border-t border-border bg-background/95 backdrop-blur-xl md:hidden">
          <div className="flex flex-col gap-1 px-4 py-4">
            {sectionItems.map((item) => <SectionLink key={item.id} id={item.id} label={item.label} mobile />)}
            {pageItems.map((item) => (
              <Link key={item.href} href={item.href} onClick={() => setOpen(false)}
                className={`rounded-lg px-3 py-2.5 text-sm font-medium transition-colors ${item.active ? activeCls : idleCls}`}>
                {item.label}
              </Link>
            ))}
            {/* Language section on mobile */}
            <div className="mt-1 border-t border-border pt-3">
              <p className="mb-2 px-3 text-xs font-semibold uppercase tracking-wider text-muted">
                {LOCALE_LABELS[locale]}
              </p>
              <div className="grid grid-cols-2 gap-1">
                {routing.locales.map((loc) => (
                  <Link key={loc} href={`/${loc}${pathWithoutLocale}`} onClick={() => setOpen(false)}
                    className={`rounded-lg px-3 py-2 text-sm transition-colors ${
                      loc === locale ? "bg-accent/10 font-semibold text-accent" : "text-muted hover:bg-surface-2 hover:text-foreground"
                    }`}>
                    {LOCALE_LABELS[loc]}
                  </Link>
                ))}
              </div>
            </div>
            <a href={siteConfig.appStoreUrl} target="_blank" rel="noopener noreferrer"
              className="mt-2 inline-flex items-center justify-center gap-2 rounded-full bg-accent px-4 py-2.5 text-sm font-semibold text-white">
              {t("download")}
            </a>
          </div>
        </div>
      )}
    </nav>
  );
}
