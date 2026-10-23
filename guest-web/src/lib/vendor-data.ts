/**
 * KitchenLink Lieferanten- & B2B-Warenwirtschaftsdaten.
 *
 * Gegenstück zur iOS-Betreiber-App (KL-PURCHASE-001 & Blueprint §11):
 * Lieferanten und Großhändler nutzen diese Weboberfläche, um:
 * 1. Vom Restaurant übermittelte Bestellungen (Purchase Orders) einzusehen
 * 2. Liefertermine zu bestätigen
 * 3. Digitale Lieferscheine für Fahrer und Wareneingang zu generieren
 * 4. Den Lieferstatus bis zum Wareneingang zu verfolgen
 *
 * Bleibt offline- und sandbox-fähig: Nutzt standardmäßig verlässliche Fixture-Daten
 * und synchronisiert mit localStorage im Browser.
 */

export type VendorOrderStatus =
  | "draft"
  | "sent"
  | "confirmed"
  | "in_transit"
  | "received"
  | "cancelled";

export interface VendorSupplier {
  id: string;
  name: string;
  category: string;
  contactEmail: string;
  phone: string;
  address: string;
  city: string;
  leadTimeDays: number;
}

export interface VendorPurchaseOrderLine {
  id: string;
  ingredientId: string;
  ingredientName: string;
  quantity: number;
  unit: string;
  pricePerUnitCents: number;
  lineTotalCents: number;
}

export interface VendorPurchaseOrder {
  id: string;
  orderNumber: string;
  venueId: string;
  venueName: string;
  venueAddress: string;
  supplierId: string;
  supplierName: string;
  supplierContact: string;
  status: VendorOrderStatus;
  totalCents: number;
  expectedDeliveryDate: string;
  confirmedDeliveryDate?: string;
  notes?: string;
  createdAt: string;
  sentAt?: string;
  receivedAt?: string;
  lines: VendorPurchaseOrderLine[];
}

export interface DeliverySlipData {
  orderNumber: string;
  slipNumber: string;
  slipDate: string;
  venueName: string;
  venueAddress: string;
  supplierName: string;
  supplierAddress: string;
  supplierContact: string;
  expectedDeliveryDate: string;
  totalCents: number;
  notes?: string;
  lines: Array<{
    position: number;
    name: string;
    quantity: number;
    unit: string;
    pricePerUnitCents: number;
    totalCents: number;
  }>;
}

export const sandboxSuppliers: VendorSupplier[] = [
  {
    id: "kochberg",
    name: "Kochberg Frischegroßhandel",
    category: "Frische, Molkerei & Grundbedarf",
    contactEmail: "bestellung@kochberg-frische.de",
    phone: "+49 89 7421890",
    address: "Großmarktstraße 14",
    city: "81371 München",
    leadTimeDays: 1,
  },
  {
    id: "weingut-hoelle",
    name: "Weingut Hölle & Söhne",
    category: "Wein, Sekt & Spirituosen",
    contactEmail: "vertrieb@weingut-hoelle.de",
    phone: "+49 6731 998822",
    address: "Rebenweg 8",
    city: "55232 Alzey",
    leadTimeDays: 3,
  },
  {
    id: "bio-lindner",
    name: "Bio-Gemüsehof Lindner",
    category: "Regionales Bio-Gemüse & Kräuter",
    contactEmail: "kontakt@biohof-lindner.de",
    phone: "+49 8122 458910",
    address: "Hofmark 3",
    city: "85435 Erding",
    leadTimeDays: 2,
  },
  {
    id: "brauerei-muehle",
    name: "Mühlenbrauerei Altbayern",
    category: "Fassbier, Radler & Limonaden",
    contactEmail: "dispo@muehlenbrauerei-altbayern.de",
    phone: "+49 8031 332211",
    address: "Brauhausgasse 1",
    city: "83022 Rosenheim",
    leadTimeDays: 2,
  },
];

