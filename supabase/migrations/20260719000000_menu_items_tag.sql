-- KL-WEB-004: tag-Spalte auf menu_items für die Tag-Pills im Gast-Web.
--
-- Die lokale Fixture (guest-web/src/lib/venue-data.ts) trägt pro Artikel ein
-- optionales `tag` (z. B. "beliebt", "vegetarisch"), das im Gast-Web als
-- kleine Pille neben dem Namen angezeigt wird (Round-04-Visual-Review). Die DB
-- hatte bisher keine Entsprechung; ein Supabase-Fetch des Menüs (KL-WEB-004)
-- hätte diese Pills verloren. Diese additive Migration ergänzt die Spalte und
-- befüllt sie für die vorhandenen Sandbox-Artikel deckungsgleich mit der
-- Fixture, sodass das visuelle Ergebnis beim Umstieg identisch bleibt.
--
-- Additiv: nur eine nullable text-Spalte + idempotente Updates. Keine Tabellen-
-- oder Policy-Änderung. Die übrigen Migrationen bleiben unangetastet.
-- Der Tag ist optional (die meisten Artikel haben keinen); NULL ist erlaubt.

begin;

alter table public.menu_items
  add column if not exists tag text;

-- Sandbox-Seed-Tags, deckungsgleich mit guest-web/src/lib/venue-data.ts:
--   flammkuchen     -> "beliebt"
--   wiener-schnitzel -> "beliebt"
--   kaesespaetzle   -> "vegetarisch"
-- (Die übrigen 5 Artikel haben in der Fixture keinen Tag -> NULL bleibt NULL.)
update public.menu_items
  set tag = 'beliebt'
  where slug in ('flammkuchen', 'wiener-schnitzel')
    and tag is distinct from 'beliebt';

update public.menu_items
  set tag = 'vegetarisch'
  where slug = 'kaesespaetzle'
    and tag is distinct from 'vegetarisch';

commit;
