# apps/web/admin — evrry Superadmin Operations & KYC Platform

> **Platform**: evrry Super App Ecosystem  
> **Company**: Elifsi Technologies Private Limited  
> **Repository**: [https://github.com/Elifsi/Evrry.git](https://github.com/Elifsi/Evrry.git)  

## Status

🔮 **Planned — Implementation Blueprint Ready**

---

## 1. Role & Purpose

The **Superadmin Operations Console** is the internal web command center for **Elifsi Technologies** operations, compliance, support, and finance teams.

It is distinct from the **Partner Web Portal** (`apps/web/partner`):
- `apps/web/partner`: Used by external restaurant owners, hotel managers, and fleet operators to manage their individual businesses.
- `apps/web/admin`: Used exclusively by internal Elifsi staff to verify KYC documents, onboard partners, moderate bad actors, monitor midnight payout batches, trigger emergency city kill-switches, and audit platform finances.

---

## 2. Core Functional Modules

1. **Partner KYC & Verification Queue**:
   - Nepali Driving License & Vehicle Blue Book verification for riders/drivers.
   - PAN/VAT certificates, company registration documents, and food hygiene permits for merchants.
   - Lalpurja (property ownership) & lease agreements for landlords and hotel hosts.
   - One-click approve/reject with automated SMS/push notification feedback.

2. **User Moderation & Fraud Prevention**:
   - Global search across users, phone numbers, vehicle plates, and device UUIDs.
   - Account actions: Temporary suspension, permanent ban, and Cash on Delivery (COD) disablement.
   - Device and SIM blacklist to prevent repeat fraud.

3. **Financial Settlement & Payout Oversight**:
   - Daily settlement review before connectIPS / Khalti Payout API execution.
   - Platform commission configuration per vertical and custom merchant contracts.
   - Cash-in-hand reconciliation for delivery riders.

4. **Geospatial & Operational Kill-Switches**:
   - Ward-level toggle for service availability (weather disruptions, strikes).
   - Surge pricing multiplier controls.

5. **Customer Support & Dispute Resolutions**:
   - Inspection of order photos, chat transcripts, and rider GPS trajectories.
   - Automated direct refund triggers to eSewa / Khalti / Fonepay.

---

## 3. Technology Stack

- **Framework**: Next.js 15+ (App Router with Server Actions & React Server Components).
- **Security**: Supabase Auth with mandatory MFA (TOTP) and `public.profiles.role = 'superadmin'`.
- **UI & Data**: Tailwind CSS, Radix UI, TanStack Table v8, Tremor / Recharts analytics.
- **Audit**: All mutations logged to `public.admin_audit_logs`.
- **Reference Spec**: [`docs/architecture/superadmin.md`](file:///home/rahul/codes/Evrry/docs/architecture/superadmin.md).