export const initialPurchaseOrders: VendorPurchaseOrder[] = [
  {
    id: "po-081",
    orderNumber: "PO-2026-081",
    venueId: "alte-muehle",
    venueName: "Gasthaus Alte Mühle",
    venueAddress: "Mühlenstraße 12, 85435 Erding",
    supplierId: "kochberg",
    supplierName: "Kochberg Frischegroßhandel",
    supplierContact: "bestellung@kochberg-frische.de",
    status: "sent",
    totalCents: 18250,
    expectedDeliveryDate: "2026-10-24",
    notes: "Bitte Anlieferung bis spätestens 10:00 Uhr über den Hinterhof/Kühlrampe.",
    createdAt: "2026-10-23T00:30:00Z",
    sentAt: "2026-10-23T01:00:00Z",
    lines: [
      {
        id: "pol-1",
        ingredientId: "ing-flour",
        ingredientName: "Mehl Type 00 (Weizen)",
        quantity: 25,
        unit: "kg",
        pricePerUnitCents: 120,
        lineTotalCents: 3000,
      },
      {
        id: "pol-2",
        ingredientId: "ing-mozzarella",
        ingredientName: "Fior di Latte Mozzarella 45% FiT",
        quantity: 10,
        unit: "kg",
        pricePerUnitCents: 850,
        lineTotalCents: 8500,
      },
      {
        id: "pol-3",
        ingredientId: "ing-tomato",
        ingredientName: "San-Marzano-Tomaten DOP geschält",
        quantity: 15,
        unit: "kg",
        pricePerUnitCents: 450,
        lineTotalCents: 6750,
      },
    ],
  },
  {
    id: "po-082",
    orderNumber: "PO-2026-082",
    venueId: "alte-muehle",
    venueName: "Gasthaus Alte Mühle",
    venueAddress: "Mühlenstraße 12, 85435 Erding",
    supplierId: "weingut-hoelle",
    supplierName: "Weingut Hölle & Söhne",
    supplierContact: "vertrieb@weingut-hoelle.de",
    status: "sent",
    totalCents: 31800,
    expectedDeliveryDate: "2026-10-26",
    notes: "Monatskontingent Herbstkarte: bruchsichere Kartonage erbeten.",
    createdAt: "2026-10-22T18:15:00Z",
    sentAt: "2026-10-22T19:00:00Z",
    lines: [
      {
        id: "pol-4",
        ingredientId: "ing-redwine",
        ingredientName: "Rotwein Spätburgunder Riserva (0,75 l)",
        quantity: 24,
        unit: "count",
        pricePerUnitCents: 950,
        lineTotalCents: 22800,
      },
      {
        id: "pol-5",
        ingredientId: "ing-whitewine",
        ingredientName: "Grauburgunder Trocken Qualitätswein (0,75 l)",
        quantity: 12,
        unit: "count",
        pricePerUnitCents: 750,
        lineTotalCents: 9000,
      },
    ],
  },
  {
    id: "po-085",
    orderNumber: "PO-2026-085",
    venueId: "alte-muehle",
    venueName: "Gasthaus Alte Mühle",
    venueAddress: "Mühlenstraße 12, 85435 Erding",
    supplierId: "bio-lindner",
    supplierName: "Bio-Gemüsehof Lindner",
    supplierContact: "kontakt@biohof-lindner.de",
    status: "confirmed",
    totalCents: 12960,
    expectedDeliveryDate: "2026-10-25",
    confirmedDeliveryDate: "2026-10-25",
    notes: "Erntefrische Herbstlieferung für Kürbissuppe und Kartoffel-Gurken-Salat.",
    createdAt: "2026-10-22T14:00:00Z",
    sentAt: "2026-10-22T14:30:00Z",
    lines: [
      {
        id: "pol-6",
        ingredientId: "ing-pumpkin",
        ingredientName: "Bio-Hokkaidokürbis",
        quantity: 20,
        unit: "kg",
        pricePerUnitCents: 280,
        lineTotalCents: 5600,
      },
      {
        id: "pol-7",
        ingredientId: "ing-ginger",
        ingredientName: "Frischer Bio-Ingwer",
        quantity: 3,
        unit: "kg",
        pricePerUnitCents: 620,
        lineTotalCents: 1860,
      },
      {
        id: "pol-8",
        ingredientId: "ing-potato",
        ingredientName: "Salatkartoffeln festkochend",
        quantity: 50,
        unit: "kg",
        pricePerUnitCents: 110,
        lineTotalCents: 5500,
      },
    ],
  },
  {
    id: "po-079",
    orderNumber: "PO-2026-079",
    venueId: "alte-muehle",
    venueName: "Gasthaus Alte Mühle",
    venueAddress: "Mühlenstraße 12, 85435 Erding",
    supplierId: "kochberg",
    supplierName: "Kochberg Frischegroßhandel",
    supplierContact: "bestellung@kochberg-frische.de",
    status: "received",
    totalCents: 9800,
    expectedDeliveryDate: "2026-10-21",
    confirmedDeliveryDate: "2026-10-21",
    notes: "Erstpressung Olivenöl für Tisch & Küche.",
    createdAt: "2026-10-18T10:00:00Z",
    sentAt: "2026-10-18T11:00:00Z",
    receivedAt: "2026-10-21T09:45:00Z",
    lines: [
      {
        id: "pol-9",
        ingredientId: "ing-oliveoil",
        ingredientName: "Olivenöl Extra Vergine Kanister (5 l)",
        quantity: 2,
        unit: "count",
        pricePerUnitCents: 4900,
        lineTotalCents: 9800,
      },
    ],
  },
];

