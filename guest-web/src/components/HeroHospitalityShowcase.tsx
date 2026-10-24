"use client";

import { useState } from "react";
import Link from "next/link";
import Image from "next/image";
import { hospitalityMoments, HospitalityMoment } from "@/lib/hospitality-moments";

export function HeroHospitalityShowcase() {
  const [selectedId, setSelectedId] = useState<HospitalityMoment["id"]>("dining");

  const activeMoment =
    hospitalityMoments.find((m) => m.id === selectedId) || hospitalityMoments[0];

  return (
    <div className="relative w-full max-w-lg mx-auto lg:max-w-none">
      {/* Ambient glow behind video card */}
      <div
        className="absolute -inset-4 bg-gradient-to-tr from-kl-terracotta/20 via-amber-500/10 to-kl-emerald/15 rounded-3xl blur-2xl opacity-75 pointer-events-none"
        aria-hidden="true"
      />

      {/* Main Showcase Container */}
      <div className="relative bg-[#141413] border border-neutral-700/80 rounded-2xl sm:rounded-3xl p-3 sm:p-4 shadow-2xl overflow-hidden">
        {/* Moment Selector Pills */}
        <div className="flex items-center gap-1.5 p-1 bg-neutral-900/90 rounded-xl mb-3 overflow-x-auto scrollbar-none border border-neutral-800">
          {hospitalityMoments.map((moment) => {
            const isSelected = moment.id === selectedId;
            return (
              <button
                key={moment.id}
                type="button"
                onClick={() => setSelectedId(moment.id)}
                className={`flex-1 min-w-[76px] py-1.5 px-2.5 rounded-lg text-xs font-mono transition-all text-center whitespace-nowrap ${
                  isSelected
                    ? "bg-kl-terracotta text-white font-medium shadow-sm"
                    : "text-neutral-400 hover:text-neutral-200 hover:bg-neutral-800/60"
                }`}
                aria-pressed={isSelected}
              >
                <div className="text-[10px] opacity-80 uppercase tracking-wider">
                  {moment.time.replace(" Uhr", "")}
                </div>
                <div className="font-sans font-medium text-xs leading-none mt-0.5">
                  {moment.id === "dining"
                    ? "Gastraum"
                    : moment.id === "kitchen"
                    ? "Küche"
                    : moment.id === "terrace"
                    ? "Terrasse"
                    : "Bar"}
                </div>
              </button>
            );
          })}
        </div>

        {/* Video / Animated Photography Frame */}
        <div className="relative aspect-[9/13] sm:aspect-[9/14] rounded-xl sm:rounded-2xl overflow-hidden bg-neutral-950 border border-neutral-800 shadow-inner group">
          <video
            key={activeMoment.id}
            autoPlay
            loop
            muted
            playsInline
            poster={activeMoment.posterSrc}
            className="w-full h-full object-cover transition-opacity duration-300"
          >
            <source src={activeMoment.mp4Src} type="video/mp4" />
            {/* Fallback to high-fidelity animated GIF for browsers without video autoplay */}
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src={activeMoment.gifSrc}
              alt={activeMoment.title}
              className="w-full h-full object-cover"
            />
          </video>

          {/* Subtle top & bottom vignette for legibility */}
          <div
            className="absolute inset-0 bg-gradient-to-t from-black/85 via-black/20 to-black/40 pointer-events-none"
            aria-hidden="true"
          />

          {/* Top Overlays: Live Badge & Context */}
          <div className="absolute top-3 inset-x-3 flex items-center justify-between gap-2 pointer-events-none">
            <div className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-black/60 backdrop-blur-md border border-white/15 text-[11px] font-mono text-neutral-200">
              <span className="w-2 h-2 rounded-full bg-kl-terracotta animate-pulse" />
              <span>{activeMoment.time}</span>
              <span className="text-neutral-400">•</span>
              <span className="font-sans font-medium text-white">{activeMoment.act.split("·")[1]?.trim()}</span>
            </div>

            <div className="hidden sm:inline-flex items-center gap-1 px-2 py-0.5 rounded-md bg-emerald-950/70 border border-emerald-700/60 text-[10px] font-mono text-kl-emerald backdrop-blur-sm">
              <span>● LIVE MESH</span>
            </div>
          </div>

          {/* Bottom Overlay: Active Moment Narrative & Quote */}
          <div className="absolute bottom-3 inset-x-3 pointer-events-none">
            <div className="p-3 sm:p-3.5 rounded-xl bg-black/75 backdrop-blur-md border border-white/10 text-white shadow-xl">
              <div className="flex items-center justify-between gap-2 mb-1">
                <span className="font-mono text-[10px] text-kl-terracotta font-semibold uppercase tracking-wider">
                  {activeMoment.tagline}
                </span>
                <span className="font-mono text-[10px] text-neutral-400">
                  {activeMoment.badge.split("·")[0]?.trim()}
                </span>
              </div>
              <p className="font-serif text-base sm:text-lg font-medium leading-snug text-neutral-100">
                „{activeMoment.headline}“
              </p>
              <p className="font-sans text-xs text-neutral-300 mt-1 line-clamp-2 leading-relaxed">
                {activeMoment.description}
              </p>
            </div>
          </div>
        </div>

        {/* Floating Paper Preview Card (Tactile Quiet UI Menu) */}
        <div className="mt-3 bg-kl-canvas text-kl-charcoal border border-kl-border rounded-xl p-3 sm:p-3.5 shadow-lg flex items-center justify-between gap-3">
          <div className="flex items-center gap-2.5 min-w-0">
            <div className="relative w-12 h-12 rounded-lg overflow-hidden border border-kl-border flex-shrink-0 bg-kl-subtle shadow-sm">
              <Image
                src="/images/dish-rote-bete.jpg"
                alt="Geschmorte Rote Bete"
                fill
                sizes="48px"
                className="object-cover"
              />
            </div>
            <div className="min-w-0">
              <div className="flex items-center gap-1.5 flex-wrap">
                <span className="font-serif font-medium text-xs text-kl-muted">
                  Gasthaus Alte Mühle
                </span>
                <span className="bg-kl-sage/15 text-kl-sage text-[9px] px-1 py-0.2 rounded font-medium">
                  Tisch 12
                </span>
              </div>
              <div className="font-sans font-semibold text-xs text-kl-charcoal truncate">
                Geschmorte Rote Bete
              </div>
              <div className="flex items-center gap-1 mt-0.5">
                <span className="bg-kl-subtle text-kl-muted font-mono text-[9px] px-1 py-0.2 rounded">
                  G · Milch
                </span>
                <span className="bg-kl-subtle text-kl-muted font-mono text-[9px] px-1 py-0.2 rounded">
                  H · Walnuss
                </span>
                <span className="font-mono tabular-nums text-xs font-bold text-kl-charcoal ml-1.5">
                  14,50 €
                </span>
              </div>
            </div>
          </div>

          <Link
            href="/alte-muehle/menu"
            className="flex-shrink-0 inline-flex items-center gap-1 bg-kl-terracotta hover:bg-kl-terracotta/90 text-white font-sans text-xs font-medium px-3 py-2 rounded-lg transition-colors shadow-sm"
          >
            <span>Speisekarte</span>
            <span aria-hidden="true">→</span>
          </Link>
        </div>
      </div>
    </div>
  );
}
