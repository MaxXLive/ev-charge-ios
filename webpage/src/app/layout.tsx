import type { Metadata } from "next";
import { Geist } from "next/font/google";
import { Analytics } from "@vercel/analytics/next";
import { siteConfig } from "@/lib/site-config";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  metadataBase: new URL(siteConfig.url),
  title: {
    default: "EVMap for iOS: Find EV charging stations",
    template: "%s | EVMap for iOS",
  },
  description:
    "Find EV charging stations on iOS. Ad-free, open source, privacy-friendly. Powered by GoingElectric, Open Charge Map and Nobil with real-time availability.",
  keywords: [
    "EV charging",
    "Ladestationen",
    "Elektroauto",
    "charging stations",
    "GoingElectric",
    "Open Charge Map",
    "Nobil",
    "EVMap",
    "iOS",
    "CarPlay",
  ],
  authors: [{ name: "Max Ermackov" }],
  creator: "Max Ermackov",
  appleWebApp: {
    capable: true,
    statusBarStyle: "black-translucent",
    title: "EVMap",
  },
  openGraph: {
    type: "website",
    siteName: "EVMap for iOS",
    locale: "en_US",
    alternateLocale: "de_DE",
    images: [
      { url: "/icon.png", width: 1024, height: 1024, alt: "EVMap App Icon" },
    ],
  },
  twitter: {
    card: "summary",
    title: "EVMap for iOS: Find EV charging stations",
    description:
      "Ad-free, open source EV charging station finder for iOS with real-time availability.",
    images: ["/icon.png"],
  },
  alternates: {
    canonical: siteConfig.url,
    languages: {
      de: `${siteConfig.url}/de`,
      en: `${siteConfig.url}/en`,
      "x-default": `${siteConfig.url}/en`,
    },
  },
  robots: { index: true, follow: true },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html suppressHydrationWarning>
      <head>
        <meta name="theme-color" content="#15a34a" />
        <link rel="apple-touch-icon" href="/icon.png" />
      </head>
      <body
        className={`${geistSans.variable} antialiased bg-background text-foreground`}
      >
        {children}
        <Analytics />
      </body>
    </html>
  );
}
