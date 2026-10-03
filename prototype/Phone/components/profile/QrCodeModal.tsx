"use client";

import { X, QrCode, Share2, ShieldCheck, Download } from "lucide-react";
import { useState } from "react";

interface QrCodeModalProps {
  displayName: string;
  username: string;
  isOpen: boolean;
  onClose: () => void;
}

export default function QrCodeModal({ displayName, username, isOpen, onClose }: QrCodeModalProps) {
  const [copied, setCopied] = useState(false);

  if (!isOpen) return null;

  const handleShare = () => {
    if (typeof window !== "undefined") {
      navigator.clipboard?.writeText(`https://evrry.app/${username}`);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4 backdrop-blur-sm animate-in fade-in duration-200">
      <div className="relative w-full max-w-xs rounded-2xl bg-white p-6 shadow-2xl">
        <button
          onClick={onClose}
          className="absolute right-4 top-4 rounded-full p-1 text-ink/40 hover:bg-black/5 hover:text-ink transition"
        >
          <X size={18} />
        </button>

        <div className="flex flex-col items-center text-center">
          <div className="flex h-14 w-14 items-center justify-center rounded-full bg-accentSoft text-xl font-bold text-accentDark shadow-inner">
            {(displayName || "?").slice(0, 1).toUpperCase()}
          </div>
          <h2 className="mt-2.5 text-lg font-bold text-ink">{displayName || "Your Name"}</h2>
          <p className="text-xs font-semibold text-accentDark">{username || "@evrry_user"}</p>

          {/* WeChat Style Personal QR Code */}
          <div className="mt-5 rounded-2xl border-2 border-dashed border-accent/40 bg-paper p-4 shadow-sm">
            <svg
              className="h-44 w-44 text-ink"
              viewBox="0 0 100 100"
              fill="currentColor"
            >
              {/* Pattern resembling a clean QR code with corner anchors */}
              <rect x="5" y="5" width="26" height="26" rx="4" fill="currentColor" />
              <rect x="9" y="9" width="18" height="18" rx="2" fill="#fffdf6" />
              <rect x="13" y="13" width="10" height="10" rx="1" fill="currentColor" />

              <rect x="69" y="5" width="26" height="26" rx="4" fill="currentColor" />
              <rect x="73" y="9" width="18" height="18" rx="2" fill="#fffdf6" />
              <rect x="77" y="13" width="10" height="10" rx="1" fill="currentColor" />

              <rect x="5" y="69" width="26" height="26" rx="4" fill="currentColor" />
              <rect x="9" y="73" width="18" height="18" rx="2" fill="#fffdf6" />
              <rect x="13" y="77" width="10" height="10" rx="1" fill="currentColor" />

              {/* Data blocks */}
              <rect x="36" y="8" width="6" height="6" rx="1" />
              <rect x="46" y="8" width="8" height="6" rx="1" />
              <rect x="58" y="14" width="6" height="8" rx="1" />
              <rect x="36" y="20" width="8" height="6" rx="1" />
              <rect x="48" y="22" width="6" height="6" rx="1" />

              <rect x="8" y="36" width="6" height="8" rx="1" />
              <rect x="20" y="38" width="8" height="6" rx="1" />
              <rect x="8" y="48" width="6" height="6" rx="1" />
              <rect x="18" y="50" width="6" height="8" rx="1" />

              <rect x="36" y="36" width="10" height="10" rx="2" />
              <rect x="50" y="38" width="14" height="6" rx="1" />
              <rect x="70" y="36" width="8" height="8" rx="1" />
              <rect x="84" y="40" width="8" height="6" rx="1" />
              <rect x="38" y="52" width="6" height="8" rx="1" />
              <rect x="48" y="50" width="12" height="12" rx="2" />
              <rect x="66" y="48" width="8" height="6" rx="1" />
              <rect x="80" y="52" width="12" height="6" rx="1" />

              <rect x="36" y="68" width="6" height="8" rx="1" />
              <rect x="46" y="72" width="8" height="6" rx="1" />
              <rect x="58" y="68" width="6" height="12" rx="1" />
              <rect x="70" y="70" width="10" height="6" rx="1" />
              <rect x="86" y="68" width="6" height="8" rx="1" />
              <rect x="38" y="84" width="10" height="8" rx="1" />
              <rect x="52" y="86" width="8" height="6" rx="1" />
              <rect x="66" y="82" width="12" height="10" rx="1" />
              <rect x="82" y="84" width="10" height="8" rx="1" />

              {/* Central brand pip */}
              <circle cx="50" cy="50" r="4.5" fill="#f5c518" />
            </svg>
          </div>

          <div className="mt-3 flex items-center gap-1.5 text-[11px] font-medium text-emerald-700">
            <ShieldCheck size={13} />
            <span>WeChat-Style Privacy: Phone number hidden</span>
          </div>

          <p className="mt-1 text-[11px] text-ink/45">
            Friends scan this QR code with their camera or evrry app to add you directly.
          </p>

          <div className="mt-4 flex w-full gap-2">
            <button
              onClick={handleShare}
              className="flex flex-1 items-center justify-center gap-1.5 rounded-xl border border-black/10 py-2.5 text-xs font-semibold text-ink hover:bg-black/5 transition"
            >
              <Share2 size={13} />
              {copied ? "Copied Link!" : "Share Link"}
            </button>
            <button
              onClick={() => alert("QR code saved to your device gallery (demo).")}
              className="flex flex-1 items-center justify-center gap-1.5 rounded-xl bg-ink py-2.5 text-xs font-semibold text-white hover:bg-ink/90 transition"
            >
              <Download size={13} />
              Save Image
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
