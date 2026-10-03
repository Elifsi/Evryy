"use client";

import { useEffect, useRef, useState } from "react";
import { motion } from "framer-motion";
import clsx from "clsx";
import { OrbPhase } from "@/components/VoiceOrb";

interface VoiceWaveformPillProps {
  phase: OrbPhase;
  muted: boolean;
  onTap: () => void;
  micStream?: MediaStream | null;
  speakEnergyToken?: number;
  errorFlavor?: boolean;
}

const BAR_COUNT = 5;
const BASE_HEIGHTS = [12, 22, 32, 22, 12]; // Default resting bar heights (in px)

export default function VoiceWaveformPill({
  phase,
  muted,
  onTap,
  micStream,
  speakEnergyToken,
  errorFlavor,
}: VoiceWaveformPillProps) {
  const [barHeights, setBarHeights] = useState<number[]>(BASE_HEIGHTS);
  const rafRef = useRef<number | null>(null);
  const energyRef = useRef(0);
  const lastTokenRef = useRef<number | undefined>(undefined);

  // Listening — real mic audio amplitude via AnalyserNode
  useEffect(() => {
    if (phase !== "listening" || !micStream || muted) {
      if (phase !== "speaking" && phase !== "processing") {
        setBarHeights(BASE_HEIGHTS);
      }
      return;
    }

    let audioCtx: AudioContext | null = null;
    let source: MediaStreamAudioSourceNode | null = null;
    let cancelled = false;
    let emaRms = 0;

    try {
      const AudioCtxCtor =
        window.AudioContext ?? (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
      if (!AudioCtxCtor) return;
      audioCtx = new AudioCtxCtor();
      source = audioCtx.createMediaStreamSource(micStream);
      const analyser = audioCtx.createAnalyser();
      analyser.fftSize = 64;
      source.connect(analyser);
      const data = new Uint8Array(analyser.frequencyBinCount);

      const tick = () => {
        if (cancelled) return;
        analyser.getByteFrequencyData(data);

        // Average overall energy
        let sum = 0;
        for (let i = 0; i < data.length; i++) {
          sum += data[i];
        }
        const avg = sum / (data.length * 255); // 0 to 1
        emaRms = emaRms * 0.65 + avg * 0.35;

        // Drive individual bars with frequency bins and slight offsets
        const next = BASE_HEIGHTS.map((base, idx) => {
          const binVal = (data[idx * 2 + 1] ?? 0) / 255;
          const dynamicBoost = binVal * 24 + emaRms * 20;
          return Math.min(38, Math.max(8, base * 0.6 + dynamicBoost));
        });

        setBarHeights(next);
        rafRef.current = requestAnimationFrame(tick);
      };
      tick();
    } catch {
      // Audio visualization fallback
      setBarHeights(BASE_HEIGHTS);
    }

    return () => {
      cancelled = true;
      if (rafRef.current) cancelAnimationFrame(rafRef.current);
      source?.disconnect();
      void audioCtx?.close().catch(() => {});
    };
  }, [phase, micStream, muted]);

  // Speaking — driven by TTS boundaries & energy decay
  useEffect(() => {
    if (phase !== "speaking") return;
    let cancelled = false;
    let step = 0;

    const tick = () => {
      if (cancelled) return;
      step += 0.18;
      energyRef.current *= 0.92;

      const currentEnergy = Math.max(energyRef.current, 0.2);
      const next = BASE_HEIGHTS.map((base, idx) => {
        const wave = Math.sin(step + idx * 0.9) * 8;
        return Math.min(38, Math.max(8, base * 0.6 + wave + currentEnergy * 18));
      });

      setBarHeights(next);
      rafRef.current = requestAnimationFrame(tick);
    };
    tick();

    return () => {
      cancelled = true;
      if (rafRef.current) cancelAnimationFrame(rafRef.current);
    };
  }, [phase]);

  // Bump energy on each spoken word boundary
  useEffect(() => {
    if (phase !== "speaking" || speakEnergyToken === undefined) return;
    if (speakEnergyToken === lastTokenRef.current) return;
    lastTokenRef.current = speakEnergyToken;
    energyRef.current = Math.min(energyRef.current + 0.35 + Math.random() * 0.15, 0.85);
  }, [phase, speakEnergyToken]);

  // Processing / Thinking wave animation
  useEffect(() => {
    if (phase !== "processing") return;
    let cancelled = false;
    let step = 0;

    const tick = () => {
      if (cancelled) return;
      step += 0.14;
      const next = BASE_HEIGHTS.map((base, idx) => {
        const wave = Math.sin(step + idx * 0.7) * 10;
        return Math.min(34, Math.max(8, base * 0.7 + wave));
      });
      setBarHeights(next);
      rafRef.current = requestAnimationFrame(tick);
    };
    tick();

    return () => {
      cancelled = true;
      if (rafRef.current) cancelAnimationFrame(rafRef.current);
    };
  }, [phase]);

  return (
    <motion.button
      type="button"
      onClick={onTap}
      whileTap={{ scale: 0.96 }}
      className={clsx(
        "relative flex h-13 min-w-[134px] items-center justify-center gap-1.5 rounded-full px-7 transition-all duration-300",
        "bg-white/95 backdrop-blur-md border",
        errorFlavor
          ? "border-red-200 shadow-[0_4px_20px_rgba(239,68,68,0.18)]"
          : "border-blue-100 shadow-[0_4px_24px_rgba(0,94,255,0.14)] hover:shadow-[0_6px_28px_rgba(0,94,255,0.22)]",
        muted && "opacity-60"
      )}
      title={phase === "speaking" ? "Tap to interrupt" : "Tap to speak"}
    >
      {/* Subtle background ambient pulse inside pill */}
      <span
        className={clsx(
          "pointer-events-none absolute inset-0 rounded-full transition-opacity duration-500",
          phase === "listening" || phase === "speaking"
            ? "bg-gradient-to-r from-blue-50/80 via-white to-blue-50/80 opacity-100"
            : "opacity-0"
        )}
      />

      {/* Dynamic Animated Bars */}
      <div className="relative flex items-center justify-center gap-1.5 h-10">
        {barHeights.map((h, i) => (
          <span
            key={i}
            className={clsx(
              "w-[3.5px] rounded-full transition-[height] duration-75 ease-out",
              errorFlavor
                ? "bg-red-500"
                : muted
                  ? "bg-slate-300"
                  : "bg-gradient-to-t from-[#005EFF] to-[#2F82F6]"
            )}
            style={{
              height: `${Math.round(h)}px`,
            }}
          />
        ))}
      </div>
    </motion.button>
  );
}
