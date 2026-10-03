# Contributing to evrry

Thank you for contributing to **evrry**, an open-source Super App platform developed by **Elifsi Technologies Private Limited**! This document outlines our development workflows, coding standards, and security policies.

---

## 1. Repository Layout

```
Evrry/
├── prototype/
│   └── Phone/               ← Working Next.js reference implementation (active)
├── apps/
│   ├── consumer/            ← Planned Consumer applications (Android / iOS)
│   ├── partner/             ← Planned Partner applications (Android / iOS)
│   └── web/                 ← Planned Production Web applications (Consumer / Partner)
├── services/                ← Background microservices (AI Voice Gateway, Notifications)
├── supabase/                ← Centralized backend (Migrations, Functions, RLS)
└── docs/                    ← Architecture, product, and developer documentation
```

---

## 2. Working on the Prototype

The interactive reference prototype is located at `prototype/Phone/`.

### Local Setup
```bash
# Clone the repository
git clone https://github.com/Elifsi/Evrry.git
cd Evrry/prototype/Phone

# Install dependencies
npm install

# (Optional) Add AI API keys for full tool-calling support
cp .env.example .env.local

# Run the Next.js app and chat relay
npm run dev:all
```

Open [http://localhost:3000](http://localhost:3000).

### Pre-PR Quality Checklist (Prototype)
Before opening a pull request that touches `prototype/Phone/`, run the full validation suite:

```bash
cd prototype/Phone

# 1. Lint
npm run lint

# 2. TypeScript typecheck
npx tsc --noEmit

# 3. Unit and integration test suite (Vitest)
npm run test

# 4. Production Next.js build
npm run build
```

---

## 3. Policy on Planned Applications (`apps/`)

- The directories under `apps/` represent planned production clients (`apps/consumer/`, `apps/partner/`, `apps/web/`).
- **Do not submit PRs containing fake code, placeholder stubs, or empty frameworks** merely to populate these directories.
- Actual implementations will be coordinated with the core engineering team according to the [Platform Roadmap](./docs/roadmap/README.md).

---

## 4. Security & Financial Directives

All contributors must adhere to strict security rules:

1. **Zero Client Secrets**:
   - Never commit or embed Supabase `service_role` keys in client apps (Android, iOS, Web).
   - Never commit or embed payment gateway secrets (eSewa, Khalti, Fonepay, Card Gateway) in client apps.
2. **Server-Side Financial Integrity**:
   - Never rely on client-side calculations for prices, discounts, taxes, or partner earnings.
   - All financial operations must execute server-side in Supabase Edge Functions or PostgreSQL stored functions.
3. **Mandatory Row Level Security**:
   - Any new SQL migration creating a database table must enable RLS and specify explicit policies for all CRUD actions.

---

## 5. Pull Requests & Commit Hygiene

- **Focused Changes**: Keep PRs small and scoped to a single feature or bug fix.
- **Explain the "Why"**: Include clear context, motivation, and test steps in your PR description.
- **Link Issues**: Reference related issues (e.g. `Closes #42`).
- **No Unrelated Formatting**: Avoid wholesale reformatting or unnecessary dependency upgrades.

---

## 6. Code of Conduct

All contributors are expected to uphold our community standards as described in [`CODE_OF_CONDUCT.md`](./CODE_OF_CONDUCT.md).
