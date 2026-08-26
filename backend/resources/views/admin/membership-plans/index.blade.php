@extends('admin.layouts.app')

@php
    $title = 'Paket Membership - EggGym Admin';
    $pageHeading = 'Paket Membership';
    $pageSubheading = 'Kelola paket membership: harga, durasi, benefit, dan status.';

    // Data paket real untuk mengisi form create/edit secara client-side.
    $plansData = $plans->map(function ($p) {
        return [
            'id' => $p->id,
            'name' => $p->name,
            'price' => (float) $p->price,
            'duration_days' => (int) ($p->duration_days ?? 30),
            // Tanggal yang sudah lewat dianggap sudah rilis. Form edit menampilkan
            // kosong agar save berikutnya menyimpan null, bukan tanggal invalid.
            'release_date' => $p->effective_status === 'upcoming' ? $p->release_date?->toDateString() : null,
            'is_active' => (bool) $p->is_active,
            'features' => $p->features_json ?? [],
            'active_members' => (int) ($p->active_members_count ?? 0),
        ];
    })->values();

    // Master daftar benefit (union dari semua paket) untuk checklist config.
    $masterBenefits = $plans->flatMap(fn ($p) => $p->features_json ?? [])
        ->map(fn ($b) => trim((string) $b))->filter()->unique()->values();
    $benefitDisplayLabels = \App\Models\MembershipPlan::benefitDisplayLabels();
    $minimumReleaseDate = now()->addDay()->toDateString();
@endphp

