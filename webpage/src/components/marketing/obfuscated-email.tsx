"use client";

import { useEffect, useState } from "react";

// Assembles the address in JS after mount so it never appears as a contiguous
// "user@domain" string in the statically rendered HTML that scrapers read.
const USER = "support";
const DOMAIN = ["ermackov", "de"].join(".");

export function ObfuscatedEmail({ className = "" }: { className?: string }) {
  const [addr, setAddr] = useState<string | null>(null);

  useEffect(() => {
    setAddr(`${USER}@${DOMAIN}`);
  }, []);

  if (!addr) {
    // Pre-hydration / no-JS fallback: human-readable, machine-unfriendly.
    return (
      <span className={className}>
        {USER} [at] {DOMAIN}
      </span>
    );
  }

  return (
    <a href={`mailto:${addr}`} className={className}>
      {addr}
    </a>
  );
}