const STORAGE_KEY = "kitchenlink-vendor-orders-v1";

/**
 * Lädt alle Bestellungen. Im Browser wird localStorage berücksichtigt.
 */
export function getVendorPurchaseOrders(supplierId?: string): VendorPurchaseOrder[] {
  let list = initialPurchaseOrders;

  if (typeof window !== "undefined") {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (raw) {
        list = JSON.parse(raw);
      }
    } catch {
      // Fallback zu initialen Fixtures
    }
  }

  if (supplierId) {
    return list.filter((po) => po.supplierId === supplierId);
  }
  return list;
}

/**
 * Speichert den aktuellen Bestellbestand im localStorage.
 */
function persistOrders(orders: VendorPurchaseOrder[]): void {
  if (typeof window !== "undefined") {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(orders));
    } catch {
      // Ignore storage errors in restrictive environments
    }
  }
}

/**
 * Holt eine einzelne Bestellung anhand der ID oder Bestellnummer.
 */
export function getPurchaseOrderById(idOrNumber: string): VendorPurchaseOrder | undefined {
  const orders = getVendorPurchaseOrders();
  return orders.find(
    (po) => po.id === idOrNumber || po.orderNumber === idOrNumber,
  );
}

/**
 * Bestätigt eine Bestellung durch den Lieferanten mit avisierter Lieferzeit.
 */
export function confirmPurchaseOrder(
  orderId: string,
  confirmedDeliveryDate?: string,
  supplierNote?: string,
): VendorPurchaseOrder {
  const orders = getVendorPurchaseOrders();
  const index = orders.findIndex((po) => po.id === orderId || po.orderNumber === orderId);

  if (index === -1) {
    throw new Error(`Bestellung mit ID ${orderId} nicht gefunden.`);
  }

  const current = orders[index];
  const targetDate = confirmedDeliveryDate || current.expectedDeliveryDate;
  const updatedNote = supplierNote
    ? current.notes
      ? `${current.notes} | Lieferanten-Notiz: ${supplierNote}`
      : `Lieferanten-Notiz: ${supplierNote}`
    : current.notes;

  const updated: VendorPurchaseOrder = {
    ...current,
    status: "confirmed",
    confirmedDeliveryDate: targetDate,
    notes: updatedNote,
  };

  orders[index] = updated;
  persistOrders(orders);
  return updated;
}

/**
 * Markiert die Bestellung als 'in Zustellung' (Fahrzeug beladen).
 */
