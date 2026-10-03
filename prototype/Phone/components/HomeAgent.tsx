"use client";

import { useEffect, useRef, useState } from "react";
import Link from "next/link";
import { motion, AnimatePresence } from "framer-motion";
import {
  Mic,
  MicOff,
  Send,
  RotateCcw,
  ShoppingBag,
  Sparkles,
  Plus,
  Upload,
  X,
  Share2,
  SlidersHorizontal,
} from "lucide-react";
import clsx from "clsx";
import { useAppStore } from "@/lib/store/useAppStore";
import { AiChatSSEEvent, ChatMessage } from "@/lib/types";
import { findById } from "@/lib/data/catalog";
import { todayIso } from "@/lib/dates";
import { cutSentences } from "@/lib/home/cutSentences";
import { shareOrCopyText } from "@/lib/shareOrCopy";
import { readImageFile } from "@/lib/imagePicker";
import Transcript from "@/components/home/Transcript";
import VoicePickerSheet from "@/components/home/VoicePickerSheet";
import VoiceWaveformPill from "@/components/home/VoiceWaveformPill";
import { OrbPhase } from "@/components/VoiceOrb";

function uid() {
  return Math.random().toString(36).slice(2, 10);
}

interface SpeechRecognitionLike extends EventTarget {
  continuous: boolean;
  interimResults: boolean;
  lang: string;
  start: () => void;
  stop: () => void;
  abort: () => void;
  onresult: ((e: SpeechRecognitionEventLike) => void) | null;
  onend: (() => void) | null;
  onerror: ((e: { error: string }) => void) | null;
}
interface SpeechRecognitionEventLike {
  resultIndex: number;
  results: { isFinal: boolean; [index: number]: { transcript: string } }[];
}

interface PendingImage {
  dataUrl: string;
  mimeType: string;
}

const SILENCE_MS = 700; // how long to wait after the last result before treating a turn as finished
const NO_SPEECH_TIMEOUT_MS = 15_000; // give up and return to idle if nothing at all is heard
const INTERRUPTED_FLASH_MS = 200; // matches the CSS .voice-orb-interrupt animation duration