@section('content')
    <style>
        .pkg-header { display: flex; justify-content: flex-end; align-items: center; margin-bottom: 14px; }

        /* KPI CARDS */
        .pkg-kpi { display: grid; grid-template-columns: repeat(4, 1fr); gap: 16px; margin-bottom: 20px; }
        .kpi-card {
            position: relative; background: var(--panel); border: 1px solid var(--border);
            border-radius: 10px; padding: 18px 20px; box-shadow: var(--shadow-card); overflow: hidden;
        }
        .kpi-card__label { font-size: 11px; font-weight: 700; letter-spacing: 2px; text-transform: uppercase; color: var(--muted); }
        .kpi-card__value { font-size: 32px; font-weight: 800; color: var(--text); line-height: 1; margin-top: 8px; }
        .kpi-card__sub { font-size: 12px; margin-top: 6px; color: var(--muted); }
        .kpi-card__sub.is-positive { color: #22C55E; }
        .kpi-card__icon { position: absolute; top: 16px; right: 18px; font-size: 20px; opacity: 0.2; }
        .kpi-card--featured { background: var(--accent); border: 0; box-shadow: 0 4px 16px rgba(250,204,21,0.25); }
        .kpi-card--featured .kpi-card__label { color: rgba(26,21,0,0.7); }
        .kpi-card--featured .kpi-card__value { font-size: 30px; color: var(--on-accent); }
        .kpi-card--featured .kpi-card__sub { color: rgba(26,21,0,0.6); }
        .kpi-card--featured .kpi-card__icon { color: var(--on-accent); opacity: 0.6; }

        /* PACKAGE CARDS GRID */
        .pkg-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 16px; margin-bottom: 20px; }
        .pkg-card {
            background: var(--panel); border: 1px solid var(--border); border-radius: 10px;
            overflow: hidden; box-shadow: var(--shadow-card); display: flex; flex-direction: column;
            transition: border-color 0.2s ease, box-shadow 0.2s ease;
        }
        .pkg-card:hover { border-color: rgba(250,204,21,0.4); box-shadow: var(--shadow-hover); }
        .pkg-card.is-selected { border-color: var(--accent); box-shadow: 0 0 0 1px var(--accent); }
        .pkg-card__head { background: var(--bg); padding: 16px 20px; }
        .pkg-card__badge-row { display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px; }
        .pkg-badge { font-size: 10px; font-weight: 700; letter-spacing: 1px; text-transform: uppercase; padding: 3px 10px; border-radius: 4px; }
        .pkg-badge-aktif { background: rgba(76,175,80,0.15); color: #22C55E; }
        .pkg-badge-nonaktif { background: rgba(107,114,128,0.15); color: #6B7280; }
        .pkg-badge-upcoming { background: rgba(245,158,11,0.16); color: #F59E0B; }
        .pkg-members { font-size: 10px; color: var(--muted); }
        .pkg-card__name { font-size: 20px; font-weight: 700; color: var(--text); margin-bottom: 6px; }
        .pkg-card__price { font-size: 28px; font-weight: 800; color: var(--accent); letter-spacing: -0.5px; }
        .pkg-card__release { margin-top: 8px; color: #F59E0B; font-size: 11px; font-weight: 700; }
        .pkg-card__body { padding: 14px 20px; display: flex; flex-direction: column; gap: 8px; flex: 1; }
        .pkg-benefit { display: flex; align-items: flex-start; gap: 10px; }
        .pkg-benefit__check { color: var(--accent); flex-shrink: 0; font-size: 14px; line-height: 1.5; }
        .pkg-benefit__text { font-size: 13px; color: var(--text); line-height: 1.5; }
        .pkg-benefit__empty { font-size: 13px; color: var(--text-muted); }
        .pkg-card__foot { padding: 12px 16px; border-top: 1px solid var(--border); display: flex; gap: 9px; }
        .pkg-card__foot form { margin: 0; flex: 0 0 auto; }
        .pkg-action-edit, .pkg-action-delete {
            height: 38px; border: 0; border-radius: 8px; display: inline-flex;
            align-items: center; justify-content: center; cursor: pointer;
            transition: background 0.15s ease, color 0.15s ease, transform 0.15s ease;
        }
        .pkg-action-edit {
            flex: 1; min-width: 0; padding: 0 20px; background: #303030; color: var(--text-secondary);
            font-size: 11px; font-weight: 800; letter-spacing: 1.2px;
        }
        .pkg-action-edit:hover { background: #3A3A3A; color: var(--accent); }
        .pkg-action-delete { width: 42px; background: #7F1D1D; color: #FFFFFF; font-size: 17px; }
        .pkg-action-delete:hover { background: #991B1B; transform: translateY(-1px); }
        .pkg-action-edit:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }
        .pkg-action-delete:focus-visible { outline: 2px solid #FCA5A5; outline-offset: 2px; }

        /* CREATE / EDIT PANEL (hidden until explicitly opened) */
        .pkg-edit-slot { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 16px; }
        .pkg-config { grid-column: 1 / span 2; width: 100%; margin: 0; border-radius: 10px; border: 1px solid var(--border); padding: 24px; background: var(--panel); display: flex; flex-direction: column; gap: 14px; }
        .pkg-config[hidden] { display: none; }
        .pkg-panel__title { font-size: 14px; font-weight: 700; color: var(--text); }
        .pkg-panel__context { font-size: 12px; color: var(--muted); margin-top: -8px; }
        .pkg-field-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 14px 16px; }
        .pkg-grid-full { grid-column: 1 / -1; }
        .pkg-field label { display: block; font-size: 11px; font-weight: 600; letter-spacing: 1px; text-transform: uppercase; color: var(--muted); margin-bottom: 6px; }
        .pkg-field input, .pkg-field select {
            width: 100%; height: 38px; background: var(--bg); border: 1px solid var(--border);
            border-radius: 8px; padding: 0 12px; font-size: 13px; color: var(--text);
        }
        .pkg-field input.is-price { color: var(--accent); font-weight: 700; }
        .pkg-field input:focus, .pkg-field select:focus { outline: none; border-color: var(--accent); }
        .pkg-field-help { margin-top: 6px; color: var(--text-muted); font-size: 10px; line-height: 1.45; }
        .pkg-field .err { font-size: 11px; color: var(--danger); margin-top: 4px; display: none; }
        .pkg-field.has-error input { border-color: var(--danger); }
        .pkg-field.has-error .err { display: block; }

        .pkg-toggle-field { display: flex; flex-direction: column; justify-content: flex-end; }
        .pkg-toggle-field__label { display: block; font-size: 11px; font-weight: 600; letter-spacing: 1px; text-transform: uppercase; color: var(--muted); margin-bottom: 6px; }
        .pkg-toggle-row { min-height: 38px; padding: 0 12px; display: flex; justify-content: space-between; align-items: center; background: var(--bg); border: 1px solid var(--border); border-radius: 8px; }
        .pkg-toggle-row span { font-size: 12px; font-weight: 600; color: var(--text); }
        .pkg-toggle { width: 48px; height: 24px; border-radius: 12px; background: #353534; position: relative; cursor: pointer; transition: background 0.2s ease; border: 0; padding: 0; }
        .pkg-toggle__knob { position: absolute; top: 3px; left: 3px; width: 18px; height: 18px; border-radius: 50%; background: var(--muted); transition: transform 0.2s ease, background 0.2s ease; }
        .pkg-toggle.is-on { background: rgba(250,204,21,0.3); }
        .pkg-toggle.is-on .pkg-toggle__knob { background: var(--accent); transform: translateX(24px); box-shadow: 0 0 6px rgba(250,204,21,0.4); }
        .pkg-toggle:disabled { cursor: not-allowed; opacity: 0.45; background: #353534; }
        .pkg-toggle:disabled .pkg-toggle__knob { background: var(--text-muted); box-shadow: none; }

        .pkg-benefit-list {
            display: grid; grid-template-columns: repeat(auto-fit, minmax(170px, 1fr));
            gap: 9px; max-height: 230px; overflow-y: auto; padding: 2px 4px 2px 2px;
        }
        .pkg-check-item {
            min-height: 48px; display: flex; align-items: center; gap: 10px; text-align: left;
            padding: 10px 12px; border-radius: 9px; border: 1px solid var(--border);
            background: var(--bg); color: var(--muted); cursor: pointer;
            transition: border-color 0.15s ease, background 0.15s ease, color 0.15s ease;
        }
        .pkg-benefit-option { position: relative; min-width: 0; }
        .pkg-benefit-option .pkg-check-item { width: 100%; padding-right: 38px; }
        .pkg-benefit-remove {
            position: absolute; top: 50%; right: 9px; transform: translateY(-50%);
            width: 23px; height: 23px; border-radius: 6px; border: 0; background: transparent;
            color: var(--text-muted); cursor: pointer; font-size: 15px; line-height: 1;
        }
        .pkg-benefit-remove:hover { color: var(--danger); background: rgba(239,68,68,0.12); }
        .pkg-benefit-remove:focus-visible { outline: 2px solid var(--danger); outline-offset: 1px; }
        .pkg-check-item:hover { border-color: rgba(250,204,21,0.55); color: var(--text); }
        .pkg-check-item:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }
        .pkg-check-item.is-checked {
            border-color: var(--accent); background: rgba(250,204,21,0.10); color: var(--text);
            box-shadow: inset 0 0 0 1px rgba(250,204,21,0.12);
        }
        .pkg-check-box {
            width: 18px; height: 18px; border-radius: 5px; border: 1px solid #514A37;
            flex-shrink: 0; display: inline-flex; align-items: center; justify-content: center;
            font-size: 11px; font-weight: 900; color: var(--on-accent); background: #222;
        }
        .pkg-check-item.is-checked .pkg-check-box { background: var(--accent); border-color: var(--accent); }
        .pkg-check-label { font-size: 12px; line-height: 1.35; color: inherit; font-weight: 600; }
        .pkg-benefit-custom {
            margin-top: 12px; padding-top: 12px; border-top: 1px solid var(--border);
        }
        .pkg-benefit-custom__label {
            display: block; margin-bottom: 7px; color: var(--text-muted); font-size: 10px;
            font-weight: 600; letter-spacing: 0.7px; text-transform: uppercase;
        }
        .pkg-add-benefit { display: flex; gap: 8px; }
        .pkg-add-benefit input { flex: 1; min-width: 0; height: 36px; }

        .pkg-actions { display: flex; justify-content: flex-end; gap: 10px; margin-top: 4px; }
        .btn-discard { background: transparent; border: 1px solid var(--border); color: var(--muted); border-radius: 8px; padding: 9px 20px; font-size: 13px; font-weight: 500; cursor: pointer; }
        .btn-discard:hover { color: var(--text); border-color: var(--text-muted); }

        .pkg-modal {
            position: fixed; inset: 0; z-index: 1000; display: flex; align-items: center;
            justify-content: center; padding: 24px; background: rgba(0,0,0,0.76); backdrop-filter: blur(4px);
        }
        .pkg-modal[hidden] { display: none; }
        .pkg-modal__dialog {
            width: min(860px, 100%); max-height: calc(100vh - 48px); overflow-y: auto;
            background: var(--panel); border: 1px solid var(--border); border-radius: 12px;
            box-shadow: 0 24px 60px rgba(0,0,0,0.45); padding: 24px;
        }
        .pkg-modal__head { display: flex; justify-content: space-between; align-items: flex-start; gap: 16px; margin-bottom: 18px; }
        .pkg-modal__close { border: 0; background: transparent; color: var(--muted); font-size: 24px; cursor: pointer; }

        @media (max-width: 1024px) {
            .pkg-kpi { grid-template-columns: 1fr 1fr; }
            .pkg-grid { grid-template-columns: 1fr 1fr; }
            .pkg-edit-slot { grid-template-columns: 1fr 1fr; }
            .pkg-config { grid-column: 1 / -1; }
        }
        @media (max-width: 640px) {
            .pkg-kpi, .pkg-grid { grid-template-columns: 1fr; }
            .pkg-edit-slot { grid-template-columns: 1fr; }
            .pkg-field-grid { grid-template-columns: 1fr; }
            .pkg-benefit-list { grid-template-columns: 1fr 1fr; max-height: 280px; }
            .pkg-add-benefit { flex-direction: column; }
            .pkg-add-benefit .btn { width: 100%; }
        }
        @media (max-width: 420px) {
            .pkg-benefit-list { grid-template-columns: 1fr; }
        }
    </style>

    @if (session('error'))
        <div class="flash" style="background: rgba(239,68,68,0.12); border-color: rgba(239,68,68,0.3); color: #f2a3a3;">
            {{ session('error') }}
        </div>
    @endif

    {{-- (1) PAGE HEADER --}}
    <div class="pkg-header">
        <button type="button" class="btn btn-primary" onclick="pkgNewPackage()">+ TAMBAH PAKET</button>
    </div>

    {{-- (2) KPI CARDS --}}
    <div class="pkg-kpi">
        <div class="kpi-card">
            <div class="kpi-card__label">Total Paket Aktif</div>
            <div class="kpi-card__value">{{ $kpi['total_active'] }}</div>
            <div class="kpi-card__sub">Paket berstatus aktif</div>
        </div>
        <div class="kpi-card">
            <div class="kpi-card__label">Revenue Bulan Ini</div>
            <div class="kpi-card__value">{{ $kpi['revenue_label'] }}</div>
            <div class="kpi-card__sub {{ $kpi['revenue_delta'] !== null && $kpi['revenue_delta'] >= 0 ? 'is-positive' : '' }}">
                {{ $kpi['revenue_delta_label'] }}
                @if($kpi['revenue_unknown_count'] > 0)
                    <br>{{ $kpi['revenue_unknown_count'] }} transaksi tanpa data fee tidak dihitung
                @endif
            </div>
        </div>
        <div class="kpi-card">
            <div class="kpi-card__label">Rata-rata Masa Aktif</div>
            <div class="kpi-card__value">{{ $kpi['average_active_label'] }}</div>
            <div class="kpi-card__sub">Rata-rata durasi membership aktif</div>
        </div>
        <div class="kpi-card kpi-card--featured">
            <div class="kpi-card__icon">&#9733;</div>
            <div class="kpi-card__label">Paket Terpopuler</div>
            <div class="kpi-card__value">{{ $kpi['popular_plan'] }}</div>
            <div class="kpi-card__sub">Berdasarkan penjualan bulan ini</div>
        </div>
    </div>

    {{-- (3) PACKAGE CARDS GRID --}}
    <div class="pkg-grid">
        @forelse ($plans as $plan)
            @php
                $activeMembers = (int) ($plan->active_members_count ?? 0);
                $effectiveStatus = $plan->effective_status;
                $statusLabel = match ($effectiveStatus) { 'upcoming' => 'Upcoming', 'active' => 'Aktif', default => 'Nonaktif' };
                $statusClass = match ($effectiveStatus) { 'upcoming' => 'pkg-badge-upcoming', 'active' => 'pkg-badge-aktif', default => 'pkg-badge-nonaktif' };
            @endphp
            <div class="pkg-card" data-plan-id="{{ $plan->id }}">
                <div class="pkg-card__head">
                    <div class="pkg-card__badge-row">
                        <span class="pkg-badge {{ $statusClass }}">
                            {{ $statusLabel }}
                        </span>
                        @if ($activeMembers > 0)
                            <span class="pkg-members">{{ $activeMembers }} member aktif</span>
                        @endif
                    </div>
                    <div class="pkg-card__name">{{ $plan->name }}</div>
                    <div class="pkg-card__price">Rp {{ number_format((float) $plan->price, 0, ',', '.') }}</div>
                    @if ($effectiveStatus === 'upcoming' && $plan->release_date)
                        <div class="pkg-card__release">Akan rilis: {{ $plan->release_date->locale('id')->translatedFormat('d F Y') }}</div>
                    @endif
                </div>
                <div class="pkg-card__body">
                    @forelse (($plan->features_json ?? []) as $benefit)
                        <div class="pkg-benefit">
                            <span class="pkg-benefit__check">&#10003;</span>
                            <span class="pkg-benefit__text">{{ \App\Models\MembershipPlan::benefitDisplayLabel((string) $benefit) }}</span>
                        </div>
                    @empty
                        <div class="pkg-benefit__empty">Belum ada benefit terdaftar.</div>
                    @endforelse
                </div>
                <div class="pkg-card__foot">
                    <button type="button" class="pkg-action-edit" title="Edit paket {{ $plan->name }}"
                        onclick="pkgEditPackage({{ $plan->id }})">EDIT</button>
                    <form method="POST" action="{{ route('admin.membership-plans.destroy', $plan) }}"
                        onsubmit="return confirm('Hapus paket membership {{ $plan->name }}?\n\nPaket akan dinonaktifkan dan tidak dapat dibeli lagi. Histori membership dan transaksi lama tetap tersimpan.');">
                        @csrf
                        @method('DELETE')
                        <button type="submit" class="pkg-action-delete" title="Hapus paket {{ $plan->name }}" aria-label="Hapus paket {{ $plan->name }}">&#128465;</button>
                    </form>
                </div>
            </div>
        @empty
            <div class="panel" style="grid-column: 1 / -1; text-align: center; color: var(--muted);">
                {{ $search !== '' ? 'Tidak ada data yang cocok.' : 'Belum ada paket membership. Klik "+ TAMBAH PAKET" untuk membuat.' }}
            </div>
        @endforelse
    </div>

    {{-- (4) EDIT PANEL: spans the first two package-grid columns --}}
    <div class="pkg-edit-slot">
        <form class="pkg-config" id="pkgConfigForm" method="POST" action="{{ route('admin.membership-plans.store') }}" hidden>
            @csrf
            <input type="hidden" name="_method" id="pkgMethod" value="PUT">
            <input type="hidden" name="features_text" id="pkgFeaturesText">
            <input type="hidden" name="is_active" id="pkgIsActive" value="1">

            <div class="pkg-panel__title" id="pkgFormTitle">Edit Paket Membership</div>
            <div class="pkg-panel__context" id="pkgFormContext">Pilih card paket yang ingin diubah.</div>

            <div class="pkg-field-grid">
                <div class="pkg-field" id="pkgNameField">
                    <label for="pkgName">Nama Paket</label>
                    <input type="text" id="pkgName" name="name" placeholder="Contoh: 30 Days Elite" oninput="pkgMarkDirty()">
                    <div class="err" id="pkgNameErr">Nama wajib diisi & tidak boleh sama dengan paket lain.</div>
                </div>

                <div class="pkg-field" id="pkgPriceField">
                    <label for="pkgPrice">Harga (IDR)</label>
                    <input type="number" id="pkgPrice" name="price" class="is-price" min="1" placeholder="7200000" oninput="pkgMarkDirty()">
                    <div class="err" id="pkgPriceErr">Harga harus lebih dari 0.</div>
                </div>

                <div class="pkg-field" id="pkgDurationField">
                    <label for="pkgDuration">Durasi (Hari)</label>
                    <input type="number" id="pkgDuration" name="duration_days" min="1" placeholder="365" oninput="pkgMarkDirty()">
                    <div class="err" id="pkgDurationErr">Durasi harus lebih dari 0 hari.</div>
                </div>

                <div class="pkg-field" id="pkgReleaseField">
                    <label for="pkgReleaseDate">Tanggal Rilis</label>
                    <input type="date" id="pkgReleaseDate" name="release_date" min="{{ $minimumReleaseDate }}" onchange="pkgHandleReleaseDateChange()">
                    <div class="pkg-field-help">Tanggal rilis opsional untuk paket Upcoming. Kosongkan jika paket ingin langsung aktif sesuai Status Aktif.</div>
                    <div class="err">Tanggal rilis harus lebih besar dari hari ini.</div>
                </div>

                <div class="pkg-toggle-field pkg-grid-full">
                    <div class="pkg-toggle-row">
                        <span>Status Aktif</span>
                        <button type="button" class="pkg-toggle is-on" id="pkgToggle" role="switch" aria-label="Status aktif paket" aria-checked="true" onclick="pkgToggleStatus()">
                            <span class="pkg-toggle__knob"></span>
                        </button>
                    </div>
                </div>
            </div>

            <div class="pkg-field" id="pkgBenefitsField">
                <label>Benefit Items</label>
                <div class="pkg-benefit-list" id="pkgBenefitList"></div>
                <div class="pkg-benefit-custom">
                    <span class="pkg-benefit-custom__label">Benefit custom</span>
                    <div class="pkg-add-benefit">
                        <input type="text" id="pkgNewBenefit" placeholder="Tulis benefit tambahan..."
                            onkeydown="if (event.key === 'Enter') { event.preventDefault(); pkgAddBenefit(); }">
                        <button type="button" class="btn btn-secondary" onclick="pkgAddBenefit()">+ Tambah</button>
                    </div>
                </div>
                <div class="err" id="pkgBenefitErr" style="{{ '' }}">Minimal 1 benefit harus dipilih.</div>
            </div>

            <div class="pkg-actions">
                <button type="button" class="btn-discard" onclick="pkgDiscard()">Discard</button>
                <button type="submit" class="btn btn-primary" id="pkgSubmitLabel" onclick="return pkgValidate()">Save Changes</button>
            </div>
        </form>
    </div>

    <div class="pkg-modal" id="pkgCreateModal" role="dialog" aria-modal="true" aria-labelledby="pkgCreateTitle" hidden>
        <form class="pkg-modal__dialog" id="pkgCreateForm" method="POST" action="{{ route('admin.membership-plans.store') }}">
            @csrf
            <input type="hidden" name="features_text" id="pkgCreateFeaturesText">
            <input type="hidden" name="is_active" id="pkgCreateIsActive" value="1">
            <div class="pkg-modal__head">
                <div>
                    <div class="pkg-panel__title" id="pkgCreateTitle">Tambah Paket Baru</div>
                    <div class="pkg-panel__context" style="margin-top:4px;">Isi data paket membership yang akan ditambahkan.</div>
                </div>
                <button type="button" class="pkg-modal__close" onclick="pkgCloseCreateModal()" aria-label="Tutup modal">&times;</button>
            </div>
            <div class="pkg-field-grid">
                <div class="pkg-field" id="pkgCreateNameField"><label for="pkgCreateName">Nama Paket</label><input type="text" id="pkgCreateName" name="name" required></div>
                <div class="pkg-field" id="pkgCreatePriceField"><label for="pkgCreatePrice">Harga (IDR)</label><input type="number" id="pkgCreatePrice" name="price" class="is-price" min="1" required></div>
                <div class="pkg-field" id="pkgCreateDurationField"><label for="pkgCreateDuration">Durasi (Hari)</label><input type="number" id="pkgCreateDuration" name="duration_days" min="1" required></div>
                <div class="pkg-field" id="pkgCreateReleaseField"><label for="pkgCreateReleaseDate">Tanggal Rilis</label><input type="date" id="pkgCreateReleaseDate" name="release_date" min="{{ $minimumReleaseDate }}" onchange="pkgHandleCreateReleaseDateChange()"><div class="pkg-field-help">Tanggal rilis opsional untuk paket Upcoming. Kosongkan jika paket ingin langsung aktif sesuai Status Aktif.</div><div class="err">Tanggal rilis harus lebih besar dari hari ini.</div></div>
                <div class="pkg-toggle-field pkg-grid-full">
                    <div class="pkg-toggle-row">
                        <span>Status Aktif</span>
                        <button type="button" class="pkg-toggle is-on" id="pkgCreateToggle" role="switch" aria-label="Status aktif paket baru" aria-checked="true" onclick="pkgToggleCreateStatus()"><span class="pkg-toggle__knob"></span></button>
                    </div>
                </div>
            </div>
            <div class="pkg-field" id="pkgCreateBenefitsField" style="margin-top:14px;">
                <label>Benefit Items</label>
                <div class="pkg-benefit-list" id="pkgCreateBenefitList"></div>
                <div class="pkg-benefit-custom">
                    <span class="pkg-benefit-custom__label">Benefit custom</span>
                    <div class="pkg-add-benefit">
                        <input type="text" id="pkgCreateNewBenefit" placeholder="Tulis benefit tambahan..." onkeydown="if(event.key==='Enter'){event.preventDefault();pkgAddCreateBenefit();}">
                        <button type="button" class="btn btn-secondary" onclick="pkgAddCreateBenefit()">+ Tambah</button>
                    </div>
                </div>
            </div>
            <div class="pkg-actions" style="margin-top:18px;">
                <button type="button" class="btn-discard" onclick="pkgCloseCreateModal()">Batal</button>
                <button type="submit" class="btn btn-primary" onclick="return pkgValidateCreate()">Simpan Paket</button>
            </div>
        </form>
    </div>

    <script>
        const PKG_PLANS = @json($plansData);
        const PKG_MASTER_BENEFITS = @json($masterBenefits);
        const PKG_BENEFIT_LABELS = @json($benefitDisplayLabels);
        const PKG_BASE_URL = "{{ url('admin/membership-plans') }}";
        const PKG_MIN_RELEASE_DATE = "{{ $minimumReleaseDate }}";

        let pkgBenefits = [];      // {label, checked}
        let pkgStatusOn = true;
        let pkgDirty = false;
        let pkgSelectedPlanId = null;
        let pkgCreateBenefits = [];
        let pkgCreateStatusOn = true;

        function pkgRenderBenefits() {
            pkgRenderBenefitGrid('pkgBenefitList', pkgBenefits, (index) => {
                pkgBenefits[index].checked = !pkgBenefits[index].checked;
                pkgMarkDirty();
                pkgRenderBenefits();
            }, (index) => pkgRemoveBenefit(index));
        }

        function pkgRenderCreateBenefits() {
            pkgRenderBenefitGrid('pkgCreateBenefitList', pkgCreateBenefits, (index) => {
                pkgCreateBenefits[index].checked = !pkgCreateBenefits[index].checked;
                pkgRenderCreateBenefits();
            }, (index) => pkgRemoveCreateBenefit(index));
        }

        function pkgRenderBenefitGrid(targetId, benefits, onToggle, onRemove) {
            const wrap = document.getElementById(targetId);
            wrap.replaceChildren();
            benefits.forEach((b, i) => {
                const option = document.createElement('div');
                option.className = 'pkg-benefit-option';
                const item = document.createElement('button');
                item.type = 'button';
                item.className = 'pkg-check-item' + (b.checked ? ' is-checked' : '');
                item.setAttribute('aria-pressed', b.checked ? 'true' : 'false');
                const displayLabel = pkgBenefitDisplayLabel(b.label);
                item.setAttribute('aria-label', (b.checked ? 'Batalkan pilihan ' : 'Pilih ') + displayLabel);
                item.onclick = () => onToggle(i);
                item.innerHTML = '<span class="pkg-check-box">' + (b.checked ? '&#10003;' : '') + '</span>' +
                    '<span class="pkg-check-label">' + pkgEscape(displayLabel) + '</span>';
                const remove = document.createElement('button');
                remove.type = 'button';
                remove.className = 'pkg-benefit-remove';
                remove.setAttribute('aria-label', 'Hapus benefit ' + displayLabel);
                remove.title = 'Hapus benefit dari form ini';
                remove.textContent = '×';
                remove.onclick = (event) => { event.stopPropagation(); onRemove(i); };
                option.append(item, remove);
                wrap.appendChild(option);
            });
        }

        function pkgConfirmBenefitRemoval(label) {
            return confirm('Hapus benefit "' + pkgBenefitDisplayLabel(label) + '" dari daftar form ini?\n\nPerubahan hanya berlaku pada paket yang sedang disimpan. Paket lain tidak ikut diubah.');
        }

        function pkgRemoveBenefit(index) {
            const benefit = pkgBenefits[index];
            if (!benefit || !pkgConfirmBenefitRemoval(benefit.label)) return;
            pkgBenefits.splice(index, 1);
            pkgMarkDirty();
            pkgRenderBenefits();
        }

        function pkgRemoveCreateBenefit(index) {
            const benefit = pkgCreateBenefits[index];
            if (!benefit || !pkgConfirmBenefitRemoval(benefit.label)) return;
            pkgCreateBenefits.splice(index, 1);
            pkgRenderCreateBenefits();
        }

        function pkgAddBenefit() {
            const input = document.getElementById('pkgNewBenefit');
            const val = (input.value || '').trim();
            if (!val) return;
            if (!pkgBenefits.some(b => b.label.toLowerCase() === val.toLowerCase())) {
                pkgBenefits.push({ label: val, checked: true });
            }
            input.value = '';
            pkgMarkDirty(); pkgRenderBenefits();
        }

        function pkgToggleStatus() {
            if (document.getElementById('pkgToggle').disabled) return;
            pkgStatusOn = !pkgStatusOn;
            const t = document.getElementById('pkgToggle');
            t.classList.toggle('is-on', pkgStatusOn);
            t.setAttribute('aria-checked', pkgStatusOn ? 'true' : 'false');
            document.getElementById('pkgIsActive').value = pkgStatusOn ? '1' : '0';
            pkgMarkDirty();
        }

        function pkgToggleCreateStatus() {
            if (document.getElementById('pkgCreateToggle').disabled) return;
            pkgCreateStatusOn = !pkgCreateStatusOn;
            const toggle = document.getElementById('pkgCreateToggle');
            toggle.classList.toggle('is-on', pkgCreateStatusOn);
            toggle.setAttribute('aria-checked', pkgCreateStatusOn ? 'true' : 'false');
            document.getElementById('pkgCreateIsActive').value = pkgCreateStatusOn ? '1' : '0';
        }

        function pkgSetForm(plan) {
            pkgSelectedPlanId = plan ? plan.id : null;
            document.getElementById('pkgName').value = plan ? plan.name : '';
            document.getElementById('pkgPrice').value = plan ? plan.price : '';
            document.getElementById('pkgDuration').value = plan ? plan.duration_days : '';
            document.getElementById('pkgReleaseDate').value = plan ? (plan.release_date || '') : '';
            pkgStatusOn = plan ? plan.is_active : true;
            const t = document.getElementById('pkgToggle');
            t.classList.toggle('is-on', pkgStatusOn);
            t.setAttribute('aria-checked', pkgStatusOn ? 'true' : 'false');
            document.getElementById('pkgIsActive').value = pkgStatusOn ? '1' : '0';
            pkgSyncScheduledStatus(false);

            // Benefit list = master benefits, tandai yang dimiliki paket ini.
            const owned = plan ? plan.features.map(f => (f || '').toLowerCase()) : [];
            pkgBenefits = PKG_MASTER_BENEFITS.map(b => ({ label: b, checked: owned.includes(b.toLowerCase()) }));
            // Benefit khusus paket ini yang belum ada di master.
            if (plan) {
                plan.features.forEach(f => {
                    if (!pkgBenefits.some(b => b.label.toLowerCase() === (f || '').toLowerCase())) {
                        pkgBenefits.push({ label: f, checked: true });
                    }
                });
            }
            pkgRenderBenefits();

            // Set action + method.
            const form = document.getElementById('pkgConfigForm');
            const methodInput = document.getElementById('pkgMethod');
            form.action = PKG_BASE_URL + '/' + plan.id;
            methodInput.value = 'PUT';
            document.getElementById('pkgFormContext').textContent = 'Mengubah paket: ' + plan.name;
            form.hidden = false;
            document.querySelectorAll('.pkg-card[data-plan-id]').forEach(card => {
                card.classList.toggle('is-selected', plan && String(card.dataset.planId) === String(plan.id));
            });
            pkgDirty = false;
        }

        function pkgEditPackage(id) {
            const form = document.getElementById('pkgConfigForm');
            if (String(pkgSelectedPlanId) === String(id) && !form.hidden) {
                pkgCloseEditPanel();
                return;
            }
            const plan = PKG_PLANS.find(p => String(p.id) === String(id));
            if (!plan) return;
            pkgSetForm(plan);
            form.scrollIntoView({ behavior: 'smooth', block: 'center' });
        }

        function pkgNewPackage() {
            pkgCreateBenefits = PKG_MASTER_BENEFITS.map(label => ({ label, checked: false }));
            pkgCreateStatusOn = true;
            document.getElementById('pkgCreateForm').reset();
            document.getElementById('pkgCreateIsActive').value = '1';
            const toggle = document.getElementById('pkgCreateToggle');
            toggle.classList.add('is-on');
            toggle.setAttribute('aria-checked', 'true');
            pkgSyncScheduledStatus(true);
            pkgRenderCreateBenefits();
            document.getElementById('pkgCreateModal').hidden = false;
            document.body.style.overflow = 'hidden';
            setTimeout(() => document.getElementById('pkgCreateName').focus(), 0);
        }

        function pkgCloseCreateModal() {
            document.getElementById('pkgCreateModal').hidden = true;
            document.body.style.overflow = '';
        }

        function pkgHandleReleaseDateChange() {
            pkgSyncScheduledStatus(false);
            pkgMarkDirty();
        }

        function pkgHandleCreateReleaseDateChange() {
            pkgSyncScheduledStatus(true);
        }

        function pkgSyncScheduledStatus(isCreate) {
            const prefix = isCreate ? 'pkgCreate' : 'pkg';
            const releaseDate = document.getElementById(prefix + 'ReleaseDate').value;
            const toggle = document.getElementById(prefix + 'Toggle');
            const hidden = document.getElementById(prefix + 'IsActive');
            const scheduled = releaseDate !== '';

            toggle.disabled = scheduled;
            toggle.title = scheduled ? 'Status aktif dikunci selama paket dijadwalkan rilis.' : '';
            if (scheduled) {
                if (isCreate) pkgCreateStatusOn = true;
                else pkgStatusOn = true;
                toggle.classList.add('is-on');
                toggle.setAttribute('aria-checked', 'true');
                hidden.value = '1';
            }
        }

        function pkgBenefitDisplayLabel(label) {
            return PKG_BENEFIT_LABELS[label] || label;
        }

        function pkgAddCreateBenefit() {
            const input = document.getElementById('pkgCreateNewBenefit');
            const value = (input.value || '').trim();
            if (!value) return;
            const existing = pkgCreateBenefits.find(item => item.label.toLowerCase() === value.toLowerCase());
            if (existing) existing.checked = true;
            else pkgCreateBenefits.push({ label: value, checked: true });
            input.value = '';
            pkgRenderCreateBenefits();
        }

        function pkgMarkDirty() { pkgDirty = true; }

        function pkgDiscard() {
            if (pkgDirty && !confirm('Buang perubahan yang belum disimpan?')) return;
            pkgCloseEditPanel();
        }

        function pkgCloseEditPanel() {
            pkgSelectedPlanId = null;
            pkgDirty = false;
            document.getElementById('pkgConfigForm').hidden = true;
            document.querySelectorAll('.pkg-card[data-plan-id]').forEach(card => card.classList.remove('is-selected'));
        }

        function pkgEscape(s) {
            const d = document.createElement('div'); d.textContent = s; return d.innerHTML;
        }

        function pkgValidate() {
            let ok = true;
            const name = document.getElementById('pkgName').value.trim();
            const price = parseFloat(document.getElementById('pkgPrice').value) || 0;
            const days = parseInt(document.getElementById('pkgDuration').value) || 0;
            const releaseDate = document.getElementById('pkgReleaseDate').value;
            const selectedId = pkgSelectedPlanId;

            // Sinkronkan benefit terpilih ke hidden field.
            const chosen = pkgBenefits.filter(b => b.checked).map(b => b.label);
            document.getElementById('pkgFeaturesText').value = chosen.join('\n');

            const dupName = PKG_PLANS.some(p => p.name.toLowerCase() === name.toLowerCase() && String(p.id) !== String(selectedId));
            pkgToggleError('pkgNameField', name === '' || dupName);
            pkgToggleError('pkgPriceField', price <= 0);
            pkgToggleError('pkgDurationField', days <= 0);
            pkgToggleError('pkgReleaseField', releaseDate !== '' && releaseDate < PKG_MIN_RELEASE_DATE);
            pkgToggleError('pkgBenefitsField', chosen.length === 0);

            ok = !(name === '' || dupName || price <= 0 || days <= 0 ||
                (releaseDate !== '' && releaseDate < PKG_MIN_RELEASE_DATE) || chosen.length === 0);
            return ok;
        }

        function pkgValidateCreate() {
            const chosen = pkgCreateBenefits.filter(item => item.checked).map(item => item.label);
            document.getElementById('pkgCreateFeaturesText').value = chosen.join('\n');
            const releaseDate = document.getElementById('pkgCreateReleaseDate').value;
            const invalidReleaseDate = releaseDate !== '' && releaseDate < PKG_MIN_RELEASE_DATE;
            pkgToggleError('pkgCreateReleaseField', invalidReleaseDate);
            if (invalidReleaseDate) return false;
            if (chosen.length === 0) {
                alert('Minimal 1 benefit harus dipilih.');
                return false;
            }
            const name = document.getElementById('pkgCreateName').value.trim();
            if (PKG_PLANS.some(plan => plan.name.toLowerCase() === name.toLowerCase())) {
                alert('Nama paket sudah dipakai paket lain.');
                return false;
            }
            return true;
        }

        function pkgToggleError(fieldId, hasError) {
            document.getElementById(fieldId).classList.toggle('has-error', hasError);
        }

        // No-selection mode is authoritative on initial page load.
        document.getElementById('pkgCreateModal').addEventListener('click', (event) => {
            if (event.target.id === 'pkgCreateModal') pkgCloseCreateModal();
        });
        document.addEventListener('keydown', (event) => {
            if (event.key === 'Escape' && !document.getElementById('pkgCreateModal').hidden) pkgCloseCreateModal();
        });
    </script>
@endsection
