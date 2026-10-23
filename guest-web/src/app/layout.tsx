import type { Metadata, Viewport } from "next";
import { Plus_Jakarta_Sans, Newsreader, JetBrains_Mono } from "next/font/google";
import "./globals.css";

const sans = Plus_Jakarta_Sans({
  subsets: ["latin"],
  variable: "--font-sans",
  display: "swap",
});

const serif = Newsreader({
  subsets: ["latin"],
  style: ["normal", "italic"],
  variable: "--font-serif",
  display: "swap",
});

const mono = JetBrains_Mono({
  subsets: ["latin"],
  variable: "--font-mono",
  display: "swap",
});

export const metadata: Metadata = {
  title: "KitchenLink Gast",
  description:
    "KitchenLink Gast-Web (Sandbox): Speisekarte ansehen und Bestellung vorbereiten.",
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html
      lang="de"
      suppressHydrationWarning
      className={`${sans.variable} ${serif.variable} ${mono.variable}`}
    >
      <head>
        <script
          dangerouslySetInnerHTML={{
            __html: `(function(){try{var t=localStorage.getItem("kitchenlink-theme");var m=window.matchMedia("(prefers-color-scheme: dark)").matches;var theme=t||(m?"dark":"light");document.documentElement.setAttribute("data-theme",theme);}catch(e){}})();`,
          }}
        />
      </head>
      <body className="bg-kl-canvas text-kl-charcoal font-sans antialiased selection:bg-kl-terracotta/20 selection:text-kl-terracotta min-h-screen">
        <div
          className="kl-sandbox-banner bg-kl-dark text-kl-canvas py-1.5 px-4 text-center text-xs font-mono tracking-wide"
          role="status"
        >
          Sandbox – keine echten Bestellungen, keine Zahlungen
        </div>
        {children}
      </body>
    </html>
  );
}
