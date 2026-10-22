import type { Metadata, Viewport } from "next";
import "./globals.css";

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
    <html lang="de" suppressHydrationWarning>
      <head>
        <script
          dangerouslySetInnerHTML={{
            __html: `(function(){try{var t=localStorage.getItem("kitchenlink-theme");var m=window.matchMedia("(prefers-color-scheme: dark)").matches;var theme=t||(m?"dark":"light");document.documentElement.setAttribute("data-theme",theme);}catch(e){}})();`,
          }}
        />
      </head>
      <body>
        <div className="kl-sandbox-banner kl-type-meta" role="status">
          Sandbox – keine echten Bestellungen, keine Zahlungen
        </div>
        {children}
      </body>
    </html>
  );
}
