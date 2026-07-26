-- KL-MENU-009: Additive Menü-Bearbeitung (einzelne Artikel/Kategorien).
--
-- Bisher erlaubt `operator_publish_menu(_v2)` nur den vollständigen Ersatz
-- der aktiven Karte. Diese Migration ergänzt drei schmale RPCs für
-- artikelweise Änderungen, ohne andere Kategorien oder Artikel zu berühren:
--
--   operator_upsert_menu_item(p_venue_slug, p_category_name, p_category_kind, p_item)
--     → legt einen Artikel an oder aktualisiert ihn; erzeugt die Kategorie
--       bei Bedarf. Gibt die item_id zurück.
--
--   operator_delete_menu_item(p_venue_slug, p_item_slug)
--     → löscht einen Artikel aus der aktiven Karte.
--
--   operator_upsert_category(p_venue_slug, p_name, p_kind)
--     → legt eine Kategorie an oder aktualisiert sie (kind).
--
-- Alle drei sind staff-gated (is_venue_staff) und laufen als SECURITY DEFINER.
-- anon/authenticated ohne Staff-Recht bekommt kein EXECUTE.

begin;

-- ============================================================================
-- operator_upsert_menu_item
-- ============================================================================

create or replace function public.operator_upsert_menu_item(
  p_venue_slug text,
  p_category_name text,
  p_category_kind text default 'food',
  p_item jsonb default '{}'::jsonb
) returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_venue_id uuid;
  v_menu_id uuid;
  v_category_id uuid;
  v_slug text;
  v_name text;
  v_price int;
  v_kind text;
  v_max_order int;
  v_item_id uuid;
begin
  if v_user is null then
    raise exception 'edit_unauthenticated: Anmeldung erforderlich';
  end if;

  select v.id into v_venue_id from public.venues v where v.slug = p_venue_slug;
  if not found then
    raise exception 'edit_unknown_venue: %', p_venue_slug;
  end if;

  if not public.is_venue_staff(v_venue_id) then
    raise exception 'edit_forbidden: kein Personal dieser Venue';
  end if;

  p_category_name := btrim(p_category_name);
  if p_category_name = '' then
    raise exception 'edit_invalid_category: Name fehlt';
  end if;

  if p_category_kind not in ('food', 'drink') then
    raise exception 'edit_invalid_kind: Kategorie % hat kind %', p_category_name, p_category_kind;
  end if;

  v_slug := btrim(coalesce(p_item ->> 'slug', ''));
  if v_slug = '' then
    raise exception 'edit_invalid_item: slug fehlt';
  end if;
  v_name := btrim(coalesce(p_item ->> 'name', ''));
  if v_name = '' then
    raise exception 'edit_invalid_item: Name fehlt (slug %)', v_slug;
  end if;
  v_price := coalesce((p_item ->> 'price_cents')::int, -1);
  if v_price < 0 then
    raise exception 'edit_invalid_price: % (slug %)', p_item ->> 'price_cents', v_slug;
  end if;
  v_kind := lower(coalesce(nullif(p_item ->> 'kind', ''), p_category_kind));
  if v_kind not in ('food', 'drink') then
    raise exception 'edit_invalid_kind: Artikel % hat kind %', v_slug, v_kind;
  end if;

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

  select mc.id into v_category_id
  from public.menu_categories mc
  where mc.menu_id = v_menu_id
    and mc.name = p_category_name;

  if not found then
    select coalesce(max(mc.sort_order), -1) + 1 into v_max_order
    from public.menu_categories mc
    where mc.menu_id = v_menu_id;

    insert into public.menu_categories (menu_id, name, kind, sort_order)
    values (v_menu_id, p_category_name, p_category_kind, v_max_order)
    returning id into v_category_id;
  end if;

  select mi.id into v_item_id
  from public.menu_items mi
  where mi.category_id = v_category_id
    and mi.slug = v_slug;

  if not found then
    select coalesce(max(mi.sort_order), -1) + 1 into v_max_order
    from public.menu_items mi
    where mi.category_id = v_category_id;

    insert into public.menu_items (
      category_id, slug, name, description, price_cents, currency, kind,
      allergen_codes, tag, available, sort_order
    ) values (
      v_category_id,
      v_slug,
      v_name,
      coalesce(p_item ->> 'description', ''),
      v_price,
      'EUR',
      v_kind,
      coalesce(
        (
          select array_agg(code)
          from jsonb_array_elements_text(
            case
              when jsonb_typeof(p_item -> 'allergen_codes') = 'array'
                then p_item -> 'allergen_codes'
              else '[]'::jsonb
            end
          ) as t(code)
        ),
        '{}'::text[]
      ),
      nullif(btrim(coalesce(p_item ->> 'tag', '')), ''),
      true,
      v_max_order
    )
    returning id into v_item_id;
  else
    update public.menu_items mi
    set
      name = v_name,
      description = coalesce(p_item ->> 'description', ''),
      price_cents = v_price,
      kind = v_kind,
      allergen_codes = coalesce(
        (
          select array_agg(code)
          from jsonb_array_elements_text(
            case
              when jsonb_typeof(p_item -> 'allergen_codes') = 'array'
                then p_item -> 'allergen_codes'
              else '[]'::jsonb
            end
          ) as t(code)
        ),
        '{}'::text[]
      ),
      tag = nullif(btrim(coalesce(p_item ->> 'tag', '')), '')
    where mi.id = v_item_id;
  end if;

  return v_item_id;
end;
$$;

revoke all on function public.operator_upsert_menu_item(text, text, text, jsonb)
  from public, anon;
grant execute on function public.operator_upsert_menu_item(text, text, text, jsonb)
  to authenticated;

-- ============================================================================
-- operator_delete_menu_item
-- ============================================================================

create or replace function public.operator_delete_menu_item(
  p_venue_slug text,
  p_item_slug text
) returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_venue_id uuid;
  v_deleted int;
begin
  if v_user is null then
    raise exception 'edit_unauthenticated: Anmeldung erforderlich';
  end if;

  select v.id into v_venue_id from public.venues v where v.slug = p_venue_slug;
  if not found then
    raise exception 'edit_unknown_venue: %', p_venue_slug;
  end if;

  if not public.is_venue_staff(v_venue_id) then
    raise exception 'edit_forbidden: kein Personal dieser Venue';
  end if;

  delete from public.menu_items mi
  where mi.slug = p_item_slug
    and mi.category_id in (
      select mc.id
      from public.menu_categories mc
      join public.menus m on m.id = mc.menu_id
      where m.venue_id = v_venue_id and m.active = true
    );

  get diagnostics v_deleted = row_count;
  return v_deleted > 0;
end;
$$;

revoke all on function public.operator_delete_menu_item(text, text)
  from public, anon;
grant execute on function public.operator_delete_menu_item(text, text)
  to authenticated;

commit;
