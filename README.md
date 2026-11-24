# Hoki Station (versi berfungsi)

Aplikasi literasi digital SMAN 1 Gondanglegi: satu berkas `index.html` yang dihosting di GitHub Pages, dengan akun, database, dan hak akses sungguhan lewat **Supabase** (gratis untuk skala kecil). Tanpa Supabase, aplikasi hanya menampilkan pesan "Belum dikonfigurasi".

## Pemasangan (sekitar 20 menit)

1. **Buat proyek Supabase** di supabase.com (daftar gratis, New project). Simpan password database di tempat aman.
2. **Buat tabel dan aturan keamanan:** buka *SQL Editor → New query*, tempel seluruh isi `supabase-setup.sql`, klik *Run*. Harus muncul "Success".
3. **Atur login:** *Authentication → Sign In / Providers → Email*. Matikan **Confirm email** (disarankan, karena admin sudah memverifikasi akun, dan email bawaan Supabase dibatasi jumlah kirimnya). Lalu *Authentication → URL Configuration*: isi **Site URL** dengan alamat GitHub Pages Anda (misalnya `https://namapengguna.github.io/hoki-station/`). Ini dipakai untuk tautan reset password.
4. **Salin kunci:** klik tombol **Connect** di proyek Supabase (atau *Project Settings → API Keys*). Salin **Project URL** dan kunci **publishable** (atau **anon**). Jangan pernah memakai kunci **secret** atau **service_role**.
5. **Unggah ke GitHub** (repositori Public): `index.html` dan `README.md`. Lalu buat berkas baru **config.js** langsung di GitHub (*Add file → Create new file*) dengan isi dari `config.contoh.js`, ganti dua nilainya dengan hasil langkah 4, dan commit. Aktifkan Pages (Settings → Pages → Deploy from a branch → `main` → `/ (root)`).
6. **Buat akun admin:** buka alamat situs, tab *Daftar*, daftar dengan email Anda dan **password kuat yang baru**. Lalu di SQL Editor jalankan (ganti emailnya):
   ```sql
   update public.profiles set role = 'admin', status = 'aktif'
   where id = (select id from auth.users where email = 'EMAIL_ADMIN_ANDA');
   ```
   Setelah itu masuk; akun Anda berstatus admin dengan avatar mahkota.
7. Akun lain mendaftar sendiri, lalu admin menyetujuinya di **Admin → Verifikasi** dan menetapkan perannya.

## Yang sudah berfungsi

Daftar dan login (hanya akun yang disetujui admin yang bisa masuk), lupa dan ubah password, 20 avatar, profil; menulis (10–1.000 kata, divalidasi juga di server), draf, terbit, edit, arsip, hapus; karya, pencarian, filter kategori, urutan; halaman baca (tema Terang/Gelap/Hangat, ukuran huruf), penghitung pembaca, suka, simpan ke Perpustakaan Saya, komentar, balasan, lapor; admin: verifikasi dan peran, kelola akun (peran, nonaktifkan), berita (tulis, edit, hapus), moderasi karya dan komentar, laporan statistik dengan unduhan CSV; menu Panduan. Hak akses dijaga oleh database (RLS), bukan hanya oleh tampilan.

## Belum ada di versi ini

Upload gambar dan audio, editor format teks (tebal, miring, dan sebagainya), sistem bab novelet/cerbung, target harian, ranking dan badge, notifikasi, login dengan username (saat ini email), kelola kategori dan banner, audit log, ekspor Word/PDF/Excel, backup otomatis dan Google Drive, avatar ilustrasi (saat ini emoji buah).

## Catatan

- Proyek Supabase gratis bisa dijeda jika lama tidak aktif, dan punya batas penyimpanan. Periksa kebijakan terbarunya di supabase.com/pricing.
- Lakukan ekspor data berkala (Admin → Laporan → CSV) dan cadangan database dari dasbor Supabase sampai backup otomatis tersedia.
- Berkas ini belum diuji pada proyek Supabase sungguhan. Kalau ada pesan galat saat uji pertama, kirim tulisannya agar bisa diperbaiki.
