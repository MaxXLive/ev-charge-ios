"use client";

import { useState, useEffect, useRef } from "react";
import { useTranslations, useLocale } from "next-intl";
import { Turnstile, type TurnstileInstance } from "@marsidev/react-turnstile";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { CheckCircle, Send } from "lucide-react";

interface Category {
  id: string;
  name: string;
  defaultName: string | null;
  color: string | null;
}

const SITE_KEY = process.env.NEXT_PUBLIC_TURNSTILE_SITE_KEY;

export function SupportForm() {
  const t = useTranslations("support");
  const locale = useLocale();

  const [categories, setCategories] = useState<Category[]>([]);
  const [categoryId, setCategoryId] = useState("");
  const [title, setTitle] = useState("");
  const [message, setMessage] = useState("");
  const [email, setEmail] = useState("");
  const [captchaToken, setCaptchaToken] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [success, setSuccess] = useState(false);
  const [error, setError] = useState("");
  const [fieldErrors, setFieldErrors] = useState<Record<string, string>>({});
  const turnstileRef = useRef<TurnstileInstance>(null);

  useEffect(() => {
    fetch(`/api/feedback?locale=${locale}`)
      .then((r) => r.json())
      .then((data) => {
        if (Array.isArray(data)) setCategories(data);
      })
      .catch(() => {});
  }, [locale]);

  function validate() {
    const errors: Record<string, string> = {};
    if (!categoryId) errors.category = t("required");
    if (!title.trim()) errors.title = t("required");
    if (!message.trim()) errors.message = t("required");
    if (!email.trim()) {
      errors.email = t("required");
    } else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      errors.email = t("invalidEmail");
    }
    if (SITE_KEY && !captchaToken) errors.captcha = t("captchaRequired");
    setFieldErrors(errors);
    return Object.keys(errors).length === 0;
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!validate()) return;

    setLoading(true);
    setError("");

    try {
      const res = await fetch("/api/feedback", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          categoryId,
          title: title.trim(),
          message: message.trim(),
          email: email.trim(),
          captchaToken,
          userId: null,
          apnsToken: null,
          metadata: {
            platform: "web",
            os_version: typeof navigator !== "undefined" ? navigator.userAgent : "",
            device_model: "browser",
            app_version: "1.0",
            app_build: "1",
            locale,
            app: "evmap-ios",
          },
        }),
      });

      if (!res.ok) {
        const data = await res.json().catch(() => ({}));
        if (res.status === 403) throw new Error(t("captchaFailed"));
        throw new Error(data?.message || "");
      }
      setSuccess(true);
    } catch (err) {
      setError(err instanceof Error && err.message ? err.message : t("errorGeneric"));
      turnstileRef.current?.reset();
      setCaptchaToken(null);
    } finally {
      setLoading(false);
    }
  }

  function reset() {
    setSuccess(false);
    setCategoryId("");
    setTitle("");
    setMessage("");
    setEmail("");
    setCaptchaToken(null);
    setFieldErrors({});
    setError("");
    turnstileRef.current?.reset();
  }

  if (success) {
    return (
      <div className="flex flex-col items-center gap-6 rounded-2xl border border-border bg-surface p-8 text-center">
        <div className="flex h-16 w-16 items-center justify-center rounded-full bg-success/10">
          <CheckCircle className="h-8 w-8 text-success" />
        </div>
        <div>
          <h3 className="text-xl font-bold">{t("successTitle")}</h3>
          <p className="mt-2 text-muted">{t("successMessage")}</p>
        </div>
        <Button variant="secondary" onClick={reset}>
          {t("sendAnother")}
        </Button>
      </div>
    );
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-5 rounded-2xl border border-border bg-surface p-6 sm:p-8">
      <div className="flex flex-col gap-1.5">
        <label className="text-sm font-medium text-accent-deep">{t("category")}</label>
        <select
          value={categoryId}
          onChange={(e) => setCategoryId(e.target.value)}
          className="w-full rounded-xl border border-border bg-surface px-3 py-3 text-base text-foreground outline-none transition-colors focus:border-accent"
        >
          <option value="">{t("categoryPlaceholder")}</option>
          {categories.map((c) => (
            <option key={c.id} value={c.id}>
              {c.name || c.defaultName}
            </option>
          ))}
        </select>
        {fieldErrors.category && <p className="text-sm text-danger">{fieldErrors.category}</p>}
      </div>

      <Input
        label={t("titleField")}
        value={title}
        onChange={(e) => setTitle(e.target.value)}
        placeholder={t("titlePlaceholder")}
        error={fieldErrors.title}
      />

      <div className="flex flex-col gap-1.5">
        <label className="text-sm font-medium text-accent-deep">{t("message")}</label>
        <textarea
          value={message}
          onChange={(e) => setMessage(e.target.value)}
          placeholder={t("messagePlaceholder")}
          rows={5}
          className="w-full resize-none rounded-xl border border-border bg-surface px-3 py-3 text-base text-foreground outline-none transition-colors focus:border-accent"
        />
        {fieldErrors.message && <p className="text-sm text-danger">{fieldErrors.message}</p>}
      </div>

      <Input
        label={t("email")}
        type="email"
        value={email}
        onChange={(e) => setEmail(e.target.value)}
        placeholder={t("emailPlaceholder")}
        error={fieldErrors.email}
      />

      {SITE_KEY && (
        <div className="flex flex-col items-center gap-1.5">
          <Turnstile
            ref={turnstileRef}
            siteKey={SITE_KEY}
            onSuccess={(token) => setCaptchaToken(token)}
            onExpire={() => setCaptchaToken(null)}
            onError={() => setCaptchaToken(null)}
            options={{ theme: "auto", language: locale }}
          />
          {fieldErrors.captcha && <p className="text-sm text-danger">{fieldErrors.captcha}</p>}
        </div>
      )}

      {error && <p className="rounded-xl bg-danger/10 px-4 py-3 text-sm text-danger">{error}</p>}

      <Button type="submit" disabled={loading || (!!SITE_KEY && !captchaToken)} fullWidth>
        {loading ? (
          t("sending")
        ) : (
          <>
            <Send className="h-4 w-4" />
            {t("submit")}
          </>
        )}
      </Button>
    </form>
  );
}
