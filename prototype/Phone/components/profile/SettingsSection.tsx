"use client";

import { useState } from "react";
import { useAppStore } from "@/lib/store/useAppStore";
import AccordionSection from "@/components/AccordionSection";
import { Settings } from "lucide-react";
import clsx from "clsx";

function Toggle({ on, onChange }: { on: boolean; onChange: (v: boolean) => void }) {
  return (
    <button
      onClick={() => onChange(!on)}
      className={clsx("h-6 w-11 shrink-0 rounded-full p-0.5 transition", on ? "bg-accent" : "bg-ink/15")}
    >
      <span className={clsx("block h-5 w-5 rounded-full bg-white transition", on && "translate-x-5")} />
    </button>
  );
}

export default function SettingsSection({ open, onToggle }: { open: boolean; onToggle: () => void }) {
  const personalizationEnabled = useAppStore((s) => s.personalizationEnabled);
  const setPersonalizationEnabled = useAppStore((s) => s.setPersonalizationEnabled);
  const clearChat = useAppStore((s) => s.clearChat);

  // WeChat-style privacy setting: allow friends to find you by phone number
  const [findByPhone, setFindByPhone] = useState(true);

  return (
    <AccordionSection icon={Settings} title="Settings & Privacy" open={open} onToggle={onToggle}>
      <div className="space-y-4">
        <div className="flex items-center justify-between">
          <div>
            <p className="text-sm font-medium text-ink">Personalization</p>
            <p className="text-[11px] text-ink/40">Lets the concierge use your AI memory and preferences.</p>
          </div>
          <Toggle on={personalizationEnabled} onChange={setPersonalizationEnabled} />
        </div>

        <div className="border-t border-black/5 pt-3.5">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-ink">Find me by phone number</p>
              <p className="text-[11px] text-ink/40">
                WeChat-style: Friends who have your number can discover your @handle.
              </p>
            </div>
            <Toggle on={findByPhone} onChange={setFindByPhone} />
          </div>
        </div>

        <div className="rounded-xl bg-paper border border-black/5 p-3 text-[11px] text-ink/60">
          <p className="font-semibold text-ink">🔒 Phone Privacy: Always Masked</p>
          <p className="mt-0.5 text-ink/45">
            Your phone number is never visible in group chats, peer threads, or to delivery riders. Calls are routed through encrypted In-App VoIP.
          </p>
        </div>

        <button
          onClick={clearChat}
          className="mt-2 w-full rounded-lg border border-black/10 px-3 py-2 text-left text-sm font-medium text-ink/70 hover:border-red-300 hover:text-red-500"
        >
          Clear AI chat history
        </button>
      </div>
    </AccordionSection>
  );
}
