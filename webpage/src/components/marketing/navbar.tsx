"use client";

import { useState, useEffect } from "react";
import { useTranslations, useLocale } from "next-intl";
import Link from "next/link";
import Image from "next/image";
import { usePathname } from "next/navigation";
import { Menu, X, Globe } from "lucide-react";
import { siteConfig } from "@/lib/site-config";

const SECTION_IDS = ["features", "screenshots", "sources"] as const;

export function MarketingNavbar() {
  const t = useTranslations("nav");
  const locale = useLocale();
  const [open, setOpen] = useState(false);
  const [active, setActive] = useState<string>("");

  const pathname = usePathname();
  const l = (path: string) => `/${locale}${path}`;
  const otherLocale = locale === "de" ? "en" : "de";
  const switchedPath = pathname.replace(/^\/(de|en)/, `/${otherLocale}`);

  const isHome = pathname === `/${locale}` || pathname === `/${locale}/`;
  const onPrivacy = pathname.startsWith(`/${locale}/privacy`);
  const onSupport = pathname.startsWith(`/${locale}/support`);

  // Scroll-spy: highlight the section currently near the viewport centre.
  useEffect(() => {
    if (!isHome) {
      setActive("");
      return;
    }
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((e) => {
          if (e.isIntersecting) setActive(e.target.id);
        });
      },
      { rootMargin: "-45% 0px -50% 0px", threshold: 0 }
    );
    SECTION_IDS.forEach((id) => {
      const el = document.getElementById(id);
      if (el) observer.observe(el);
    });

    const onScroll = () => {
      if (window.scrollY < 120) setActive("");
    };
    window.addEventListener("scroll", onScroll, { passive: true });
    onScroll();

    return () => {
      observer.disconnect();
      window.removeEventListener("scroll", onScroll);
    };
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

  // Section links: hash-only on home (scroll from current position, no reload),
  // full path elsewhere (client navigation back to the landing page).
  function SectionLink({ id, label, mobile }: { id: string; label: string; mobile?: boolean }) {
    const isActive = isHome && active === id;
    const cls = `${mobile ? "rounded-lg px-3 py-2.5 text-sm font-medium transition-colors" : itemBase} ${
      isActive ? activeCls : idleCls
    }`;
    if (isHome) {
      return (
        <a href={`#${id}`} onClick={() => setOpen(false)} className={cls}>
          {label}
        </a>
      );
    }
    return (
      <Link href={`${l("/")}#${id}`} onClick={() => setOpen(false)} className={cls}>
        {label}
      </Link>
    );
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
            {sectionItems.map((item) => (
              <SectionLink key={item.id} id={item.id} label={item.label} />
            ))}
            {pageItems.map((item) => (
              <Link key={item.href} href={item.href} className={`${itemBase} ${item.active ? activeCls : idleCls}`}>
                {item.label}
              </Link>
            ))}
          </div>

          <div className="hidden items-center gap-2 md:flex">
            <Link
              href={switchedPath}
              className="flex items-center gap-1.5 rounded-full px-3 py-2 text-sm font-medium text-muted transition-colors hover:bg-surface-2 hover:text-foreground"
              title={otherLocale === "en" ? "Switch to English" : "Zu Deutsch wechseln"}
            >
              <Globe className="h-4 w-4" />
              {otherLocale.toUpperCase()}
            </Link>
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
            {sectionItems.map((item) => (
              <SectionLink key={item.id} id={item.id} label={item.label} mobile />
            ))}
            {pageItems.map((item) => (
              <Link
                key={item.href}
                href={item.href}
                onClick={() => setOpen(false)}
                className={`rounded-lg px-3 py-2.5 text-sm font-medium transition-colors ${
                  item.active ? activeCls : idleCls
                }`}
              >
                {item.label}
              </Link>
            ))}
            <Link
              href={switchedPath}
              onClick={() => setOpen(false)}
              className="flex items-center gap-2 rounded-lg px-3 py-2.5 text-sm font-medium text-muted hover:bg-surface-2 hover:text-foreground"
            >
              <Globe className="h-4 w-4" />
              {otherLocale === "en" ? "English" : "Deutsch"}
            </Link>
            <a
              href={siteConfig.appStoreUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="mt-2 inline-flex items-center justify-center gap-2 rounded-full bg-accent px-4 py-2.5 text-sm font-semibold text-white"
            >
              {t("download")}
            </a>
          </div>
        </div>
      )}
    </nav>
  );
}
