import type { Config } from "tailwindcss";

// EVRRY design tokens — see docs/design/UI_COLOR_TOKENS.json (source of truth).
// Values flagged "provisional" there must be re-verified against the original brand assets.
const config: Config = {
  content: [
    "./app/**/*.{ts,tsx}",
    "./components/**/*.{ts,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        ink: "#0B172A", // text.primary
        paper: "#FFFFFF", // background.main
        brand: {
          DEFAULT: "#005EFF", // brand.primary
          secondary: "#2F82F6", // brand.secondary
          light: "#93C5FD", // brand.accentLight (decorative only)
          soft: "#EFF6FF", // surface.primarySoft (provisional)
        },
        brandSoft: "#EFF6FF",
        muted: "#64758B", // text.secondary
        subtle: "#F8FAFC", // background.subtle (provisional)
        line: "#CBD5E1", // border.default (provisional)
        success: "#10B981", // status.success (provisional; icons/fills only)
        danger: "#EF4444", // status.error (provisional; icons/fills only)
      },
      fontFamily: {
        sans: ["Inter Variable", "Inter", "system-ui", "-apple-system", "Segoe UI", "Roboto", "sans-serif"],
      },
      borderRadius: {
        xl2: "1.25rem",
      },
    },
  },
  plugins: [],
};
export default config;
