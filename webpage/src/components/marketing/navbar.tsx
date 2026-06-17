"use client";

import { useState } from "react";
import { useTranslations, useLocale } from "next-intl";
import Link from "next/link";
import Image from "next/image";
import { usePathname } from "next/navigation";
import { Menu, X, Globe } from "lucide-react";
import { siteConfig } from "@/lib/site-config";

export function MarketingNavbar() {
  const t = useTranslations("nav");
  const locale = useLocale();
  const [open, setOpen] = useState(false);

  const l = (path: string) => `/${locale}${path}`;
  const otherLocale = locale === "de" ? "en" : "de";
  const pathname = usePathname();
  const switchedPath = pathname.replace(/^\/(de|en)/, `/${otherLocale}`);

  const navItems = [
    { href: `${l("/")}#features`, label: t("features") },
    { href: `${l("/")}#screenshots`, label: t("screenshots") },
    { href: `${l("/")}#sources`, label: t("sources") },
  ];

  return (
    <nav className="fixed inset-x-0 top-0 z-50 border-b border-border/70 bg-background/85 backdrop-blur-xl">
      <div className="mx-auto max-w-6xl px-4 sm:px-6">
        <div className="flex h-16 items-center justify-between">
          <Link href={l("/")} className="flex items-center gap-2.5">
            <Image src="/icon.png" alt="EVMap for iOS" width={34} height={34} className="rounded-[10px] shadow-sm" />
            <span className="text-lg font-bold tracking-tight">
              EVMap <span className="font-semibold text-muted">for iOS</span>
            </span>
          </Link>

          <div className="hidden items-center gap-1 rounded-full border border-border bg-surface/70 px-1.5 py-1 md:flex">
            {navItems.map((item) => (
              <a
                key={item.href}
                href={item.href}
                className="rounded-full px-3.5 py-1.5 text-sm font-medium text-muted transition-colors hover:bg-surface-2 hover:text-foreground"
              >
                {item.label}
              </a>
            ))}
            <Link
              href={l("/privacy")}
              className="rounded-full px-3.5 py-1.5 text-sm font-medium text-muted transition-colors hover:bg-surface-2 hover:text-foreground"
            >
              {t("privacy")}
            </Link>
            <Link
              href={l("/support")}
              className="rounded-full px-3.5 py-1.5 text-sm font-medium text-muted transition-colors hover:bg-surface-2 hover:text-foreground"
            >
              {t("support")}
            </Link>
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
          <div className="flex flex-col gap-1 px-4 py-4" onClick={() => setOpen(false)}>
            {navItems.map((item) => (
              <a key={item.href} href={item.href} className="rounded-lg px-3 py-2.5 text-sm font-medium text-muted hover:bg-surface-2 hover:text-foreground">
                {item.label}
              </a>
            ))}
            <Link href={l("/privacy")} className="rounded-lg px-3 py-2.5 text-sm font-medium text-muted hover:bg-surface-2 hover:text-foreground">
              {t("privacy")}
            </Link>
            <Link href={l("/support")} className="rounded-lg px-3 py-2.5 text-sm font-medium text-muted hover:bg-surface-2 hover:text-foreground">
              {t("support")}
            </Link>
            <Link href={switchedPath} className="flex items-center gap-2 rounded-lg px-3 py-2.5 text-sm font-medium text-muted hover:bg-surface-2 hover:text-foreground">
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