export function markPurchaseOrderInTransit(orderId: string): VendorPurchaseOrder {
  const orders = getVendorPurchaseOrders();
  const index = orders.findIndex((po) => po.id === orderId || po.orderNumber === orderId);

  if (index === -1) {
    throw new Error(`Bestellung mit ID ${orderId} nicht gefunden.`);
  }

  const updated: VendorPurchaseOrder = {
    ...orders[index],
    status: "in_transit",
  };

  orders[index] = updated;
  persistOrders(orders);
  return updated;
}

/**
 * Meldet die Ware als beim Restaurant angeliefert ('received').
 */
export function markPurchaseOrderDelivered(orderId: string): VendorPurchaseOrder {
  const orders = getVendorPurchaseOrders();
  const index = orders.findIndex((po) => po.id === orderId || po.orderNumber === orderId);

  if (index === -1) {
    throw new Error(`Bestellung mit ID ${orderId} nicht gefunden.`);
  }

  const updated: VendorPurchaseOrder = {
    ...orders[index],
    status: "received",
    receivedAt: new Date().toISOString(),
  };

  orders[index] = updated;
  persistOrders(orders);
  return updated;
}

/**
 * Setzt den Demobestand auf die Standard-Fixtures zurück.
 */
export function resetVendorOrdersDemo(): void {
  if (typeof window !== "undefined") {
    try {
      localStorage.removeItem(STORAGE_KEY);
    } catch {
      // Ignore
    }
  }
}

/**
 * Generiert Daten für einen standardisierten digitalen Lieferschein.
 */
export function generateDeliverySlip(orderId: string): DeliverySlipData | null {
  const po = getPurchaseOrderById(orderId);
  if (!po) return null;

  const supplier = sandboxSuppliers.find((s) => s.id === po.supplierId);
  const supplierAddress = supplier ? `${supplier.address}, ${supplier.city}` : "Großmarkt";

  return {
    orderNumber: po.orderNumber,
    slipNumber: `LS-${po.orderNumber.replace("PO-", "")}`,
    slipDate: new Date().toLocaleDateString("de-DE"),
    venueName: po.venueName,
    venueAddress: po.venueAddress,
    supplierName: po.supplierName,
    supplierAddress,
    supplierContact: po.supplierContact,
    expectedDeliveryDate: po.confirmedDeliveryDate || po.expectedDeliveryDate,
    totalCents: po.totalCents,
    notes: po.notes,
    lines: po.lines.map((line, idx) => ({
      position: idx + 1,
      name: line.ingredientName,
      quantity: line.quantity,
      unit: line.unit,
      pricePerUnitCents: line.pricePerUnitCents,
      totalCents: line.lineTotalCents,
    })),
  };
}

/**
 * Formatiert Cent-Beträge in lesbares Euro-Format (z.B. "18,45 €").
 */
export function formatCents(cents: number): string {
  const euros = cents / 100;
  return `${euros.toLocaleString("de-DE", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })} €`;
}

/**
 * Übersetzt den Status in ein deutsches Label und CSS-Farbindikatoren.
 */
export function getStatusBadgeInfo(status: VendorOrderStatus): {
  label: string;
  cssModifier: string;
  isActionable: boolean;
} {
  switch (status) {
    case "sent":
      return {
        label: "Offen / Neu eingegangen",
        cssModifier: "kl-vendor-status-sent",
        isActionable: true,
      };
    case "confirmed":
      return {
        label: "Bestätigt / In Kommission",
        cssModifier: "kl-vendor-status-confirmed",
        isActionable: true,
      };
    case "in_transit":
      return {
        label: "In Auslieferung",
        cssModifier: "kl-vendor-status-transit",
        isActionable: true,
      };
    case "received":
      return {
        label: "Geliefert & Eingebucht",
        cssModifier: "kl-vendor-status-received",
        isActionable: false,
      };
    case "draft":
      return {
        label: "Entwurf Restaurant",
        cssModifier: "kl-vendor-status-draft",
        isActionable: false,
      };
    case "cancelled":
      return {
        label: "Storniert",
        cssModifier: "kl-vendor-status-cancelled",
        isActionable: false,
      };
  }
}
