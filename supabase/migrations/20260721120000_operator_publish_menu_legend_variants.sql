-- KL-MENU-006: Publish-Vertrag um Allergen-Legende und Varianten erweitern.
--
-- Der manuelle Editor (und der Scan-Import) erfassen jetzt pro Kategorie eine
-- Allergen-/Zusatzstoff-Legende (Code→Klartext) und pro Artikel
-- Varianten/Portionen/Extras. Die Zielspalten existieren seit dem Kernschema
-- (`menu_categories.allergen_legend jsonb`, `menu_items.variant_options jsonb`),
-- wurden von der ersten Fassung der RPC aber bewusst nicht gefüllt
-- (20260719200000, „bewusster erster Schnitt"). Diese additive Migration ersetzt
-- ausschließlich die Funktion `operator_publish_menu`, sodass beide Felder aus
-- `p_menu` übernommen werden. Semantik, Slug-Invariante, Staff-Gate und
-- „genau eine aktive Karte" bleiben unverändert.
--
-- Erweiterte Nutzlast-Form (p_menu):
--   {
--     "categories": [
--       {
--         "name": "Küche", "kind": "food",
--         "allergen_legend": { "a": "Glutenhaltiges Getreide", "g": "Milch" },
--         "items": [
--           { "slug": "kuerbissuppe", "name": "Kürbissuppe",
--             "description": "…", "price_cents": 690, "kind": "food",
--             "allergen_codes": ["a","g"],
--             "variant_options": [
--               { "name": "Klein", "price_cents": 490, "kind": "portion" },
--               { "name": "mit Sahne", "price_cents": 80, "kind": "extra" }
--             ] }
--         ]
--       }
--     ]
--   }
-- `allergen_legend` (Objekt) und `variant_options` (Array) sind optional und
-- fallen auf `{}` bzw. `[]` zurück. Legenden-Keys werden klein geschrieben
-- (konsistent zu den klein geschriebenen `allergen_codes`); Varianten mit leerem
-- Namen werden ausgelassen, `kind` wird auf portion|extra|variant normalisiert.

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
-- Die RETURNS TABLE deklariert OUT-Spalten (menu_id, category_count,
-- item_count), deren Namen mit Tabellenspalten kollidieren (u. a.
-- menu_categories.menu_id). Ohne diese Direktive lehnt PL/pgSQL
-- `delete ... where menu_id = v_menu_id` als mehrdeutig ab (latenter Fehler der
-- ersten RPC-Fassung 20260719200000, die real noch nie ausgeführt wurde). Die
-- OUT-Parameter werden im Rumpf nie namentlich referenziert (Rückgabe nur über
-- die v_-Variablen), daher löst `use_column` alle unqualifizierten Namen
-- eindeutig auf die Spalten auf.
#variable_conflict use_column
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
  v_legend jsonb;
  v_variants jsonb;
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

    -- Legende (Code→Klartext): Keys klein, leere Paare aussortieren.
    v_legend := coalesce(
      (
        select jsonb_object_agg(lower(btrim(kv.key)), kv.value)
        from jsonb_each_text(
          case
            when jsonb_typeof(v_category -> 'allergen_legend') = 'object'
              then v_category -> 'allergen_legend'
            else '{}'::jsonb
          end
        ) as kv(key, value)
        where btrim(kv.key) <> '' and btrim(kv.value) <> ''
      ),
      '{}'::jsonb
    );

    insert into public.menu_categories (menu_id, name, kind, sort_order, allergen_legend)
    values (v_menu_id, v_name, v_cat_kind, v_cat_index, v_legend)
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

      -- Varianten/Portionen/Extras: nur wohlgeformte Objekte mit Namen; Preis
      -- >= 0; kind auf portion|extra|variant normalisiert; Reihenfolge erhalten.
      v_variants := coalesce(
        (
          select jsonb_agg(
            jsonb_build_object(
              'name', btrim(opt.value ->> 'name'),
              'price_cents', greatest(coalesce((opt.value ->> 'price_cents')::int, 0), 0),
              'kind', case lower(coalesce(opt.value ->> 'kind', 'variant'))
                        when 'portion' then 'portion'
                        when 'extra' then 'extra'
                        else 'variant'
                      end
            )
            order by opt.ordinality
          )
          from jsonb_array_elements(
            case
              when jsonb_typeof(v_item -> 'variant_options') = 'array'
                then v_item -> 'variant_options'
              else '[]'::jsonb
            end
          ) with ordinality as opt(value, ordinality)
          where jsonb_typeof(opt.value) = 'object'
            and btrim(coalesce(opt.value ->> 'name', '')) <> ''
        ),
        '[]'::jsonb
      );

      insert into public.menu_items (
        category_id, slug, name, description, price_cents, currency, kind,
        allergen_codes, variant_options, available, sort_order
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
        v_variants,
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
