@extends('admin.layouts.app')

@php
    $title = 'Alat Gym - EggGym Admin';
    $pageHeading = 'Alat Gym';
    $pageSubheading = 'Kelola aset alat gym: kategori, status, dan foto.';

    $lastUpdatedMinutes = $lastUpdated ? now()->diffInMinutes($lastUpdated) : null;
@endphp

@section('content')
    <style>
        /* PAGE HEADER + WATERMARK */
        .eq-hero { position: relative; overflow: hidden; margin-bottom: 8px; padding: 4px 0 8px; }
        .eq-watermark {
            position: absolute; top: 50%; left: -8px; transform: translateY(-50%);
            font-size: 96px; font-weight: 800; letter-spacing: 0; text-transform: uppercase;
            color: rgba(255,255,255,0.03); z-index: 0; pointer-events: none; white-space: nowrap; line-height: 1;
        }
        .eq-hero__inner { position: relative; z-index: 1; display: flex; justify-content: space-between; align-items: flex-end; gap: 16px; flex-wrap: wrap; }
        .eq-supra { font-size: 11px; font-weight: 700; letter-spacing: 3px; text-transform: uppercase; color: var(--accent); margin-bottom: 8px; }
        .eq-h1 { font-size: 34px; font-weight: 800; color: var(--text); letter-spacing: -0.5px; margin: 0; }

        /* FILTER TABS */
        .eq-tabs { display: flex; gap: 10px; margin: 24px 0; flex-wrap: wrap; max-width: 100%; }
        .eq-tab {
            padding: 9px 20px; border-radius: 999px; font-size: 11px; font-weight: 700; letter-spacing: 1px;
            text-transform: uppercase; background: var(--panel); border: 1px solid var(--border); color: var(--muted);
            text-decoration: none; transition: all 0.15s ease;
        }
        .eq-tab:hover { color: var(--text); border-color: #4D4732; }
        .eq-tab.active { background: var(--accent); border-color: var(--accent); color: var(--on-accent); }

        /* CARDS GRID */
        .eq-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 24px; }
        .eq-card {
            background: var(--panel); border: 1px solid var(--border); border-radius: 10px; overflow: hidden;
            box-shadow: var(--shadow-card); display: flex; flex-direction: column; transition: transform 0.2s ease, box-shadow 0.2s ease, border-color 0.2s ease;
        }
        .eq-card:hover { transform: translateY(-4px); box-shadow: var(--shadow-hover); border-color: rgba(250,204,21,0.4); }
        .eq-card__img { position: relative; height: 200px; overflow: hidden; background: linear-gradient(135deg,#353534,#131313); display: flex; align-items: center; justify-content: center; }
        .eq-card__img img { width: 100%; height: 100%; object-fit: cover; }
        .eq-card__img-empty { font-size: 40px; opacity: 0.25; }
        .eq-id-badge { position: absolute; top: 12px; left: 12px; background: rgba(0,0,0,0.7); color: #fff; font-size: 10px; font-weight: 600; font-family: "JetBrains Mono", monospace; padding: 3px 9px; border-radius: 4px; letter-spacing: 0.5px; }
        .eq-status-badge {
            position: absolute; bottom: 12px; left: 12px; display: inline-flex; align-items: center; gap: 6px;
            font-size: 10px; font-weight: 700; letter-spacing: 0.5px; text-transform: uppercase; padding: 4px 12px; border-radius: 999px;
        }
        .eq-status-badge .dot { width: 7px; height: 7px; border-radius: 50%; }
        .eq-card__body { padding: 16px 18px; flex: 1; }
        .eq-card__cat { font-size: 10px; font-weight: 700; color: var(--muted); letter-spacing: 1.5px; text-transform: uppercase; margin-bottom: 6px; }
        .eq-card__name { font-size: 18px; font-weight: 800; color: var(--text); margin-bottom: 8px; }
        .eq-card__desc { font-size: 13px; color: var(--muted); line-height: 1.5; display: -webkit-box; -webkit-line-clamp: 3; -webkit-box-orient: vertical; overflow: hidden; }
        .eq-card__foot { padding: 12px 18px 16px; border-top: 1px solid var(--border); display: flex; justify-content: space-between; align-items: center; }
        .eq-icon-btn { width: 36px; height: 36px; border-radius: 6px; background: var(--panel-soft); border: 0; color: var(--muted); display: inline-flex; align-items: center; justify-content: center; cursor: pointer; font-size: 15px; text-decoration: none; }
        .eq-icon-btn:hover { color: var(--accent); }
        .eq-icon-btn.is-danger:hover { color: var(--danger); }
        .eq-detail-btn { font-size: 11px; font-weight: 700; color: var(--accent); letter-spacing: 1px; text-transform: uppercase; background: transparent; border: 0; cursor: pointer; text-decoration: none; }
        .eq-detail-btn:hover { color: var(--accent-hover); text-decoration: underline; }
        .eq-empty { grid-column: 1/-1; padding: 40px; text-align: center; color: var(--muted); background: var(--panel); border: 1px solid var(--border); border-radius: 10px; }

        /* BOTTOM SECTION */
        .eq-bottom { display: flex; gap: 24px; align-items: stretch; margin-top: 32px; flex-wrap: wrap; }
        .eq-summary { flex: 3; min-width: 320px; background: var(--panel); border: 1px solid var(--border); border-left: 4px solid var(--accent); border-radius: 10px; padding: 24px 28px; }
        .eq-summary__head { display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; flex-wrap: wrap; gap: 8px; }
        .eq-summary__title { font-size: 20px; font-weight: 800; color: var(--text); }
        .eq-summary__sub { font-size: 10px; font-weight: 600; color: var(--muted); letter-spacing: 1px; text-transform: uppercase; }
        .eq-stats { display: flex; gap: 48px; flex-wrap: wrap; }
        .eq-stat__num { font-size: 34px; font-weight: 800; line-height: 1; }
        .eq-stat__label { font-size: 10px; font-weight: 600; color: var(--muted); letter-spacing: 1px; text-transform: uppercase; margin-top: 6px; }

        .eq-alert { flex: 2; max-width: 300px; min-width: 240px; background: var(--accent); border-radius: 10px; padding: 24px; display: flex; flex-direction: column; }
        .eq-alert__label { font-size: 10px; font-weight: 700; color: rgba(26,21,0,0.6); letter-spacing: 2px; text-transform: uppercase; margin-bottom: 12px; }
        .eq-alert__body { font-size: 20px; font-weight: 800; color: var(--on-accent); line-height: 1.3; }
        .eq-alert__cta { align-self: flex-start; margin-top: 16px; font-size: 11px; font-weight: 700; letter-spacing: 1px; text-transform: uppercase; color: var(--on-accent); background: rgba(0,0,0,0.12); border-radius: 6px; padding: 8px 16px; text-decoration: none; }
        .eq-alert__cta:hover { background: rgba(0,0,0,0.2); }

        @media (max-width: 1024px) { .eq-grid { grid-template-columns: repeat(2, 1fr); } }
        @media (max-width: 640px) { .eq-grid { grid-template-columns: 1fr; } }
    </style>

    @if (session('success'))
        <div class="flash">{{ session('success') }}</div>
    @endif
    @if (session('error'))
        <div class="flash" style="background: rgba(239,68,68,0.12); border-color: rgba(239,68,68,0.3); color: #f2a3a3;">{{ session('error') }}</div>
    @endif

    {{-- (2) PAGE HEADER + WATERMARK --}}
    <div class="eq-hero">
        <div class="eq-watermark">EQUIPMENT</div>
        <div class="eq-hero__inner">
            <div>
                <div class="eq-supra">Elite Inventory</div>
                <h1 class="eq-h1">Manajemen Aset</h1>
            </div>
            <a href="{{ route('admin.equipments.create') }}" class="btn btn-primary">+ Tambah Alat</a>
        </div>
    </div>

    {{-- (3) FILTER TABS --}}
    <div class="eq-tabs">
        <a href="{{ route('admin.equipments.index', ['search' => $search]) }}" class="eq-tab {{ $category === '' ? 'active' : '' }}">Semua Alat</a>
        @foreach ($categories as $cat)
            <a href="{{ route('admin.equipments.index', ['category' => $cat, 'search' => $search]) }}"
                class="eq-tab {{ $category === $cat ? 'active' : '' }}">{{ $cat }}</a>
        @endforeach
        <a href="{{ route('admin.equipments.index', ['category' => $otherCategoryValue, 'search' => $search]) }}"
            class="eq-tab {{ $category === $otherCategoryValue ? 'active' : '' }}">Lainnya</a>
    </div>

    {{-- (4) CARDS GRID --}}
    <div class="eq-grid">
        @forelse ($equipments as $eq)
            @php $sm = $eq->status_meta; @endphp
            <div class="eq-card">
                <div class="eq-card__img">
                    @if (!empty($eq->image_url))
                        <img src="{{ $eq->image_url }}" alt="Foto {{ $eq->name }}" loading="lazy">
                    @else
                        <span class="eq-card__img-empty">&#127947;</span>
                    @endif
                    <span class="eq-id-badge">{{ $eq->code ?? 'EQ-000' }}</span>
                    <span class="eq-status-badge" style="background: {{ $sm['color'] }}26; border: 1px solid {{ $sm['color'] }}; color: {{ $sm['color'] }};">
                        <span class="dot" style="background: {{ $sm['color'] }};"></span>{{ strtoupper($sm['label']) }}
                    </span>
                </div>
                <div class="eq-card__body">
                    <div class="eq-card__cat">{{ $eq->category }}</div>
                    <div class="eq-card__name">{{ $eq->name }}</div>
                    <div class="eq-card__desc">{{ $eq->description }}</div>
                </div>
                <div class="eq-card__foot">
                    <div style="display: flex; gap: 8px;">
                        <a href="{{ route('admin.equipments.edit', $eq) }}" class="eq-icon-btn" title="Edit {{ $eq->name }}" aria-label="Edit {{ $eq->name }}">&#9998;</a>
                        <form method="POST" action="{{ route('admin.equipments.destroy', $eq) }}" style="margin:0;"
                            onsubmit="return confirm('Hapus alat {{ $eq->name }}?');">
                            @csrf @method('DELETE')
                            <button type="submit" class="eq-icon-btn is-danger" title="Hapus {{ $eq->name }}" aria-label="Hapus {{ $eq->name }}">&#128465;</button>
                        </form>
                    </div>
                    <a href="{{ route('admin.equipments.edit', $eq) }}" class="eq-detail-btn">Detail &gt;</a>
                </div>
            </div>
        @empty
            <div class="eq-empty">{{ $category !== '' ? 'Belum ada alat pada kategori ini.' : ($search !== '' ? 'Tidak ada data yang cocok.' : 'Belum ada alat. Klik "+ Tambah Alat" untuk menambahkan.') }}</div>
        @endforelse
    </div>

    {{-- (5)+(6) BOTTOM SECTION --}}
    <div class="eq-bottom">
        <div class="eq-summary">
            <div class="eq-summary__head">
                <div class="eq-summary__title">Ringkasan Status Alat</div>
                <div class="eq-summary__sub">
                    Pembaruan Terakhir:
                    {{ $lastUpdatedMinutes !== null ? $lastUpdatedMinutes . ' menit lalu' : '-' }}
                </div>
            </div>
            <div class="eq-stats">
                <div>
                    <div class="eq-stat__num" style="color: var(--accent);">{{ $stats['total'] }}</div>
                    <div class="eq-stat__label">Total Aset</div>
                </div>
                <div>
                    <div class="eq-stat__num" style="color: #22C55E;">{{ $stats['available'] }}</div>
                    <div class="eq-stat__label">Beroperasi</div>
                </div>
                <div>
                    <div class="eq-stat__num" style="color: var(--accent);">{{ $stats['maintenance'] }}</div>
                    <div class="eq-stat__label">Dalam Servis</div>
                </div>
                <div>
                    <div class="eq-stat__num" style="color: #EF4444;">{{ $stats['broken'] }}</div>
                    <div class="eq-stat__label">Rusak</div>
                </div>
            </div>
        </div>

        <div class="eq-alert">
            <div class="eq-alert__label">Audit Report</div>
            <div class="eq-alert__body">
                @if ($auditCount > 0)
                    Butuh inspeksi rutin untuk {{ $auditCount }} alat minggu ini.
                @else
                    Semua alat dalam kondisi baik. Tidak ada yang butuh inspeksi.
                @endif
            </div>
            <a href="{{ route('admin.audit-trail.index') }}" class="eq-alert__cta">Buka Laporan</a>
        </div>
    </div>

@endsection
