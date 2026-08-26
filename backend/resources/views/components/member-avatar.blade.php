{{--
    Komponen avatar member reusable (SATU sumber kebenaran render avatar).
    Dipakai di SEMUA tempat Web Admin yang menampilkan member (Data Member,
    Physical Progress, Transaksi, Booking) supaya foto profil tampil konsisten
    saat member update avatar.

    Props:
    - name      : nama member (untuk alt + fallback inisial bila tak dioper).
    - avatarUrl : users.avatar_url (relative path mis. "avatars/x.jpg";
                  data lama bisa URL absolut http/https -> dipakai apa adanya).
                  Dioper via atribut `:avatar-url`.
    - initials  : inisial yang sudah dihitung pemanggil (opsional). Bila null,
                  dihitung dari `name`. Dioper agar tampilan per-halaman
                  (1 vs 2 huruf) tetap sama seperti sebelumnya.

    URL foto resolve pola relative path + baseUrl dinamis (aturan permanen):
    JANGAN hardcode localhost / Storage::url() penuh. avatar_url relative
    dirangkai via asset('storage/'.$path); URL absolut lama dipakai apa adanya.

    CATATAN: komponen ini HANYA merender isi (img / inisial) untuk diletakkan
    di dalam container .xx-avatar milik masing-masing halaman -> sizing, bentuk,
    dan border tiap halaman TIDAK berubah. Ini murni foto profil (avatar) yang
    memang boleh tampil di admin; TIDAK ada kaitan dengan foto/catatan progress
    fisik yang tetap tidak boleh diakses admin.
--}}
@props(['name' => 'Member', 'avatarUrl' => null, 'initials' => null])
@php
    $fallbackInitials = ($initials !== null && $initials !== '')
        ? $initials
        : (collect(explode(' ', trim((string) $name)))
            ->filter()
            ->take(2)
            ->map(fn ($w) => mb_strtoupper(mb_substr($w, 0, 1)))
            ->implode('') ?: 'M');

    $avatarSrc = $avatarUrl
        ? (\Illuminate\Support\Str::startsWith($avatarUrl, ['http://', 'https://'])
            ? $avatarUrl
            : asset('storage/' . ltrim($avatarUrl, '/')))
        : null;
@endphp
@if ($avatarSrc)
    <img src="{{ $avatarSrc }}" alt="Foto {{ $name }}"
         style="width:100%;height:100%;border-radius:inherit;object-fit:cover;display:block;">
@else
    {{ $fallbackInitials }}
@endif
