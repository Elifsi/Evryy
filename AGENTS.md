<!-- BEGIN:nextjs-agent-rules -->

# This is NOT the Next.js you know

This version has breaking changes — APIs, conventions, and file structure may all differ from your training data. Read the relevant guide in `node_modules/next/dist/docs/` (resolved from this file's directory; in monorepos the `next` package may not be visible from the repo root) before writing any code. Heed deprecation notices.

This block is written and re-added by `next dev` — verify at `node_modules/next/dist/server/lib/generate-agent-files.js`. Removing it from a diff only re-creates the uncommitted change; committing it with your work keeps the tree clean.

<!-- END:nextjs-agent-rules -->

> **Monorepo note**: This repository contains the **evryy** Super App platform, developed by **Elifsi Technologies Private Limited**:
>
> | Path | Purpose | Status |
> |------|---------|--------|
> | `prototype/Phone/` | Working Next.js prototype (visual & functional reference) | ✅ Current |
> | `apps/consumer/` | Native Android & iOS consumer applications | 🔮 Planned |
> | `apps/partner/` | Native Android & iOS partner applications | 🔮 Planned |
> | `apps/web/` | Production consumer & partner web applications | 🔮 Planned |
> | `supabase/` | Centralized shared backend (DB, Auth, RLS, Edge Functions) | 🔮 Planned |
>
> **Running the Prototype**:
> Run `next dev` (and all npm commands) from `prototype/Phone/`, not the repository root.
> The `node_modules/next/` package is installed at `prototype/Phone/node_modules/next/`.
