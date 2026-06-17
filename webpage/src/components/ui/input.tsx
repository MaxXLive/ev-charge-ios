import { InputHTMLAttributes, forwardRef } from "react";

interface InputProps extends InputHTMLAttributes<HTMLInputElement> {
  label?: string;
  error?: string;
}

export const Input = forwardRef<HTMLInputElement, InputProps>(
  ({ label, error, className = "", ...props }, ref) => {
    return (
      <div className="space-y-1.5">
        {label && <label className="text-sm font-medium text-accent-deep">{label}</label>}
        <input
          ref={ref}
          className={`w-full rounded-xl bg-surface border border-border px-4 py-3 text-foreground placeholder:text-muted/60 focus:outline-none focus:border-accent transition-colors ${error ? "border-danger" : ""} ${className}`}
          {...props}
        />
        {error && <p className="text-sm text-danger">{error}</p>}
      </div>
    );
  }
);

Input.displayName = "Input";