export default function HomeAgent() {
  const chatMessages = useAppStore((s) => s.chatMessages);
  const addChatMessage = useAppStore((s) => s.addChatMessage);
  const clearChat = useAppStore((s) => s.clearChat);
  const logAudit = useAppStore((s) => s.logAudit);
  const displayName = useAppStore((s) => s.displayName);
  const cart = useAppStore((s) => s.cart);
  const setCart = useAppStore((s) => s.setCart);
  const walletBalance = useAppStore((s) => s.walletBalance);
  const placeOrderFromCart = useAppStore((s) => s.placeOrderFromCart);
  const bookHotel = useAppStore((s) => s.bookHotel);
  const personalizationEnabled = useAppStore((s) => s.personalizationEnabled);
  const memory = useAppStore((s) => s.memory);

  const [started, setStarted] = useState(chatMessages.length > 0);
  const [aiMode, setAiMode] = useState<"chat" | "assistant">("chat");
  const [showDrawer, setShowDrawer] = useState(false);
  const [phase, setPhase] = useState<OrbPhase>("idle");
  const [errorFlavor, setErrorFlavor] = useState(false);
  const [caption, setCaption] = useState("");
  const [muted, setMuted] = useState(false);
  const [showTyped, setShowTyped] = useState(false);
  const [typedValue, setTypedValue] = useState("");
  const [supported, setSupported] = useState(true);
  const [loading, setLoading] = useState(false);
  const [micStream, setMicStream] = useState<MediaStream | null>(null);
  const [pendingImage, setPendingImage] = useState<PendingImage | null>(null);
  const [speakEnergyToken, setSpeakEnergyToken] = useState(0);
  const [showInfo, setShowInfo] = useState(false);
  const [showVoicePicker, setShowVoicePicker] = useState(false);
  const [shareCopied, setShareCopied] = useState(false);
  const [voices, setVoices] = useState<SpeechSynthesisVoice[]>([]);
  const [selectedVoiceURI, setSelectedVoiceURI] = useState<string | null>(null);

  const aiModeRef = useRef<"chat" | "assistant">("chat");
  const recognitionRef = useRef<SpeechRecognitionLike | null>(null);
  const mutedRef = useRef(false);
  const scrollRef = useRef<HTMLDivElement>(null);
  const sendingRef = useRef(false);
  const micStreamRef = useRef<MediaStream | null>(null);
  const pendingImageRef = useRef<PendingImage | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  // Session-local closure set fresh by whichever startRecognition() call is
  // currently live — always called through this ref so callers elsewhere in
  // the file (handleOrbTap) never act on a stale session, the same
  // "re-check live state, don't trust the closure" pattern used in the
  // rides feature's ride-tracking effect.
  const finalizeNowRef = useRef<(() => void) | null>(null);

  const silenceTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const interruptedTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const noSpeechTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Speculative-streaming reply state (see sendTurn/handleStreamEvent).
  const streamAbortRef = useRef<AbortController | null>(null);
  const speechQueueRef = useRef<string[]>([]);
  const queueActiveRef = useRef(false); // this turn's queue is the thing currently allowed to speak
  const queuePlayingRef = useRef(false); // an utterance from the queue is in flight right now
  const streamDoneRef = useRef(false); // the server's terminal `done` event has arrived

  useEffect(() => {
    aiModeRef.current = aiMode;
  }, [aiMode]);

  useEffect(() => {
    mutedRef.current = muted;
  }, [muted]);

  useEffect(() => {
    pendingImageRef.current = pendingImage;
  }, [pendingImage]);

  useEffect(() => {
    scrollRef.current?.scrollTo({ top: scrollRef.current.scrollHeight, behavior: "smooth" });
  }, [chatMessages, loading]);

  useEffect(() => stopEverything, []);

  // Voice list loads asynchronously in most browsers (empty on first call),
  // so listen for onvoiceschanged too, not just call it once. The chosen
  // voice persists across sessions in localStorage — no need for a full
  // store field for a browser-local preference like this.
  useEffect(() => {
    if (typeof window === "undefined" || !("speechSynthesis" in window)) return;
    setSelectedVoiceURI(window.localStorage.getItem("pc-voice-uri"));
    const loadVoices = () => setVoices(window.speechSynthesis.getVoices());
    loadVoices();
    window.speechSynthesis.addEventListener("voiceschanged", loadVoices);
    return () => window.speechSynthesis.removeEventListener("voiceschanged", loadVoices);
  }, []);

  function chooseVoice(uri: string | null) {
    setSelectedVoiceURI(uri);
    if (typeof window !== "undefined") {
      if (uri) window.localStorage.setItem("pc-voice-uri", uri);
      else window.localStorage.removeItem("pc-voice-uri");
    }
  }

  function applyVoice(utter: SpeechSynthesisUtterance) {
    const voice = selectedVoiceURI ? voices.find((v) => v.voiceURI === selectedVoiceURI) : undefined;
    if (voice) utter.voice = voice;
  }

  /** A standalone preview, deliberately outside the conversation's speak()/queue machinery — just a quick sample, not a real turn. */
  function previewVoice(voice: SpeechSynthesisVoice) {
    if (typeof window === "undefined" || !("speechSynthesis" in window)) return;
    window.speechSynthesis.cancel();
    const utter = new SpeechSynthesisUtterance("Hi, this is how I sound.");
    utter.voice = voice;
    utter.rate = 1.02;
    window.speechSynthesis.speak(utter);
  }

  async function handleShareTranscript() {
    const text = chatMessages.map((m) => `${m.role === "user" ? "You" : "Concierge"}: ${m.content}`).join("\n");
    await shareOrCopyText(text, {
      title: "evrry conversation",
      onCopied: () => {
        setShareCopied(true);
        window.setTimeout(() => setShareCopied(false), 2000);
      },
    });
  }

  function clearVoiceTimers() {
    if (silenceTimerRef.current) {
      clearTimeout(silenceTimerRef.current);
      silenceTimerRef.current = null;
    }
    if (interruptedTimerRef.current) {
      clearTimeout(interruptedTimerRef.current);
      interruptedTimerRef.current = null;
    }
    if (noSpeechTimerRef.current) {
      clearTimeout(noSpeechTimerRef.current);
      noSpeechTimerRef.current = null;
    }
  }

  // The one place phase actually changes — wraps setPhase so the
  // "interrupted" flash always gets a real, guarded auto-advance instead of
  // leaving a stray timeout that could later clobber whatever phase
  // something else legitimately set in the meantime.
  function transitionPhase(next: OrbPhase) {
    if (interruptedTimerRef.current) {
      clearTimeout(interruptedTimerRef.current);
      interruptedTimerRef.current = null;
    }
    setPhase(next);
    if (next === "interrupted") {
      interruptedTimerRef.current = setTimeout(() => {
        interruptedTimerRef.current = null;
        setPhase("listening");
      }, INTERRUPTED_FLASH_MS);
    }
  }

  function stopEverything() {
    recognitionRef.current?.abort();
    recognitionRef.current = null;
    // Close the queue gate BEFORE cancelling — cancel()'s onerror can fire
    // synchronously and the queue runner's onerror only stops advancing
    // when it sees queueActiveRef already false (see runQueue).
    queueActiveRef.current = false;
    queuePlayingRef.current = false;
    if (typeof window !== "undefined" && "speechSynthesis" in window) window.speechSynthesis.cancel();
    micStreamRef.current?.getTracks().forEach((t) => t.stop());
    micStreamRef.current = null;
    setMicStream(null);
    streamAbortRef.current?.abort();
    streamAbortRef.current = null;
    clearVoiceTimers();
  }

  // Separate from SpeechRecognition's own internal mic capture — purely so
  // the orb can react to real audio amplitude while listening. Best-effort:
  // if it fails, the orb just falls back to its non-reactive animation.
  // These constraints only affect THIS stream — SpeechRecognition's own
  // internal capture is opaque to JS and can't be given them; that's a real
  // Web Speech API ceiling, not a bug (see the plan's echo-mitigation note).
  async function ensureMicStream() {
    if (micStreamRef.current?.active) return;
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        audio: { echoCancellation: true, noiseSuppression: true, autoGainControl: true },
      });
      micStreamRef.current = stream;
      setMicStream(stream);
    } catch {
      // no visualization stream — the voice pipeline itself doesn't depend on this
    }
  }

  function resumeAfterSpeaking() {
    if (mutedRef.current) {
      stopEverything();
      transitionPhase("idle");
      return;
    }
    // The mic is never left running while the AI is speaking (see the big
    // comment in speak() about self-hearing), so there's never an existing
    // session to promote here — always a fresh, clean listen.
    startRecognition();
  }

  function startRecognition() {
    if (typeof window === "undefined") return;
    const Ctor =
      (window as unknown as { SpeechRecognition?: new () => SpeechRecognitionLike }).SpeechRecognition ??
      (window as unknown as { webkitSpeechRecognition?: new () => SpeechRecognitionLike }).webkitSpeechRecognition;

    if (!Ctor) {
      setSupported(false);
      setShowTyped(true);
      transitionPhase("idle");
      return;
    }

    void ensureMicStream();

    const rec = new Ctor();
    rec.continuous = true;
    rec.interimResults = true;
    rec.lang = "en-US";

    // Local to this call — a stale timer/callback from an old session can
    // never act on the wrong recognizer, by construction, since a fresh
    // startRecognition() call always gets its own fresh locals.
    let finalTranscript = "";
    let lastInterim = "";

    function armNoSpeechTimeout() {
      if (noSpeechTimerRef.current) clearTimeout(noSpeechTimerRef.current);
      noSpeechTimerRef.current = setTimeout(() => {
        if (recognitionRef.current !== rec) return;
        if (finalTranscript.trim() || lastInterim.trim()) return; // something was said, not truly silent
        rec.stop();
      }, NO_SPEECH_TIMEOUT_MS);
    }

    function scheduleSilenceFinalize() {
      if (silenceTimerRef.current) clearTimeout(silenceTimerRef.current);
      silenceTimerRef.current = setTimeout(finalizeAndSend, SILENCE_MS);
    }

    function finalizeAndSend() {
      if (recognitionRef.current !== rec) return; // this session is no longer live
      silenceTimerRef.current = null;
      const text = (finalTranscript || lastInterim).trim();
      if (text) {
        rec.stop();
        void sendTurn(text);
      }
    }
    finalizeNowRef.current = finalizeAndSend;

    rec.onresult = (e) => {
      let interim = "";
      let finalChunk = "";
      for (let i = e.resultIndex; i < e.results.length; i++) {
        const r = e.results[i];
        if (r.isFinal) finalChunk += r[0].transcript;
        else interim += r[0].transcript;
      }
      lastInterim = interim;
      if (finalChunk.trim()) finalTranscript += (finalTranscript ? " " : "") + finalChunk.trim();

      setCaption(finalTranscript || interim);
      armNoSpeechTimeout();
      scheduleSilenceFinalize();
    };
    rec.onerror = (e) => {
      if (e.error === "not-allowed" || e.error === "service-not-allowed") {
        transitionPhase("denied");
        setShowTyped(true);
      } else {
        transitionPhase("idle");
      }
      if (recognitionRef.current === rec) clearVoiceTimers();
    };
    rec.onend = () => {
      if (recognitionRef.current === rec) {
        recognitionRef.current = null;
        clearVoiceTimers();
      }
    };

    recognitionRef.current = rec;
    setCaption("");
    transitionPhase("listening");
    armNoSpeechTimeout();
    try {
      rec.start();
    } catch {
      // recognition already running — ignore
    }
  }

  /** Single-utterance TTS — the greeting, and any authoritative (non-speculative) reply. */
  function speak(text: string, opts?: { errorFlavor?: boolean }) {
    setErrorFlavor(Boolean(opts?.errorFlavor));
    transitionPhase("speaking");
    setCaption(text);
    setSpeakEnergyToken((t) => t + 1);

    const canSpeak = typeof window !== "undefined" && "speechSynthesis" in window;
    if (!canSpeak) {
      if (opts?.errorFlavor) {
        // No TTS AND the thing we wanted to say was an apology — genuinely
        // stuck, not just "briefly speaking an error," so this really is
        // the terminal error phase rather than a same-frame tint.
        transitionPhase("error");
        return;
      }
      window.setTimeout(resumeAfterSpeaking, 700);
      return;
    }
    window.speechSynthesis.cancel();
    const utter = new SpeechSynthesisUtterance(text);
    utter.rate = 1.02;
    applyVoice(utter);
    utter.onboundary = () => setSpeakEnergyToken((t) => t + 1);
    utter.onend = () => {
      setErrorFlavor(false);
      resumeAfterSpeaking();
    };
    utter.onerror = () => {
      setErrorFlavor(false);
      resumeAfterSpeaking();
    };
    // Deliberately NOT listening while this plays: the mic and the speaker
    // are the same physical hardware, and without real acoustic echo
    // cancellation (a genuine Web Speech API ceiling — see ensureMicStream's
    // comment) the recognizer would hear the AI's own voice and transcribe
    // it as a new user turn, which then gets a new reply, which gets heard
    // again — a self-sustaining loop that also starves out anything the
    // user actually says. Interruption is tap-only (see handleOrbTap);
    // listening always starts fresh only once speech has genuinely stopped.
    window.speechSynthesis.speak(utter);
  }

  /** Runs the sentence queue for a speculatively-streamed reply — chained utterance playback, gated on queueActiveRef. */
  function runQueue() {
    if (!queueActiveRef.current || queuePlayingRef.current) return;
    const next = speechQueueRef.current.shift();
    if (!next) return; // caught up — wait for more deltas or `done`
    queuePlayingRef.current = true;
    const utter = new SpeechSynthesisUtterance(next);
    utter.rate = 1.02;
    applyVoice(utter);
    utter.onboundary = () => setSpeakEnergyToken((t) => t + 1);
    const advance = () => {
      queuePlayingRef.current = false;
      if (!queueActiveRef.current) return; // retracted/barged-in — commit logic already handled the transition
      if (speechQueueRef.current.length > 0) {
        runQueue();
      } else if (streamDoneRef.current) {
        queueActiveRef.current = false;
        resumeAfterSpeaking();
      }
      // else: caught up but the stream isn't done yet — the next speech_delta/done will call runQueue again
    };
    utter.onend = advance;
    // speechSynthesis.cancel() (barge-in) fires onerror, not onend — if a
    // barge-in already flipped queueActiveRef false, do nothing here (its
    // own commit logic owns the transition); otherwise treat it like onend.
    utter.onerror = () => {
      if (queueActiveRef.current) advance();
      else queuePlayingRef.current = false;
    };
    window.speechSynthesis.speak(utter);
  }

  function beginStreamingSpeech() {
    queueActiveRef.current = true;
    transitionPhase("speaking");
    setErrorFlavor(false);
    setLoading(false);
    // Same reasoning as speak() — no passive listening during playback, to
    // avoid the mic hearing the speaker and looping on itself.
  }

  function handleImageButton() {
    fileInputRef.current?.click();
  }

  async function handleImageSelected(e: React.ChangeEvent<HTMLInputElement>) {
    const picked = await readImageFile(e);
    if (picked) setPendingImage(picked);
  }

  async function sendTurn(text: string) {
    const trimmed = text.trim();
    const image = pendingImageRef.current;
    if (!trimmed && !image) {
      startRecognition();
      return;
    }
    if (sendingRef.current) return; // a turn is already in flight — don't race it (stale cart/wallet reads)
    sendingRef.current = true;
    setStarted(true);
    const userMsg: ChatMessage = {
      id: uid(),
      role: "user",
      content: trimmed || "(sent an image)",
      createdAt: Date.now(),
      imageDataUrl: image?.dataUrl,
    };
    const history = [...useAppStore.getState().chatMessages, userMsg];
    addChatMessage(userMsg);
    setPendingImage(null);
    transitionPhase("processing");
    setLoading(true);
    setCaption("");

    logAudit({
      actorType: "USER",
      action: "conversation_turn",
      resourceType: "conversation",
      policyDecision: "allowed",
      detail: trimmed.slice(0, 140),
    });

    streamAbortRef.current?.abort();
    const controller = new AbortController();
    streamAbortRef.current = controller;
    queueActiveRef.current = false;
    queuePlayingRef.current = false;
    streamDoneRef.current = false;
    speechQueueRef.current = [];
    let sentenceBuffer = "";
    let streamingStarted = false;

    function pushDeltaText(delta: string) {
      sentenceBuffer += delta;
      const { sentences, rest } = cutSentences(sentenceBuffer);
      sentenceBuffer = rest;
      if (sentences.length === 0) return;
      if (aiModeRef.current === "assistant") {
        if (!streamingStarted) {
          streamingStarted = true;
          beginStreamingSpeech();
        }
        speechQueueRef.current.push(...sentences);
        setCaption((c) => (c ? `${c} ${sentences.join(" ")}` : sentences.join(" ")));
        runQueue();
      }
    }

    function handleRetract() {
      queueActiveRef.current = false;
      queuePlayingRef.current = false;
      if (typeof window !== "undefined" && "speechSynthesis" in window) window.speechSynthesis.cancel();
      speechQueueRef.current = [];
      sentenceBuffer = "";
      streamingStarted = false;
      setCaption("");
      transitionPhase("processing");
      setLoading(true);
    }

    function handleDone(evt: Extract<AiChatSSEEvent, { type: "done" }>) {
      streamDoneRef.current = true;
      const leftover = sentenceBuffer.trim();
      sentenceBuffer = "";
      if (leftover && aiModeRef.current === "assistant") {
        if (!streamingStarted) {
          streamingStarted = true;
          beginStreamingSpeech();
        }
        speechQueueRef.current.push(leftover);
        setCaption((c) => (c ? `${c} ${leftover}` : leftover));
      }

      addChatMessage({
        id: uid(),
        role: "assistant",
        content: evt.reply,
        itemIds: evt.itemIds ?? [],
        mode: evt.mode as ChatMessage["mode"],
        createdAt: Date.now(),
      });
      logAudit({
        actorType: "AI_AGENT",
        action: "recommendation_presented",
        resourceType: "conversation",
        policyDecision: "allowed",
        detail: `${(evt.itemIds ?? []).length} item(s) presented via ${evt.mode} mode.`,
      });

      if (Array.isArray(evt.cart)) setCart(evt.cart);

      if (evt.orderResult?.ok) {
        const commit = placeOrderFromCart("wallet", { placedBy: "AI_AGENT" });
        if (!commit.ok) {
          addChatMessage({
            id: uid(),
            role: "assistant",
            content: "Sorry — something changed and I couldn't finish placing that order. Please try again.",
            createdAt: Date.now(),
          });
        }
      }

      if (evt.hotelBooking?.ok) {
        const hb = evt.hotelBooking as { item_id: string; check_in: string; check_out: string; guests: number };
        const commit = bookHotel(
          { itemId: hb.item_id, checkIn: hb.check_in, checkOut: hb.check_out, guests: hb.guests, source: "wallet" },
          { placedBy: "AI_AGENT" }
        );
        if (!commit.ok) {
          addChatMessage({
            id: uid(),
            role: "assistant",
            content: "Sorry — something changed and I couldn't finish that booking. Please try again.",
            createdAt: Date.now(),
          });
        }
      }

      if (aiModeRef.current === "assistant") {
        if (evt.spoken) {
          if (leftover) runQueue();
          if (speechQueueRef.current.length === 0 && !queuePlayingRef.current) {
            queueActiveRef.current = false;
            resumeAfterSpeaking();
          }
        } else {
          speak(evt.reply.replace(/\*\*/g, ""));
        }
      } else {
        transitionPhase("idle");
      }
    }

    try {
      const res = await fetch("/api/ai/chat", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          messages: history,
          context: {
            walletBalance: useAppStore.getState().walletBalance,
            cart: useAppStore.getState().cart,
            displayName,
            today: todayIso(),
          },
          image: image ? { dataUrl: image.dataUrl, mimeType: image.mimeType } : undefined,
        }),
        signal: controller.signal,
      });
      if (!res.body) throw new Error("empty response body");

      const reader = res.body.getReader();
      const decoder = new TextDecoder();
      let buf = "";
      while (true) {
        const { value, done } = await reader.read();
        if (done) break;
        buf += decoder.decode(value, { stream: true });
        const chunks = buf.split("\n\n");
        buf = chunks.pop() ?? "";
        for (const chunk of chunks) {
          const dataLine = chunk.split("\n").find((l) => l.startsWith("data:"));
          if (!dataLine) continue;
          let evt: AiChatSSEEvent;
          try {
            evt = JSON.parse(dataLine.slice(5).trim()) as AiChatSSEEvent;
          } catch {
            continue; // malformed chunk — skip
          }
          if (evt.type === "speech_delta") pushDeltaText(evt.text);
          else if (evt.type === "retract") handleRetract();
          else if (evt.type === "done") handleDone(evt);
        }
      }
    } catch (err) {
      if ((err as { name?: string })?.name === "AbortError") {
        // Barge-in already aborted this turn and handled the phase/queue
        // transition itself — nothing more to do here.
      } else {
        speak("Sorry, something went wrong reaching the concierge.", { errorFlavor: true });
      }
    } finally {
      setLoading(false);
      sendingRef.current = false;
    }
  }

  function startSession() {
    setStarted(true);
    const greeting = `Hi ${displayName || "Rahul"}, what's on your mind?`;
    addChatMessage({ id: uid(), role: "assistant", content: greeting, createdAt: Date.now() });
    if (aiModeRef.current === "assistant") {
      speak(greeting);
    }
  }

  function startVoiceAssistant() {
    setAiMode("assistant");
    setStarted(true);
    if (phase === "idle" || phase === "denied" || phase === "error") {
      startRecognition();
    }
  }

  function closeAssistant() {
    stopEverything();
    setPhase("idle");
    setCaption("");
    setAiMode("chat");
  }

  function handleOrbTap() {
    if (!started) {
      startVoiceAssistant();
    } else if (phase === "listening") {
      finalizeNowRef.current?.();
    } else if (phase === "idle" || phase === "denied" || phase === "error") {
      startRecognition();
    } else if (phase === "speaking" || phase === "interrupted") {
      queueActiveRef.current = false;
      queuePlayingRef.current = false;
      streamAbortRef.current?.abort();
      transitionPhase("interrupted");
      window.speechSynthesis?.cancel();
    }
  }

  function toggleMute() {
    setMuted((m) => {
      const next = !m;
      if (next) {
        recognitionRef.current?.abort();
        queueActiveRef.current = false;
        queuePlayingRef.current = false;
        streamAbortRef.current?.abort();
        if (typeof window !== "undefined" && "speechSynthesis" in window) window.speechSynthesis.cancel();
        clearVoiceTimers();
        transitionPhase("idle");
      } else if (started && phase === "idle") {
        startRecognition();
      }
      return next;
    });
  }

  function resetConversation() {
    stopEverything();
    clearChat();
    setStarted(false);
    transitionPhase("idle");
    setCaption("");
    setShowTyped(false);
    setPendingImage(null);
  }

  const cartTotal = cart.reduce((sum, c) => sum + (findById(c.itemId)?.price ?? 0) * c.qty, 0);
  const cartCount = cart.reduce((n, c) => n + c.qty, 0);

  const hint =
    phase === "listening"
      ? "Listening…"
      : phase === "processing"
        ? "Thinking…"
        : phase === "interrupted"
          ? "Go ahead…"
          : phase === "speaking"
            ? ""
            : phase === "error"
              ? "Something went wrong — tap to try again."
              : phase === "denied"
                ? "Microphone access was denied — type below instead."
                : !supported
                  ? "Voice isn't supported in this browser — type below instead."
                  : "Tap the orb to talk";

  return (
    <>
      <div className="fixed inset-x-0 top-0 bottom-20 z-10 mx-auto flex max-w-md flex-col overflow-hidden bg-gradient-to-b from-[#F9FBFF] via-white to-[#E8F1FF]">
        {/* Soft background ambient gradient glows */}
        <div className="pointer-events-none absolute -top-24 -left-24 h-72 w-72 rounded-full bg-blue-100/40 blur-3xl" />
        <div className="pointer-events-none absolute -bottom-24 -right-24 h-80 w-80 rounded-full bg-blue-200/40 blur-3xl" />

        {/* Hidden file input for media/image attachment */}
        <input ref={fileInputRef} type="file" accept="image/*" className="hidden" onChange={handleImageSelected} />

        {/* Top Bar matching chat.png and Assistant.png */}
        <div className="relative z-10 flex items-center justify-between px-5 pt-4 pb-2">
          <button
            type="button"
            onClick={() => setShowDrawer(true)}
            className="flex h-10 w-10 items-center justify-center rounded-full text-[#0B172A] hover:bg-black/5 active:scale-95 transition"
            title="Menu"
          >
            <div className="flex flex-col justify-center gap-1.5 w-5">
              <span className="h-[2px] w-5 bg-[#0B172A] rounded-full" />
              <span className="h-[2px] w-5 bg-[#0B172A] rounded-full" />
            </div>
          </button>

          <Link
            href="/profile"
            className="relative flex h-9 w-9 shrink-0 items-center justify-center overflow-hidden rounded-full border border-slate-200 shadow-sm active:scale-95 transition"
            title="Profile"
          >
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src="/avatar.png"
              alt={displayName || "Rahul"}
              className="h-full w-full object-cover"
            />
          </Link>
        </div>

        {/* MODE 1: CHAT SCREEN (chat.png) */}
        {aiMode === "chat" && (
          <div className="relative z-10 flex flex-1 flex-col overflow-hidden">
            {chatMessages.length === 0 ? (
              <div className="flex flex-1 flex-col items-center justify-center px-6 -mt-10">
                <h1 className="text-center text-[27px] font-normal tracking-tight text-[#0B172A] leading-[1.3] whitespace-pre-line">
                  Hi {displayName || "Rahul"}, what&apos;s on{"\n"}your mind?
                </h1>
              </div>
            ) : (
              <div className="flex flex-1 flex-col overflow-hidden">
                <Transcript scrollRef={scrollRef} chatMessages={chatMessages} loading={loading} />

                {cartCount > 0 && (
                  <div className="relative z-10 mx-4 mb-2 flex items-center justify-between rounded-full bg-white px-4 py-2 text-xs text-[#0B172A] shadow-sm border border-slate-100">
                    <span className="inline-flex items-center gap-1.5 text-slate-600">
                      <ShoppingBag size={13} className="text-[#005EFF]" /> {cartCount} item{cartCount > 1 ? "s" : ""} in cart
                    </span>
                    <span className="font-semibold text-[#005EFF]">₹{cartTotal.toLocaleString("en-IN")}</span>
                  </div>
                )}
              </div>
            )}

            {/* Floating Capsule Composer at bottom (chat.png) */}
            <div className="relative z-10 px-4 pb-4 pt-1">
              {pendingImage && (
                <div className="mb-2 flex items-center gap-2 rounded-2xl bg-white px-3 py-2 shadow-sm border border-slate-100">
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img src={pendingImage.dataUrl} alt="Attached" className="h-10 w-10 rounded-lg object-cover" />
                  <span className="flex-1 text-xs text-slate-600 truncate">Image attached</span>
                  <button
                    onClick={() => setPendingImage(null)}
                    className="flex h-6 w-6 items-center justify-center rounded-full bg-slate-100 text-slate-500 hover:bg-slate-200"
                  >
                    <X size={12} />
                  </button>
                </div>
              )}

              <form
                onSubmit={(e) => {
                  e.preventDefault();
                  const v = typedValue.trim();
                  if (!v && !pendingImage) return;
                  setTypedValue("");
                  void sendTurn(v);
                }}
                className="flex items-center gap-2 rounded-full bg-white px-2 py-2 shadow-[0_6px_24px_rgba(0,0,0,0.06)] border border-slate-100"
              >
                <button
                  type="button"
                  onClick={handleImageButton}
                  className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full text-slate-600 hover:bg-slate-100 transition active:scale-95"
                  title="Attach image"
                >
                  <Plus size={20} strokeWidth={2.2} />
                </button>

                <input
                  value={typedValue}
                  onChange={(e) => setTypedValue(e.target.value)}
                  placeholder="Ask Evrry..."
                  disabled={loading}
                  className="flex-1 bg-transparent px-1 text-base text-[#0B172A] placeholder:text-slate-400 outline-none font-normal"
                />

                {typedValue.trim() ? (
                  <button
                    type="submit"
                    disabled={loading}
                    className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-[#005EFF] text-white shadow-sm hover:bg-blue-600 transition active:scale-95 disabled:opacity-50"
                    title="Send"
                  >
                    <Send size={16} strokeWidth={2.2} />
                  </button>
                ) : (
                  <>
                    <button
                      type="button"
                      onClick={startVoiceAssistant}
                      className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full text-slate-600 hover:bg-slate-100 transition active:scale-95"
                      title="Voice input"
                    >
                      <Mic size={20} strokeWidth={2} />
                    </button>

                    <button
                      type="button"
                      onClick={startVoiceAssistant}
                      className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-[#E8F1FF] text-[#005EFF] hover:bg-blue-100 transition active:scale-95"
                      title="Open Voice Assistant"
                    >
                      <div className="flex items-center justify-center gap-[2.5px] h-4">
                        <span className="w-[3px] h-2.5 bg-[#005EFF] rounded-full" />
                        <span className="w-[3px] h-4 bg-[#005EFF] rounded-full" />
                        <span className="w-[3px] h-2 bg-[#005EFF] rounded-full" />
                        <span className="w-[3px] h-3.5 bg-[#005EFF] rounded-full" />
                      </div>
                    </button>
                  </>
                )}
              </form>
            </div>
          </div>
        )}

        {/* MODE 2: VOICE ASSISTANT SCREEN (Assistant.png) */}
        {aiMode === "assistant" && (
          <div className="relative z-10 flex flex-1 flex-col overflow-hidden">
            {/* Center Hero with Live Caption */}
            <div className="flex flex-1 flex-col items-center justify-center px-8 text-center -mt-8">
              <h1 className="text-[26px] font-normal tracking-tight text-[#0B172A] leading-[1.35] max-w-sm whitespace-pre-line">
                {caption || `Hi ${displayName || "Rahul"}, what's on\nyour mind?`}
              </h1>
              <p className="mt-3 text-xs font-medium text-slate-400">
                {phase === "listening" && "Listening…"}
                {phase === "processing" && "Thinking…"}
                {phase === "speaking" && "Speaking…"}
                {phase === "idle" && "Tap wave to talk"}
                {phase === "error" && "Something went wrong — tap to retry"}
                {phase === "denied" && "Microphone access denied"}
              </p>
            </div>

            {/* Floating Action Controls Row (Assistant.png) - Camera icon explicitly excluded */}
            <div className="relative z-10 px-6 pb-6 pt-2">
              {pendingImage && (
                <div className="mb-3 mx-auto flex max-w-xs items-center gap-2 rounded-2xl bg-white px-3 py-2 shadow-sm border border-slate-100">
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img src={pendingImage.dataUrl} alt="Attached" className="h-10 w-10 rounded-lg object-cover" />
                  <span className="flex-1 text-xs text-slate-600 truncate">Image attached</span>
                  <button
                    onClick={() => setPendingImage(null)}
                    className="flex h-6 w-6 items-center justify-center rounded-full bg-slate-100 text-slate-500 hover:bg-slate-200"
                  >
                    <X size={12} />
                  </button>
                </div>
              )}

              <div className="flex items-center justify-center gap-3">
                {/* 1. Upload Button (NO camera button!) */}
                <button
                  type="button"
                  onClick={handleImageButton}
                  className="flex h-12 w-12 shrink-0 items-center justify-center rounded-full bg-white shadow-md border border-slate-100 text-slate-700 hover:bg-slate-50 active:scale-95 transition"
                  title="Upload image / document"
                >
                  <Upload size={20} strokeWidth={2} />
                </button>

                {/* 2. Center Voice Visualizer Waveform Pill */}
                <VoiceWaveformPill
                  phase={phase}
                  muted={muted}
                  onTap={handleOrbTap}
                  micStream={micStream}
                  speakEnergyToken={speakEnergyToken}
                  errorFlavor={errorFlavor}
                />

                {/* 3. Mic Mute/Unmute Button */}
                <button
                  type="button"
                  onClick={toggleMute}
                  className={clsx(
                    "flex h-12 w-12 shrink-0 items-center justify-center rounded-full shadow-md border transition active:scale-95",
                    muted
                      ? "bg-slate-200 border-slate-300 text-slate-500"
                      : "bg-white border-slate-100 text-slate-700 hover:bg-slate-50"
                  )}
                  title={muted ? "Unmute" : "Mute"}
                >
                  {muted ? <MicOff size={20} strokeWidth={2} /> : <Mic size={20} strokeWidth={2} />}
                </button>

                {/* 4. Close / Dismiss Button (Returns to Chat mode) */}
                <button
                  type="button"
                  onClick={closeAssistant}
                  className="flex h-12 w-12 shrink-0 items-center justify-center rounded-full bg-white shadow-md border border-slate-100 text-slate-700 hover:bg-slate-50 active:scale-95 transition"
                  title="Exit voice assistant"
                >
                  <X size={20} strokeWidth={2} />
                </button>
              </div>
            </div>
          </div>
        )}
      </div>

      {/* Hamburger Drawer / Info Sheet */}
      {showDrawer && (
        <div className="fixed inset-0 z-40 flex items-end bg-black/40 backdrop-blur-sm" onClick={() => setShowDrawer(false)}>
          <div
            className="mx-auto w-full max-w-md rounded-t-3xl bg-white p-6 pb-8 text-[#0B172A] shadow-2xl border-t border-slate-100"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="flex items-center justify-between pb-3 border-b border-slate-100">
              <div>
                <p className="text-base font-semibold text-[#0B172A]">evrry Assistant</p>
                <p className="text-xs text-slate-400">Everything. One Place.</p>
              </div>
              <button
                onClick={() => setShowDrawer(false)}
                className="flex h-8 w-8 items-center justify-center rounded-full text-slate-400 hover:bg-slate-100"
              >
                <X size={16} />
              </button>
            </div>

            <div className="mt-4 space-y-2">
              <button
                onClick={() => {
                  resetConversation();
                  setShowDrawer(false);
                }}
                className="flex w-full items-center gap-3 rounded-2xl bg-slate-50 px-4 py-3 text-sm font-medium text-slate-700 hover:bg-slate-100 transition"
              >
                <RotateCcw size={16} className="text-[#005EFF]" />
                <span>New conversation</span>
              </button>

              <button
                onClick={() => {
                  setShowVoicePicker(true);
                  setShowDrawer(false);
                }}
                className="flex w-full items-center gap-3 rounded-2xl bg-slate-50 px-4 py-3 text-sm font-medium text-slate-700 hover:bg-slate-100 transition"
              >
                <SlidersHorizontal size={16} className="text-[#005EFF]" />
                <span>Change voice</span>
              </button>

              <button
                onClick={() => {
                  handleShareTranscript();
                  setShowDrawer(false);
                }}
                className="flex w-full items-center gap-3 rounded-2xl bg-slate-50 px-4 py-3 text-sm font-medium text-slate-700 hover:bg-slate-100 transition"
              >
                <Share2 size={16} className="text-[#005EFF]" />
                <span>Share conversation</span>
              </button>
            </div>

            <div className="mt-5 rounded-2xl bg-blue-50/60 p-4 text-xs text-slate-600 border border-blue-100/50">
              <p className="font-semibold text-slate-800 mb-1">Session status</p>
              <p>Personalization: {personalizationEnabled ? "On" : "Off"}</p>
              <p>Remembered facts: {memory.length}</p>
              <p>Messages this session: {chatMessages.length}</p>
              {!supported && (
                <p className="mt-1 text-amber-600">Voice input isn&apos;t supported in this browser.</p>
              )}
            </div>
          </div>
        </div>
      )}

      {showVoicePicker && (
        <VoicePickerSheet
          voices={voices}
          selectedVoiceURI={selectedVoiceURI}
          onChoose={chooseVoice}
          onPreview={previewVoice}
          onClose={() => setShowVoicePicker(false)}
        />
      )}

      {shareCopied && (
        <div className="pointer-events-none fixed inset-x-0 top-16 z-50 flex justify-center">
          <div className="rounded-full bg-white/90 px-4 py-2 text-xs font-semibold text-[#0B172A] shadow-lg border border-slate-100">
            Copied to clipboard
          </div>
        </div>
      )}
    </>
  );
}
