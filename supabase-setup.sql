-- HOKI STATION — skema database + aturan keamanan (Row Level Security)
-- Jalankan sekali di Supabase: SQL Editor > New query > tempel semua > Run.

create table public.profiles(
  id uuid primary key references auth.users(id) on delete cascade,
  nama text not null check(char_length(nama) between 2 and 80),
  username text not null unique check(username ~ '^[A-Za-z0-9_]{3,20}$'),
  avatar text not null default '🍎',
  bio text not null default '' check(char_length(bio) <= 300),
  role text not null default 'umum' check(role in ('admin','siswa','guru','alumni','umum')),
  status text not null default 'menunggu' check(status in ('menunggu','aktif','ditolak','nonaktif')),
  created_at timestamptz not null default now());

create table public.writings(
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  judul text not null check(char_length(judul) between 1 and 150),
  kategori text not null,
  isi text not null default '',
  status text not null default 'draf' check(status in ('draf','terbit','arsip','disembunyikan')),
  views int not null default 0,
  published_at timestamptz,
  created_at timestamptz not null default now());
create index on public.writings(status, published_at desc);
create index on public.writings(user_id);

create table public.likes(
  writing_id bigint references public.writings(id) on delete cascade,
  user_id uuid default auth.uid() references public.profiles(id) on delete cascade,
  primary key(writing_id, user_id));
create table public.bookmarks(
  writing_id bigint references public.writings(id) on delete cascade,
  user_id uuid default auth.uid() references public.profiles(id) on delete cascade,
  primary key(writing_id, user_id));
create table public.comments(
  id bigint generated always as identity primary key,
  writing_id bigint not null references public.writings(id) on delete cascade,
  user_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  parent_id bigint references public.comments(id) on delete cascade,
  isi text not null check(char_length(isi) between 1 and 500),
  hidden boolean not null default false,
  reported boolean not null default false,
  created_at timestamptz not null default now());
create index on public.comments(writing_id);
create table public.news(
  id bigint generated always as identity primary key,
  judul text not null check(char_length(judul) between 1 and 150),
  isi text not null,
  created_at timestamptz not null default now());

-- Fungsi bantu (dipakai aturan keamanan)
create function public.is_admin() returns boolean language sql security definer stable set search_path = public as
$$ select exists(select 1 from profiles where id = auth.uid() and role = 'admin' and status = 'aktif') $$;
create function public.is_active() returns boolean language sql security definer stable set search_path = public as
$$ select exists(select 1 from profiles where id = auth.uid() and status = 'aktif') $$;

-- Profil dibuat otomatis saat daftar. Peran dan status SELALU umum + menunggu (tidak bisa dipilih pendaftar).
create function public.on_signup() returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into profiles(id, nama, username, avatar) values(
    new.id,
    left(coalesce(new.raw_user_meta_data->>'nama','Pengguna'), 80),
    coalesce(new.raw_user_meta_data->>'username', 'u' || substr(new.id::text, 1, 8)),
    left(coalesce(new.raw_user_meta_data->>'avatar','🍎'), 8));
  return new;
end $$;
create trigger t_signup after insert on auth.users for each row execute function public.on_signup();

-- Pengguna biasa tidak boleh mengubah peran, status, atau username.
create function public.guard_profile() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null and not is_admin()
     and (new.role <> old.role or new.status <> old.status or new.username <> old.username) then
    raise exception 'Tidak diizinkan';
  end if;
  return new;
end $$;
create trigger t_guard_profile before update on public.profiles for each row execute function public.guard_profile();

