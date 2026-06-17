import { useTranslations } from "next-intl";
import { getTranslations } from "next-intl/server";
import { MessageSquare } from "lucide-react";
import { SupportForm } from "@/components/marketing/support-form";
import { siteConfig } from "@/lib/site-config";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "support" });
  return {
    title: t("title"),
    description: t("subtitle"),
    alternates: {
      canonical: `${siteConfig.url}/${locale}/support`,
      languages: {
        de: `${siteConfig.url}/de/support`,
        en: `${siteConfig.url}/en/support`,
        "x-default": `${siteConfig.url}/en/support`,
      },
    },
  };
}

export default function SupportPage() {
  const t = useTranslations("support");

  return (
    <div className="px-4 py-16 sm:px-6">
      <div className="mx-auto max-w-xl">
        <div className="mb-8 text-center">
          <div className="mb-4 inline-flex h-14 w-14 items-center justify-center rounded-2xl bg-accent/10">
            <MessageSquare className="h-7 w-7 text-accent" />
          </div>
          <h1 className="text-3xl font-bold sm:text-4xl">{t("title")}</h1>
          <p className="mt-3 text-muted">{t("subtitle")}</p>
        </div>

        <SupportForm />
      </div>
    </div>
  );
}
