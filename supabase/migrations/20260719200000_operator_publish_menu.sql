-- KL-MENU-005: Scan-zu-Publish-Brücke — der Betreiber veröffentlicht ein
-- geprüftes, importiertes Menü in die Supabase-Venue, sodass die gescannte
-- Karte auf dem Gast-Web (kitchenlink.luneq.eu/<slug>/menu) erscheint.
--
-- Additive Migration. Keine bestehende Tabelle, Policy oder Funktion wird
-- geändert. Neu ist ausschließlich die SECURITY-DEFINER-RPC
-- `operator_publish_menu` — das einzige Schreibtor für die Menükarte einer
-- Venue. Die Menü-Tabellen (menus/menu_categories/menu_items) haben weiterhin
-- KEINE direkten Client-Schreib-Policies; geschrieben wird nur über diese RPC.
--
-- Semantik (bewusst identisch zur lokalen Sandbox-Übernahme `store.replaceMenu`):
--   Ein veröffentlichter Scan ERSETZT die aktive Karte der Venue vollständig.
--   Das Menü, das der Betreiber gerade geprüft und freigegeben hat, IST danach
--   die Karte. Es gibt bewusst keinen Merge/Append — additive Kartenpflege wäre
--   ein eigenes späteres Ticket.
--
-- Zugriff: nur `venue_staff` (über `is_venue_staff`), gespiegelt zu KL-CLOUD-001.
--
-- Lastende Invariante (guest-web/src/lib/menu-loader.ts + order gate):
--   `menu_items.slug` ist die Gast-Web-Client-ID und muss innerhalb der aktiven
--   Karte einer Venue eindeutig sein, sonst wird die serverseitige
--   Neubepreisung in `guest_web_submit_order` mehrdeutig. Die Funktion lehnt
--   doppelte Slugs in der Nutzlast ab und garantiert genau EINE aktive Karte
--   pro Venue.
--
-- Nutzlast-Form (p_menu):
--   {
--     "categories": [
--       {
--         "name": "Küche",
--         "kind": "food",
--         "items": [
--           { "slug": "kuerbissuppe", "name": "Kürbissuppe",
--             "description": "…", "price_cents": 690, "kind": "food",
--             "allergen_codes": ["a","c"] }
--         ]
--       }
--     ]
--   }
-- `kind` ist optional pro Artikel (fällt auf den Kategorie-`kind` zurück);
-- `description` und `allergen_codes` sind optional. `price_cents` ist Pflicht
-- und >= 0. `tag` und `variant_options` werden hier NICHT gesetzt (bewusster
-- erster Schnitt; die Gastkarte und der Bestell-Gate nutzen beides derzeit
-- nicht — dokumentiert im Handoff als Folgearbeit).

begin;

