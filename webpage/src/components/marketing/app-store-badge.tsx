"use client";

import { useLocale } from "next-intl";
import Image from "next/image";
import { siteConfig } from "@/lib/site-config";

const BADGES: Record<string, string> = {
  de: "/badges/app-store-de.svg",
  en: "/badges/app-store-en.svg",
  cs: "/badges/app-store-cs.svg",
  fr: "/badges/app-store-fr.svg",
  it: "/badges/app-store-it.svg",
  nl: "/badges/app-store-nl.svg",
  no: "/badges/app-store-no.svg",
  pt: "/badges/app-store-pt.svg",
  ro: "/badges/app-store-ro.svg",
  sv: "/badges/app-store-sv.svg",
};

const BADGE_ALT: Record<string, string> = {
  de: "Laden im App Store",
  en: "Download on the App Store",
  cs: "Stáhnout v App Storu",
  fr: "Télécharger dans l'App Store",
  it: "Scarica sull'App Store",
  nl: "Downloaden in de App Store",
  no: "Last ned i App Store",
  pt: "Transferir na App Store",
  ro: "Descarcă din App Store",
  sv: "Hämta i App Store",
};

// Official Apple "Download on the App Store" badge, localized.
export function AppStoreBadge({ className = "" }: { className?: string }) {
  const locale = useLocale();
  const src = BADGES[locale] ?? BADGES.en;
  const alt = BADGE_ALT[locale] ?? BADGE_ALT.en;

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
