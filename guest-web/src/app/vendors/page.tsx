import type { Metadata } from "next";
import { VendorPortal } from "@/components/VendorPortal";

export const metadata: Metadata = {
  title: "KitchenLink B2B Lieferanten-Portal | Plattform-Gegenstück",
  description:
    "B2B-Lieferantenportal für KitchenLink Gastronomie: Bestellungen einsehen, Liefertermine bestätigen und digitale Lieferscheine drucken.",
};

export default function VendorsPage() {
  return <VendorPortal />;
}