-- Validasi tulisan di server: 10-1000 kata, tanggal terbit, dan perlindungan moderasi.
create function public.check_writing() returns trigger language plpgsql set search_path = public as $$
declare n int; sys boolean := coalesce(current_setting('app.sys', true), '') = '1'; adm boolean := false;
begin
  if auth.uid() is not null and not sys then adm := is_admin(); end if;
  n := case when trim(new.isi) = '' then 0 else array_length(regexp_split_to_array(trim(new.isi), '\s+'), 1) end;
  if n > 1000 then raise exception 'Maksimal 1000 kata'; end if;
  if new.status = 'terbit' and n < 10 then raise exception 'Minimal 10 kata untuk dipublikasikan'; end if;
  if auth.uid() is not null and not sys and not adm then
    if tg_op = 'UPDATE' then
      new.views := old.views;
      if old.status = 'disembunyikan' then new.status := 'disembunyikan'; end if;
    else new.views := 0; end if;
    if new.status = 'disembunyikan' then raise exception 'Tidak diizinkan'; end if;
  end if;
  if new.status = 'terbit' and new.published_at is null then new.published_at := now(); end if;
  return new;
end $$;
create trigger t_writing before insert or update on public.writings for each row execute function public.check_writing();

-- Penghitung pembaca dan laporan komentar (hanya lewat fungsi ini)
create function public.add_view(wid bigint) returns void language plpgsql security definer set search_path = public as $$
begin
  perform set_config('app.sys', '1', true);
  update writings set views = views + 1 where id = wid and status = 'terbit' and is_active();
end $$;
create function public.report_comment(cid bigint) returns void language sql security definer set search_path = public as
$$ update comments set reported = true where id = cid and is_active() $$;
revoke execute on function public.add_view(bigint), public.report_comment(bigint) from public, anon;
grant execute on function public.add_view(bigint), public.report_comment(bigint) to authenticated;

-- Aturan akses (RLS): semua tabel terkunci kecuali yang diizinkan di bawah.
alter table public.profiles enable row level security;
alter table public.writings enable row level security;
alter table public.likes enable row level security;
alter table public.bookmarks enable row level security;
alter table public.comments enable row level security;
alter table public.news enable row level security;

create policy p_sel on public.profiles for select to authenticated using (true);
create policy p_upd on public.profiles for update to authenticated using (id = auth.uid() or is_admin()) with check (id = auth.uid() or is_admin());

create policy w_sel on public.writings for select to authenticated using (is_active() and (status = 'terbit' or user_id = auth.uid() or is_admin()));
create policy w_ins on public.writings for insert to authenticated with check (user_id = auth.uid() and is_active());
create policy w_upd on public.writings for update to authenticated using (is_active() and (user_id = auth.uid() or is_admin())) with check (user_id = auth.uid() or is_admin());
create policy w_del on public.writings for delete to authenticated using (is_active() and (user_id = auth.uid() or is_admin()));

create policy l_sel on public.likes for select to authenticated using (is_active());
create policy l_ins on public.likes for insert to authenticated with check (user_id = auth.uid() and is_active());
create policy l_del on public.likes for delete to authenticated using (user_id = auth.uid());

create policy b_sel on public.bookmarks for select to authenticated using (user_id = auth.uid());
create policy b_ins on public.bookmarks for insert to authenticated with check (user_id = auth.uid() and is_active());
create policy b_del on public.bookmarks for delete to authenticated using (user_id = auth.uid());

create policy c_sel on public.comments for select to authenticated using (is_active() and (not hidden or user_id = auth.uid() or is_admin()));
create policy c_ins on public.comments for insert to authenticated with check (user_id = auth.uid() and is_active() and not hidden and not reported);
create policy c_upd on public.comments for update to authenticated using (is_admin()) with check (is_admin());
create policy c_del on public.comments for delete to authenticated using (user_id = auth.uid() or is_admin());

create policy n_sel on public.news for select to authenticated using (is_active());
create policy n_all on public.news for all to authenticated using (is_admin()) with check (is_admin());

-- ADMIN PERTAMA: setelah Anda mendaftar lewat aplikasi, ganti email di bawah dengan email Anda lalu jalankan.
-- (Hapus tanda -- di depan baris update ini.)
-- update public.profiles set role = 'admin', status = 'aktif' where id = (select id from auth.users where email = 'EMAIL_ADMIN_ANDA');
