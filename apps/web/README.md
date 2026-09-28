# apps/web/ — Production Web Applications

This directory contains the production web applications of the **evryy** Super App platform, developed by **Elifsi Technologies Private Limited**:

```
apps/web/
├── consumer/     # Customer-facing production web application (Next.js + React)
└── partner/      # Merchant/Partner business management dashboard (Next.js + React)
```

> **Crucial Distinction**:
> - [`prototype/Phone/`](../../prototype/Phone/) is the **existing working interactive prototype and design reference**.
> - [`apps/web/`](./) contains the **future production web applications** that will connect directly to the shared Supabase backend (`supabase/`) with production authentication, database persistence, and payment gateways.
