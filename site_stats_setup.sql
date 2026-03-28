-- Table to store site statistics
create table if not exists site_stats (
    id int primary key default 1,
    total_visits bigint default 0,
    unique (id)
);

-- Initialize the stats table if empty
insert into site_stats (id, total_visits)
values (1, 0)
on conflict (id) do nothing;

-- Function to increment visits safely
create or replace function increment_site_visits()
returns void
language plpgsql
security definer
as $$
begin
    update site_stats
    set total_visits = total_visits + 1
    where id = 1;
end;
$$;

-- Explicitly grant permissions to standard Supabase roles
grant select on table site_stats to anon, authenticated;
grant execute on function increment_site_visits() to anon, authenticated;

-- RLS Policies
alter table site_stats enable row level security;

-- Everyone can read the stats
drop policy if exists "Allow public read-only access to stats" on site_stats;
create policy "Allow public read-only access to stats"
on site_stats for select
to anon, authenticated
using (true);

-- Trigger a manual schema cache refresh (PostgREST)
notify pgrst, 'reload schema';
