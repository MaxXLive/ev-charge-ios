"use client";

import { useLocale } from "next-intl";
import Image from "next/image";
import { siteConfig } from "@/lib/site-config";

const BADGES: Record<string, string> = {
  de: "/badges/app-store-de.svg",
  en: "/badges/app-store-en.svg",
};

// Official Apple "Download on the App Store" badge, localized.
export function AppStoreBadge({ className = "" }: { className?: string }) {
  const locale = useLocale();
  const src = BADGES[locale] ?? BADGES.en;
  const alt = locale === "de" ? "Laden im App Store" : "Download on the App Store";

  return (
    <a
      href={siteConfig.appStoreUrl}
      target="_blank"
      rel="noopener noreferrer"
      aria-label={alt}
      className={`inline-flex transition-transform hover:scale-[1.03] ${className}`}
    >
      <Image src={src} alt={alt} width={156} height={52} unoptimized className="h-[52px] w-auto" />
    </a>
  );
}
