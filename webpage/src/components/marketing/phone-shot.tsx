import Image from "next/image";

interface PhoneShotProps {
  src: string;
  alt: string;
  className?: string;
  priority?: boolean;
}

// Renders a pre-framed App Store screenshot (1290×2796, transparent iPhone bezel).
export function PhoneShot({ src, alt, className = "", priority }: PhoneShotProps) {
  return (
    <Image
      src={src}
      alt={alt}
      width={1260}
      height={2596}
      priority={priority}
      sizes="(max-width: 768px) 60vw, 280px"
      className={`phone-shadow h-auto w-full select-none ${className}`}
    />
  );
}