create or replace function public.operator_publish_menu(
  p_venue_slug text,
  p_menu jsonb
) returns table (
  menu_id uuid,
  category_count int,
  item_count int
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_venue_id uuid;
  v_menu_id uuid;
  v_categories jsonb;
  v_category jsonb;
  v_item jsonb;
  v_category_id uuid;
  v_cat_index int := 0;
  v_item_index int := 0;
  v_category_count int := 0;
  v_item_count int := 0;
  v_cat_kind text;
  v_item_kind text;
  v_slug text;
  v_name text;
  v_price int;
  v_total_slugs int;
  v_distinct_slugs int;
begin
  -- 1. Authentifizierung, Venue-Lookup und Personalprüfung.
  if v_user is null then
    raise exception 'publish_unauthenticated: Anmeldung erforderlich';
  end if;

  select v.id into v_venue_id from public.venues v where v.slug = p_venue_slug;
  if not found then
    raise exception 'publish_unknown_venue: %', p_venue_slug;
  end if;

  if not public.is_venue_staff(v_venue_id) then
    raise exception 'publish_forbidden: kein Personal dieser Venue';
  end if;

  -- 2. Grundstruktur der Nutzlast.
  if p_menu is null or jsonb_typeof(p_menu) is distinct from 'object' then
    raise exception 'publish_invalid_menu: JSON-Objekt erwartet';
  end if;

  v_categories := p_menu -> 'categories';
  if v_categories is null
     or jsonb_typeof(v_categories) is distinct from 'array'
     or jsonb_array_length(v_categories) = 0 then
    raise exception 'publish_empty_menu: keine Kategorien';
  end if;

  -- 3. Slug-Eindeutigkeit über die gesamte Nutzlast (lastende Invariante).
  select count(*), count(distinct (item ->> 'slug'))
    into v_total_slugs, v_distinct_slugs
  from jsonb_array_elements(v_categories) as cat,
       jsonb_array_elements(coalesce(cat -> 'items', '[]'::jsonb)) as item;

  if v_total_slugs = 0 then
    raise exception 'publish_empty_menu: keine Artikel';
  end if;
  if v_total_slugs <> v_distinct_slugs then
    raise exception 'publish_duplicate_slug: Artikel-Slugs müssen eindeutig sein';
  end if;

  -- 4. Genau eine aktive Karte: bestehende aktive Karte wählen oder neu anlegen,
  --    danach alle anderen Karten der Venue deaktivieren (der Bestell-Gate
  --    bleibt so eindeutig, weil er über alle aktiven Karten der Venue auflöst).
  select m.id into v_menu_id
  from public.menus m
  where m.venue_id = v_venue_id and m.active = true
  order by m.created_at asc, m.id asc
  limit 1;

  if not found then
    insert into public.menus (venue_id, name, active)
    values (v_venue_id, 'Standard', true)
    returning id into v_menu_id;
  end if;

  update public.menus m
    set active = (m.id = v_menu_id)
    where m.venue_id = v_venue_id;

  -- 5. Inhalt vollständig ersetzen. Das Löschen der Kategorien kaskadiert auf
  --    menu_items; historische order_items.menu_item_id fallen per FK auf NULL
  --    (Name und Preis bleiben als Snapshot in order_items erhalten, keine
  --    Bestellung wird beschädigt).
  delete from public.menu_categories where menu_id = v_menu_id;

  -- 6. Kategorien und Artikel in der übergebenen Reihenfolge einfügen.
  for v_category in select * from jsonb_array_elements(v_categories) loop
    v_name := btrim(coalesce(v_category ->> 'name', ''));
    if v_name = '' then
      raise exception 'publish_invalid_category: Name fehlt';
    end if;
    v_cat_kind := lower(coalesce(v_category ->> 'kind', 'food'));
    if v_cat_kind not in ('food', 'drink') then
      raise exception 'publish_invalid_kind: Kategorie % hat kind %', v_name, v_cat_kind;
    end if;

    insert into public.menu_categories (menu_id, name, kind, sort_order)
    values (v_menu_id, v_name, v_cat_kind, v_cat_index)
    returning id into v_category_id;

    v_cat_index := v_cat_index + 1;
    v_category_count := v_category_count + 1;

    v_item_index := 0;
    for v_item in
      select * from jsonb_array_elements(coalesce(v_category -> 'items', '[]'::jsonb))
    loop
      v_slug := btrim(coalesce(v_item ->> 'slug', ''));
      if v_slug = '' then
        raise exception 'publish_invalid_item: slug fehlt';
      end if;
      v_name := btrim(coalesce(v_item ->> 'name', ''));
      if v_name = '' then
        raise exception 'publish_invalid_item: Name fehlt (slug %)', v_slug;
      end if;
      v_price := coalesce((v_item ->> 'price_cents')::int, -1);
      if v_price < 0 then
        raise exception 'publish_invalid_price: % (slug %)', v_item ->> 'price_cents', v_slug;
      end if;
      v_item_kind := lower(coalesce(nullif(v_item ->> 'kind', ''), v_cat_kind));
      if v_item_kind not in ('food', 'drink') then
        raise exception 'publish_invalid_kind: Artikel % hat kind %', v_slug, v_item_kind;
      end if;

      insert into public.menu_items (
        category_id, slug, name, description, price_cents, currency, kind,
        allergen_codes, available, sort_order
      )
      values (
        v_category_id,
        v_slug,
        v_name,
        coalesce(v_item ->> 'description', ''),
        v_price,
        'EUR',
        v_item_kind,
        coalesce(
          (
            select array_agg(code)
            from jsonb_array_elements_text(
              case
                when jsonb_typeof(v_item -> 'allergen_codes') = 'array'
                  then v_item -> 'allergen_codes'
                else '[]'::jsonb
              end
            ) as t(code)
          ),
          '{}'::text[]
        ),
        true,
        v_item_index
      );

      v_item_index := v_item_index + 1;
      v_item_count := v_item_count + 1;
    end loop;
  end loop;

  return query select v_menu_id, v_category_count, v_item_count;
end;
$$;

-- RESTRICTIVE: die Funktion ist das einzige Schreibtor für die Menükarte.
-- anon hat keinen auth.uid() und scheitert in der Funktion ohnehin.
revoke all on function public.operator_publish_menu(text, jsonb) from public, anon;
grant execute on function public.operator_publish_menu(text, jsonb) to authenticated;

commit;
