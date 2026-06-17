import { NextRequest, NextResponse } from "next/server";

const FEEDBACK_HOST = process.env.FEEDBACK_HOST || "https://feedback-portal-mx.vercel.app";
const FEEDBACK_API_KEY = process.env.FEEDBACK_API_KEY || "";
const TURNSTILE_SECRET = process.env.TURNSTILE_SECRET_KEY || "";

async function verifyTurnstile(token: string): Promise<boolean> {
  const res = await fetch("https://challenges.cloudflare.com/turnstile/v0/siteverify", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ secret: TURNSTILE_SECRET, response: token }),
  });
  const data = await res.json();
  return data.success === true;
}

async function feedbackFetch(path: string, options?: RequestInit): Promise<Response> {
  return fetch(`${FEEDBACK_HOST}${path}`, {
    ...options,
    headers: {
      Authorization: `Bearer ${FEEDBACK_API_KEY}`,
      ...(options?.body ? { "Content-Type": "application/json" } : {}),
      ...options?.headers,
    },
  });
}

async function forwardFeedbackResponse(res: Response): Promise<NextResponse> {
  const text = await res.text();
  if (!text) return new NextResponse(null, { status: res.status });
  try {
    return NextResponse.json(JSON.parse(text), { status: res.status });
  } catch {
    return new NextResponse(text, {
      status: res.status,
      headers: { "Content-Type": res.headers.get("content-type") || "text/plain" },
    });
  }
}

export async function GET(request: NextRequest) {
  const { searchParams } = request.nextUrl;
  const locale = searchParams.get("locale") || "en";
  const res = await feedbackFetch(`/api/v1/categories?locale=${encodeURIComponent(locale)}`);
  return forwardFeedbackResponse(res);
}

export async function POST(request: NextRequest) {
  const body = await request.json();
  const { captchaToken, ...feedbackBody } = body;

  if (TURNSTILE_SECRET) {
    const valid = await verifyTurnstile(captchaToken || "");
    if (!valid) {
      return NextResponse.json({ message: "CAPTCHA verification failed" }, { status: 403 });
    }
  }

  const res = await feedbackFetch("/api/v1/feedback", {
    method: "POST",
    body: JSON.stringify(feedbackBody),
  });
  return forwardFeedbackResponse(res);
}
