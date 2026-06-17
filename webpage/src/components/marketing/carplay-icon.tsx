// Apple CarPlay glyph: rounded-square badge with the CarPlay car silhouette.
// Drawn as a single currentColor mark to match the line-icon style of the page.
export function CarPlayIcon({ className = "" }: { className?: string }) {
  return (
    <svg viewBox="0 0 24 24" className={className} fill="none" aria-hidden="true">
      <rect
        x="2.5"
        y="2.5"
        width="19"
        height="19"
        rx="5"
        stroke="currentColor"
        strokeWidth="1.6"
      />
      <path
        d="M7.2 14.4l.9-2.7a2 2 0 0 1 1.9-1.35h4a2 2 0 0 1 1.9 1.35l.9 2.7"
        stroke="currentColor"
        strokeWidth="1.6"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <path
        d="M6.6 14.4h10.8v2a.7.7 0 0 1-.7.7h-1a.7.7 0 0 1-.7-.7v-.6H9v.6a.7.7 0 0 1-.7.7h-1a.7.7 0 0 1-.7-.7v-2z"
        fill="currentColor"
      />
    </svg>
  );
}
