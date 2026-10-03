"use client";

import { useState } from "react";
import AccordionSection from "@/components/AccordionSection";
import { Ticket, Share2, Sparkles, Check, Copy, Gift } from "lucide-react";
import clsx from "clsx";

interface Voucher {
  id: string;
  code: string;
  title: string;
  discount: string;
  category: "food" | "rides" | "all";
  minOrder: number;
  expiresIn: string;
}

const DEMO_VOUCHERS: Voucher[] = [
  {
    id: "v1",
    code: "WELCOME100",
    title: "Welcome Bonus Voucher",
    discount: "NPR 100 OFF",
    category: "all",
    minOrder: 300,
    expiresIn: "Expires in 5 days",
  },
  {
    id: "v2",
    code: "MOMOLOVE",
    title: "Food & Mart Special",
    discount: "NPR 150 OFF",
    category: "food",
    minOrder: 600,
    expiresIn: "Expires tomorrow",
  },
  {
    id: "v3",
    code: "FREERIDE",
    title: "Ride Partner Perk",
    discount: "FREE PLATFORM FEE",
    category: "rides",
    minOrder: 150,
    expiresIn: "Expires in 12 days",
  },
];

export default function VouchersSection({ open, onToggle }: { open: boolean; onToggle: () => void }) {
  const [promoInput, setPromoInput] = useState("");
  const [promoMessage, setPromoMessage] = useState<{ text: string; success: boolean } | null>(null);
  const [copiedCode, setCopiedCode] = useState<string | null>(null);

  const handleApplyPromo = (e: React.FormEvent) => {
    e.preventDefault();
    if (!promoInput.trim()) return;

    if (promoInput.toUpperCase() === "EVRRY50" || promoInput.toUpperCase() === "DASHAIN") {
      setPromoMessage({ text: "Promo applied! NPR 50 added to your voucher wallet.", success: true });
      setPromoInput("");
    } else {
      setPromoMessage({ text: "Invalid or expired promo code.", success: false });
    }
    setTimeout(() => setPromoMessage(null), 3500);
  };

  const handleCopy = (code: string) => {
    if (typeof window !== "undefined") {
      navigator.clipboard?.writeText(code);
      setCopiedCode(code);
      setTimeout(() => setCopiedCode(null), 2000);
    }
  };

  const handleShareReferral = () => {
    const text = "Join me on evrry! Use my code EVRRY-RAHUL to get a NPR 100 welcome voucher on your first food order or ride: https://evrry.com.np/r/rahul";
    if (typeof window !== "undefined") {
      if (navigator.share) {
        navigator.share({ title: "evrry Referral", text });
      } else {
        navigator.clipboard?.writeText(text);
        alert("Referral link copied to clipboard! Share on WhatsApp.");
      }
    }
  };

  return (
    <AccordionSection
      icon={Ticket}
      title="Vouchers & Referrals"
      subtitle={`${DEMO_VOUCHERS.length} active vouchers · Refer & earn`}
      open={open}
      onToggle={onToggle}
    >
      {/* Refer & Earn Banner */}
      <div className="relative overflow-hidden rounded-xl2 bg-gradient-to-br from-amber-500 via-amber-600 to-yellow-600 p-4 text-white shadow-sm">
        <div className="flex items-start justify-between">
          <div>
            <span className="inline-flex items-center gap-1 rounded-full bg-white/20 px-2 py-0.5 text-[10px] font-bold uppercase tracking-wider backdrop-blur-sm">
              <Gift size={11} /> Refer & Earn
            </span>
            <h3 className="mt-1.5 text-base font-bold leading-snug">Invite friends, get NPR 150</h3>
            <p className="mt-0.5 text-xs text-white/90">Your friend gets NPR 100 on signup; you get NPR 150 when they complete an order.</p>
          </div>
        </div>

        <div className="mt-3.5 flex items-center justify-between gap-2 rounded-xl bg-black/15 p-2.5 backdrop-blur-sm">
          <div>
            <p className="text-[10px] uppercase font-semibold text-white/70">Your referral code</p>
            <p className="text-xs font-mono font-bold tracking-wider text-white">EVRRY-RAHUL</p>
          </div>
          <button
            onClick={handleShareReferral}
            className="flex items-center gap-1.5 rounded-lg bg-white px-3 py-1.5 text-xs font-bold text-amber-700 shadow-sm hover:bg-white/95 active:scale-95 transition"
          >
            <Share2 size={12} /> Invite via WhatsApp
          </button>
        </div>

        <div className="mt-2.5 flex items-center justify-between text-[11px] text-white/80">
          <span>Invited: 4 friends</span>
          <span>Earned: NPR 300 in vouchers</span>
        </div>
      </div>

      {/* Digital Stamp Card (Japanese Point-Card Model) */}
      <div className="mt-3.5 rounded-xl2 border border-black/5 bg-paper p-3.5">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-1.5">
            <Sparkles size={14} className="text-brand" />
            <p className="text-xs font-bold text-ink">Digital Stamp Card</p>
          </div>
          <span className="text-[11px] font-semibold text-brand">7 / 10 Stamps</span>
        </div>
        <p className="mt-1 text-[11px] text-ink/55">
          1 stamp per NPR 500 spent. Collect 10 stamps to unlock flat <strong className="text-ink">NPR 500 Rebate Voucher</strong>!
        </p>

        {/* 10 Stamp Slots */}
        <div className="mt-2.5 grid grid-cols-5 gap-1.5">
          {Array.from({ length: 10 }).map((_, i) => (
            <div
              key={i}
              className={clsx(
                "flex h-8 items-center justify-center rounded-lg border text-xs font-bold transition",
                i < 7
                  ? "border-brand bg-brand/20 text-brand shadow-xs"
                  : "border-black/10 bg-white/60 text-ink/20"
              )}
            >
              {i < 7 ? "✓" : i + 1}
            </div>
          ))}
        </div>
      </div>

      {/* Enter Promo Code */}
      <form onSubmit={handleApplyPromo} className="mt-3.5">
        <label className="text-xs font-medium text-ink/60">Have a promo code?</label>
        <div className="mt-1 flex gap-2">
          <input
            type="text"
            value={promoInput}
            onChange={(e) => setPromoInput(e.target.value)}
            placeholder="e.g. EVRRY50"
            className="flex-1 rounded-xl border border-black/15 bg-white px-3 py-2 text-xs font-mono uppercase text-ink placeholder:normal-case placeholder:font-sans placeholder:text-ink/30 focus:border-brand focus:outline-none"
          />
          <button
            type="submit"
            className="rounded-xl bg-ink px-4 py-2 text-xs font-semibold text-white hover:bg-ink/90 active:scale-95 transition"
          >
            Apply
          </button>
        </div>
        {promoMessage && (
          <p
            className={clsx(
              "mt-1.5 text-xs font-medium animate-in fade-in",
              promoMessage.success ? "text-emerald-600" : "text-red-500"
            )}
          >
            {promoMessage.text}
          </p>
        )}
      </form>

      {/* Active Vouchers List */}
      <div className="mt-4 space-y-2">
        <p className="text-xs font-semibold text-ink/70">Your Active Vouchers</p>
        {DEMO_VOUCHERS.map((v) => (
          <div
            key={v.id}
            className="flex items-center justify-between rounded-xl border border-black/5 bg-white p-3 shadow-xs"
          >
            <div>
              <div className="flex items-center gap-1.5">
                <span className="rounded bg-brandSoft px-1.5 py-0.5 text-[10px] font-bold text-brand">
                  {v.discount}
                </span>
                <span className="text-[10px] font-medium text-ink/40">Min. NPR {v.minOrder}</span>
              </div>
              <p className="mt-1 text-xs font-semibold text-ink">{v.title}</p>
              <p className="text-[10px] text-ink/40">{v.expiresIn}</p>
            </div>
            <button
              onClick={() => handleCopy(v.code)}
              className="flex items-center gap-1 rounded-lg border border-black/10 px-2.5 py-1.5 text-[11px] font-mono font-medium text-ink/70 hover:bg-black/5 active:scale-95 transition"
            >
              {copiedCode === v.code ? (
                <>
                  <Check size={11} className="text-emerald-600" /> Copied
                </>
              ) : (
                <>
                  <Copy size={11} /> {v.code}
                </>
              )}
            </button>
          </div>
        ))}
      </div>
    </AccordionSection>
  );
}
