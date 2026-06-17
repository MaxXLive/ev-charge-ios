"use client";

import { useTranslations } from "next-intl";
import { Github } from "lucide-react";
import { siteConfig } from "@/lib/site-config";

// Sized to match the official App Store badge (52px tall, ~9px corner radius).
export function GithubButton({
  href = siteConfig.githubUrl,
  className = "",
}: {
  href?: string;
  className?: string;
}) {
  const t = useTranslations("home");
  return (
    <a
      href={href}
      target="_blank"
      rel="noopener noreferrer"
      className={`inline-flex h-[52px] items-center gap-2.5 rounded-[9px] border border-white/15 bg-black px-5 text-[15px] font-medium text-white transition-transform hover:scale-[1.03] ${className}`}
    >
      <Github className="h-5 w-5" />
      {t("openSourceGithubCta")}
    </a>
  );
}
