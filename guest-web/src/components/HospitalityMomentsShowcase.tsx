"use client";

import { useState } from "react";
import Link from "next/link";
import { hospitalityMoments, HospitalityMoment } from "@/lib/hospitality-moments";

export function HospitalityMomentsShowcase() {
  const [activeId, setActiveId] = useState<HospitalityMoment["id"]>("dining");

  const current =
    hospitalityMoments.find((m) => m.id === activeId) || hospitalityMoments[0];

  return (
    <section className="bg-kl-canvas text-kl-charcoal py-20 lg:py-28 border-b border-kl-border relative overflow-hidden">
      {/* Subtle paper grain / background decoration */}
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        {/* Section Header */}
        <div className="max-w-3xl">
          <div className="inline-flex items-center gap-2 mb-3">
            <span className="w-2 h-2 rounded-full bg-kl-terracotta" />
            <span className="font-mono text-xs uppercase tracking-widest text-kl-terracotta font-semibold">
              GASTRONOMIE MIT HERZ & RHYTHMUS
            </span>
          </div>
          <h2 className="font-serif text-3xl sm:text-4xl lg:text-5xl font-medium tracking-tight text-kl-charcoal leading-tight">
            Ein Tag im Restaurant –
            <br />
            <span className="italic text-kl-muted">vier Momente voller Leben.</span>
          </h2>
          <p className="text-kl-muted text-base sm:text-lg max-w-2xl mt-4 font-sans leading-relaxed">
            Gastronomie ist kein starres Software-Problem, sondern ein lebendiger Organismus.
            KitchenLink nimmt den Druck vom Team und gibt Raum für das, was zählt:
            frisches Essen, unbeschwerte Gäste und Freude an der Gastfreundschaft.
          </p>
        </div>

        {/* 1. Interactive Time Pills (Navigation) */}
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-2.5 sm:gap-3 mt-10">
          {hospitalityMoments.map((moment) => {
            const isActive = moment.id === activeId;
            return (
              <button
                key={moment.id}
                type="button"
                onClick={() => setActiveId(moment.id)}
                className={`p-3.5 sm:p-4 rounded-xl text-left transition-all border ${
                  isActive
                    ? "bg-kl-surface border-kl-terracotta/60 shadow-md ring-2 ring-kl-terracotta/20"
                    : "bg-kl-surface/60 border-kl-border hover:bg-kl-surface hover:border-kl-border/90 text-kl-muted"
                }`}
                aria-pressed={isActive}
              >
                <div className="flex items-center justify-between mb-1">
                  <span
                    className={`font-mono text-xs font-semibold px-2 py-0.5 rounded ${
                      isActive
                        ? "bg-kl-terracotta text-white"
                        : "bg-kl-subtle text-kl-muted"
                    }`}
                  >
                    {moment.time}
                  </span>
                  <span className="font-mono text-[11px] text-kl-muted hidden sm:inline">
                    {moment.act.split("·")[0]?.trim()}
                  </span>
                </div>
                <div
                  className={`font-sans font-semibold text-sm line-clamp-1 mt-1 ${
                    isActive ? "text-kl-charcoal" : "text-kl-muted"
                  }`}
                >
                  {moment.act.split("·")[1]?.trim() || moment.title}
                </div>
              </button>
            );
          })}
        </div>

        {/* 2. Spotlight Showcase (Editorial 2-Column Display) */}
        <div className="mt-8 bg-kl-surface border border-kl-border rounded-2xl sm:rounded-3xl p-6 sm:p-8 lg:p-10 shadow-sm">
          <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 lg:gap-12 items-center">
            {/* Left: Animated Video Frame */}
            <div className="lg:col-span-5 relative">
              <div className="relative aspect-[9/14] sm:aspect-[9/15] rounded-2xl overflow-hidden bg-kl-dark border border-neutral-700/80 shadow-2xl">
                <video
                  key={current.id}
                  autoPlay
                  loop
                  muted
                  playsInline
                  poster={current.posterSrc}
                  className="w-full h-full object-cover"
                >
                  <source src={current.mp4Src} type="video/mp4" />
                  {/* Fallback to high-fidelity animated GIF */}
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img
                    src={current.gifSrc}
                    alt={current.title}
                    className="w-full h-full object-cover"
                  />
                </video>

                {/* Subtle dark gradient for badge legibility */}
                <div
                  className="absolute inset-0 bg-gradient-to-t from-black/80 via-transparent to-black/40 pointer-events-none"
                  aria-hidden="true"
                />

                {/* Top Badge */}
                <div className="absolute top-3.5 inset-x-3.5 flex items-center justify-between">
                  <span className="font-mono text-xs text-white bg-black/60 backdrop-blur-md px-3 py-1 rounded-full border border-white/20">
                    {current.time} • {current.act.split("·")[1]?.trim()}
                  </span>
                </div>

                {/* Bottom Overlay Badge */}
                <div className="absolute bottom-3.5 inset-x-3.5">
                  <div className="bg-black/75 backdrop-blur-md border border-white/15 p-3 rounded-xl text-white">
                    <div className="flex items-center gap-2 font-mono text-xs">
                      <span className="w-2 h-2 rounded-full bg-kl-emerald animate-pulse" />
                      <span>{current.badge}</span>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            {/* Right: Narrative Editorial Details */}
            <div className="lg:col-span-7 flex flex-col justify-between">
              <div>
                <div className="flex items-center gap-2">
                  <span className="font-mono text-xs uppercase tracking-widest text-kl-terracotta font-semibold">
                    {current.act}
                  </span>
                  <span className="text-kl-border">•</span>
                  <span className="font-mono text-xs text-kl-muted">
                    {current.time}
                  </span>
                </div>

                <h3 className="font-serif text-2xl sm:text-3xl lg:text-4xl font-medium tracking-tight text-kl-charcoal mt-2 leading-snug">
                  {current.title}
                </h3>

                <p className="font-sans text-base sm:text-lg text-kl-muted mt-4 leading-relaxed">
                  {current.description}
                </p>

                {/* Feature Bullets */}
                <ul className="mt-6 space-y-2.5 font-sans text-sm text-kl-charcoal">
                  {current.bulletPoints.map((bullet, idx) => (
                    <li key={idx} className="flex items-start gap-2.5">
                      <span className="text-kl-terracotta font-bold text-base leading-none mt-0.5">
                        ✓
                      </span>
                      <span>{bullet}</span>
                    </li>
                  ))}
                </ul>

                {/* Authentic Testimonial Quote */}
                <blockquote className="mt-8 p-4 sm:p-5 bg-kl-subtle/80 border-l-4 border-kl-terracotta rounded-r-xl">
                  <p className="font-serif italic text-base sm:text-lg text-kl-charcoal leading-snug">
                    „{current.quote}“
                  </p>
                  <footer className="mt-2 font-mono text-xs text-kl-muted">
                    — <span className="font-semibold text-kl-charcoal">{current.quoteAuthor}</span>, {current.quoteRole}
                  </footer>
                </blockquote>
              </div>

              {/* Action Link */}
              <div className="mt-8 pt-6 border-t border-kl-border/80 flex flex-wrap items-center gap-4">
                <Link
                  href={current.ctaHref}
                  className="inline-flex items-center gap-2 bg-kl-terracotta hover:bg-kl-terracotta/90 text-white font-sans text-sm font-medium px-5 py-3 rounded-xl transition-all shadow-sm hover:shadow"
                >
                  <span>{current.ctaText}</span>
                  <span aria-hidden="true">→</span>
                </Link>
                <span className="font-mono text-xs text-kl-muted">
                  Sandbox live ohne Registrierung
                </span>
              </div>
            </div>
          </div>
        </div>

        {/* 3. Four-Moment Living Strip (All 4 in Simultaneous Motion) */}
        <div className="mt-14">
          <div className="flex items-center justify-between mb-4">
            <h4 className="font-serif text-lg font-medium text-kl-charcoal">
              Alle vier Rhythmen auf einen Blick
            </h4>
            <span className="font-mono text-xs text-kl-muted">
              Klicke auf einen Moment zum Fokussieren
            </span>
          </div>

          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            {hospitalityMoments.map((moment) => {
              const isSelected = moment.id === activeId;
              return (
                <button
                  key={moment.id}
                  type="button"
                  onClick={() => setActiveId(moment.id)}
                  className={`text-left rounded-xl overflow-hidden border transition-all group ${
                    isSelected
                      ? "ring-2 ring-kl-terracotta border-kl-terracotta shadow-md"
                      : "border-kl-border hover:border-kl-muted/50 bg-kl-surface"
                  }`}
                >
                  <div className="relative aspect-[9/13] bg-kl-dark overflow-hidden">
                    <video
                      autoPlay
                      loop
                      muted
                      playsInline
                      poster={moment.posterSrc}
                      className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
                    >
                      <source src={moment.mp4Src} type="video/mp4" />
                      {/* eslint-disable-next-line @next/next/no-img-element */}
                      <img
                        src={moment.gifSrc}
                        alt={moment.title}
                        className="w-full h-full object-cover"
                      />
                    </video>
                    <div className="absolute inset-0 bg-gradient-to-t from-black/80 via-transparent to-transparent pointer-events-none" />
                    <div className="absolute bottom-2.5 inset-x-2.5 text-white">
                      <div className="font-mono text-[10px] text-kl-terracotta font-semibold">
                        {moment.time}
                      </div>
                      <div className="font-sans font-medium text-xs leading-snug line-clamp-1">
                        {moment.title}
                      </div>
                    </div>
                  </div>
                </button>
              );
            })}
          </div>
        </div>
      </div>
    </section>
  );
}
