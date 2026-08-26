@extends('admin.layouts.app')

@php
    $title = 'Personal Trainer - EggGym Admin';
    $pageHeading = 'Data Personal Trainer';
    $pageSubheading = 'Lihat profil coach dan kelola status akun administratif.';
@endphp

@section('content')
    <style>
        /* PERFORMANCE BANNER */
        .tr-banner {
            position: relative; overflow: hidden; background: var(--panel); border: 1px solid var(--border);
            border-radius: 10px; padding: 32px; margin-bottom: 24px; min-height: 150px;
            display: flex; align-items: center; justify-content: space-between; gap: 20px;
        }
        .tr-watermark {
            position: absolute; top: 50%; left: 20px; transform: translateY(-50%);
            font-size: 110px; font-weight: 800; letter-spacing: 2px; text-transform: uppercase;
            color: rgba(255,255,255,0.04); z-index: 0; pointer-events: none; white-space: nowrap; line-height: 1;
        }
        .tr-banner__stats { position: relative; z-index: 1; display: flex; gap: 64px; flex-wrap: wrap; }
        .tr-stat__label { font-size: 11px; font-weight: 600; letter-spacing: 1.5px; text-transform: uppercase; color: var(--muted); margin-bottom: 8px; }
        .tr-stat__value { font-size: 44px; font-weight: 800; color: var(--text); line-height: 1; display: flex; align-items: center; gap: 8px; }
        .tr-stat__value .star { color: var(--accent); font-size: 26px; }
        .tr-banner__cta { position: relative; z-index: 1; flex-shrink: 0; }

        /* FILTER TABS */
        .tr-filter { display: flex; align-items: flex-start; justify-content: space-between; margin-bottom: 20px; gap: 12px; }
        .tr-filter__specialties { flex: 1; min-width: 0; }
        .tr-tabs { display: flex; align-items: center; gap: 10px; flex-wrap: wrap; }
        .tr-tabs--extra { display: none; margin-top: 10px; padding-top: 10px; border-top: 1px solid var(--border); }
        .tr-tabs--extra.is-open { display: flex; }
        .tr-tab {
            padding: 9px 18px; border-radius: 999px; font-size: 11px; font-weight: 700; letter-spacing: 1px;
            text-transform: uppercase; background: var(--panel); border: 1px solid var(--border); color: var(--muted);
            transition: all 0.15s ease; cursor: pointer;
        }
        .tr-tab:hover { color: var(--text); border-color: #3A3A3A; }
        .tr-tab.active { background: var(--accent); border-color: var(--accent); color: var(--on-accent); }
        .tr-tab--toggle { font-family: inherit; display: inline-flex; align-items: center; gap: 6px; }
        .tr-tab--toggle .tr-toggle-icon { font-size: 13px; line-height: 1; transition: transform 0.15s ease; }
        .tr-tab--toggle[aria-expanded="true"] .tr-toggle-icon { transform: rotate(180deg); }
        .tr-advanced { display: inline-flex; align-items: center; gap: 6px; font-size: 13px; color: var(--muted); cursor: pointer; }
        .tr-advanced:hover { color: var(--accent); }

        /* COACH CARDS */
        .tr-cards { display: grid; grid-template-columns: repeat(2, 1fr); gap: 20px; margin-bottom: 24px; }
        .tr-card {
            background: var(--panel); border: 1px solid var(--border); border-radius: 10px; padding: 20px;
            display: flex; gap: 18px; box-shadow: var(--shadow-card); transition: border-color 0.2s ease;
        }
        .tr-card:hover { border-color: rgba(250,204,21,0.3); }
        .tr-card__photo {
            width: 130px; flex-shrink: 0; position: relative; border-radius: 14px; overflow: hidden;
            background: linear-gradient(135deg, #353534 0%, #131313 100%);
            display: flex; align-items: center; justify-content: center; min-height: 180px;
        }
        .tr-card__photo img { width: 100%; height: 100%; object-fit: cover; }
        .tr-card__photo-initial { font-size: 44px; font-weight: 800; color: var(--accent); }
        .tr-tier-badge {
            position: absolute; bottom: 8px; left: 8px; background: var(--accent); color: var(--on-accent);
            font-size: 10px; font-weight: 800; letter-spacing: 1px; text-transform: uppercase;
            padding: 4px 12px; border-radius: 4px;
        }
        .tr-card__info { flex: 1; display: flex; flex-direction: column; }
        .tr-card__head { display: flex; justify-content: space-between; align-items: flex-start; }
        .tr-card__name { font-size: 22px; font-weight: 800; color: var(--text); }
        .tr-card__spec { font-size: 11px; font-weight: 700; color: var(--accent); letter-spacing: 1px; text-transform: uppercase; margin-top: 4px; }
        .tr-card__rating { text-align: right; }
        .tr-card__rating-val { font-size: 18px; font-weight: 800; color: var(--text); }
        .tr-card__rating-val .star { color: var(--accent); }
        .tr-card__rating-label { font-size: 9px; font-weight: 600; color: var(--muted); letter-spacing: 1px; text-transform: uppercase; }
        .tr-card__stats { display: flex; gap: 12px; margin: 16px 0; }
        .tr-inner-box { flex: 1; background: var(--bg); border: 1px solid var(--border); border-radius: 6px; padding: 12px 14px; }
        .tr-inner-box__label { font-size: 9px; font-weight: 600; color: var(--muted); letter-spacing: 1px; text-transform: uppercase; }
        .tr-inner-box__value { font-size: 20px; font-weight: 800; color: var(--text); margin-top: 4px; }
        .tr-inner-box__value .max { font-size: 11px; font-weight: 400; color: var(--muted); }
        .tr-status-dot { display: inline-flex; align-items: center; gap: 6px; font-size: 13px; font-weight: 700; margin-top: 6px; }
        .tr-status-dot .dot { width: 8px; height: 8px; border-radius: 50%; }
        .tr-status-dot.is-active { color: #22C55E; } .tr-status-dot.is-active .dot { background: #22C55E; }
        .tr-status-dot.is-inactive { color: var(--muted); } .tr-status-dot.is-inactive .dot { background: var(--muted); }
        .tr-card__foot { display: flex; align-items: center; gap: 8px; margin-top: auto; }
        .tr-btn-text {
            font-size: 11px; font-weight: 700; letter-spacing: 0.5px; text-transform: uppercase; color: var(--text);
            background: var(--bg); border: 1px solid var(--border); border-radius: 6px; padding: 9px 14px; cursor: pointer; text-decoration: none;
        }
        .tr-btn-text:hover { border-color: var(--accent); color: var(--accent); }
        .tr-btn-icon {
            width: 36px; height: 36px; display: inline-flex; align-items: center; justify-content: center;
            background: var(--bg); border: 1px solid var(--border); border-radius: 6px; color: var(--muted); cursor: pointer; font-size: 15px; padding: 0;
        }
        .tr-btn-icon:hover { border-color: var(--accent); color: var(--accent); }

        /* QUEUE TABLE */
        .tr-queue { background: var(--panel); border: 1px solid var(--border); border-radius: 10px; overflow: hidden; }
        .tr-queue__head { display: flex; justify-content: space-between; align-items: center; padding: 20px 24px; border-bottom: 1px solid var(--border); }
        .tr-queue__meta { display: flex; align-items: center; gap: 12px; }
        .tr-queue__title { font-size: 14px; font-weight: 700; color: var(--text); letter-spacing: 1px; text-transform: uppercase; }
        .tr-queue__sub { font-size: 10px; font-weight: 600; color: var(--muted); letter-spacing: 1px; text-transform: uppercase; }
        .tr-queue__nav { display: flex; align-items: center; gap: 6px; }
        .tr-queue__arrow {
            width: 30px; height: 30px; border-radius: 6px; border: 1px solid var(--border);
            background: var(--bg); color: var(--text); cursor: pointer; font-size: 16px;
        }
        .tr-queue__arrow:hover:not(:disabled) { border-color: var(--accent); color: var(--accent); }
        .tr-queue__arrow:disabled { opacity: 0.35; cursor: not-allowed; }
        .tr-qgrid { display: grid; grid-template-columns: 2fr 1.5fr 1fr 0.8fr 1fr 0.6fr; gap: 12px; align-items: center; }
        .tr-qthead { padding: 12px 24px; border-bottom: 1px solid var(--border); font-size: 11px; font-weight: 700; color: var(--muted); letter-spacing: 1px; text-transform: uppercase; }
        .tr-qrow { padding: 16px 24px; border-bottom: 1px solid var(--border); transition: background 0.15s ease; }
        .tr-qrow[data-trainer-id] { cursor: pointer; }
        .tr-qrow[hidden], .tr-card[hidden] { display: none; }
        .tr-qrow:last-child { border-bottom: 0; }
        .tr-qrow:hover { background: var(--bg); }
        .tr-qname { display: flex; align-items: center; gap: 12px; }
        .tr-qavatar { width: 36px; height: 36px; border-radius: 50%; background: var(--panel-soft); display: flex; align-items: center; justify-content: center; font-weight: 700; color: var(--accent); flex-shrink: 0; }
        .tr-qname__name { font-size: 14px; font-weight: 700; color: var(--text); }
        .tr-qname__sub { font-size: 11px; color: var(--muted); }
        .tr-badge { display: inline-flex; align-items: center; padding: 4px 12px; border-radius: 4px; font-size: 10px; font-weight: 700; letter-spacing: 0.5px; text-transform: uppercase; }
        .tr-badge-active { background: rgba(76,175,80,0.15); color: #22C55E; }
        .tr-badge-leave { background: rgba(250,204,21,0.15); color: var(--accent); }
        .tr-kebab { position: relative; }
        .tr-kebab__btn { background: transparent; border: 0; color: var(--muted); font-size: 18px; cursor: pointer; padding: 4px 8px; }
        .tr-kebab__btn:hover { color: var(--text); }
        .tr-kebab__menu {
            display: none; position: absolute; right: 0; top: 100%; z-index: 20; min-width: 170px;
            background: var(--panel); border: 1px solid var(--border); border-radius: 8px; box-shadow: var(--shadow-hover); padding: 6px 0;
        }
        .tr-kebab.is-open .tr-kebab__menu { display: block; }
        .tr-kebab__menu a, .tr-kebab__menu button {
            display: block; width: 100%; text-align: left; padding: 9px 14px; font-size: 13px; color: var(--text);
            background: transparent; border: 0; cursor: pointer; text-decoration: none;
        }
        .tr-kebab__menu a:hover, .tr-kebab__menu button:hover { background: var(--bg); color: var(--accent); }
        .tr-empty { padding: 40px 24px; text-align: center; color: var(--muted); }

        @media (max-width: 900px) {
            .tr-filter { flex-direction: column; }
            .tr-filter__specialties { width: 100%; }
            .tr-cards { grid-template-columns: 1fr; }
            .tr-qgrid { grid-template-columns: 2fr 1fr 0.6fr; }
            .tr-qcol-spec, .tr-qcol-rating, .tr-qcol-clients { display: none; }
        }
    </style>

    @if (session('error'))
        <div class="flash" style="background: rgba(239,68,68,0.12); border-color: rgba(239,68,68,0.3); color: #f2a3a3;">{{ session('error') }}</div>
    @endif

    {{-- (2) PERFORMANCE BANNER --}}
    <div class="tr-banner">
        <div class="tr-watermark">PERFORMANCE</div>
        <div class="tr-banner__stats">
            <div>
                <div class="tr-stat__label">Total Active Coaches</div>
                <div class="tr-stat__value">{{ $banner['active_coaches'] }}</div>
            </div>
            <div>
                <div class="tr-stat__label">Avg. Client Satisfaction</div>
                <div class="tr-stat__value">
                    @if ($banner['avg_satisfaction'] !== null)
                        {{ number_format($banner['avg_satisfaction'], 2) }} / 5 &#9733;
                    @else
                        Belum ada rating
                    @endif
                </div>
                <div class="tr-card__rating-label">{{ $banner['reviews_count'] }} ulasan</div>
            </div>
        </div>
        <div class="tr-banner__cta">
            <a href="{{ route('admin.trainer-profiles.create') }}" class="btn btn-primary">&#43; Register New Coach</a>
        </div>
    </div>

    {{-- (3) FILTER TABS --}}
    @php
        $primarySpecialties = $specialties->take(4);
        $extraSpecialties = $specialties->slice(4);
        $extraIsOpen = $extraSpecialties->contains($specialty);
    @endphp
    <div class="tr-filter">
        <div class="tr-filter__specialties">
            <div class="tr-tabs">
                <a href="{{ route('admin.trainer-profiles.index') }}" class="tr-tab {{ $specialty === '' ? 'active' : '' }}">All Specialists</a>
                @foreach ($primarySpecialties as $sp)
                    <a href="{{ route('admin.trainer-profiles.index', ['specialty' => $sp]) }}"
                        class="tr-tab {{ $specialty === $sp ? 'active' : '' }}">{{ $sp }}</a>
                @endforeach
                @if ($extraSpecialties->isNotEmpty())
                    <button type="button" id="specialtyFilterToggle" class="tr-tab tr-tab--toggle"
                        aria-expanded="{{ $extraIsOpen ? 'true' : 'false' }}" aria-controls="extraSpecialtyFilters">
                        <span class="tr-toggle-label">{{ $extraIsOpen ? 'Tutup' : 'Lainnya' }}</span>
                        <span class="tr-toggle-icon" aria-hidden="true">&#9662;</span>
                    </button>
                @endif
            </div>
            @if ($extraSpecialties->isNotEmpty())
                <div id="extraSpecialtyFilters" class="tr-tabs tr-tabs--extra {{ $extraIsOpen ? 'is-open' : '' }}">
                    @foreach ($extraSpecialties as $sp)
                        <a href="{{ route('admin.trainer-profiles.index', ['specialty' => $sp]) }}"
                            class="tr-tab {{ $specialty === $sp ? 'active' : '' }}">{{ $sp }}</a>
                    @endforeach
                </div>
            @endif
        </div>
    </div>

    <script>
        (() => {
            const toggle = document.getElementById('specialtyFilterToggle');
            const extra = document.getElementById('extraSpecialtyFilters');
            if (!toggle || !extra) return;

            toggle.addEventListener('click', () => {
                const isOpen = extra.classList.toggle('is-open');
                toggle.setAttribute('aria-expanded', isOpen ? 'true' : 'false');
                toggle.querySelector('.tr-toggle-label').textContent = isOpen ? 'Tutup' : 'Lainnya';
            });
        })();
    </script>

    @php
        $allDisplayedCoaches = $featured->concat($queue)->values();
        $initialFeaturedIds = $featured->pluck('id')->map(fn ($id) => (int) $id)->values();
        $initialQueueIds = $queue->pluck('id')->map(fn ($id) => (int) $id)->values();
        $allDisplayedCoachIds = $allDisplayedCoaches->pluck('id')->map(fn ($id) => (int) $id)->values();
        $activeDisplayedCoachIds = $allDisplayedCoaches
            ->where('is_active', true)
            ->pluck('id')
            ->map(fn ($id) => (int) $id)
            ->values();
        $hasTrainerFilter = $search !== '' || $specialty !== '';
    @endphp

    {{-- (4) COACH PREVIEW SLOTS: maksimal 2 terlihat, seluruh card tersedia untuk rotasi UI --}}
    @if ($allDisplayedCoaches->isNotEmpty())
        <div class="tr-cards" id="trainerTopCards">
            @foreach ($allDisplayedCoaches as $c)
                @php $initial = strtoupper(mb_substr($c['name'], 0, 1)); @endphp
                <div class="tr-card" data-trainer-id="{{ $c['id'] }}" data-active="{{ $c['is_active'] ? 'true' : 'false' }}" {{ $initialFeaturedIds->contains((int) $c['id']) ? '' : 'hidden' }}>
                    <div class="tr-card__photo">
                        @php
                            // avatar_url disimpan sbg relative path (mis.
                            // "avatars/x.jpg"); data lama bisa URL absolut.
                            $av = $c['avatar_url'] ?? null;
                            $avSrc = $av
                                ? (\Illuminate\Support\Str::startsWith($av, ['http://', 'https://'])
                                    ? $av
                                    : asset('storage/' . ltrim($av, '/')))
                                : null;
                        @endphp
                        @if ($avSrc)
                            <img src="{{ $avSrc }}" alt="Foto {{ $c['name'] }}">
                        @else
                            <span class="tr-card__photo-initial">{{ $initial }}</span>
                        @endif
                        <span class="tr-tier-badge">{{ $c['tier'] }}</span>
                    </div>
                    <div class="tr-card__info">
                        <div class="tr-card__head">
                            <div>
                                <div class="tr-card__name">{{ $c['name'] }}</div>
                                <div class="tr-card__spec">
                                    {{ collect($c['specialties'])->take(2)->join(' • ') }}
                                    @if(count($c['specialties']) > 2) +{{ count($c['specialties']) - 2 }} @endif
                                </div>
                            </div>
                            <div class="tr-card__rating">
                                <div class="tr-card__rating-val">
                                    @if ($c['rating'] !== null)
                                        {{ number_format($c['rating'], 1) }} <span class="star">&#9733;</span>
                                    @else
                                        Belum ada rating
                                    @endif
                                </div>
                                <div class="tr-card__rating-label">{{ $c['reviews_count'] }} ulasan</div>
                            </div>
                        </div>
                        <div class="tr-card__stats">
                            <div class="tr-inner-box">
                                <div class="tr-inner-box__label">Klien Aktif</div>
                                <div class="tr-inner-box__value">{{ $c['active_clients'] }} <span class="max">/ {{ $c['max_clients'] }} Max</span></div>
                            </div>
                            <div class="tr-inner-box">
                                <div class="tr-inner-box__label">Status</div>
                                <div class="tr-status-dot {{ $c['is_active'] ? 'is-active' : 'is-inactive' }}">
                                    <span class="dot"></span>{{ $c['is_active'] ? 'Aktif' : 'Nonaktif' }}
                                </div>
                            </div>
                        </div>
                        <div class="tr-card__foot">
                            <a href="{{ route('admin.trainer-profiles.show', $c['id']) }}" class="tr-btn-text">Lihat Detail</a>
                            <a href="{{ route('admin.trainer-profiles.edit', $c['id']) }}" class="tr-btn-text">Edit Profil</a>
                            <a href="{{ route('admin.trainer-profiles.schedule', $c['id']) }}" class="tr-btn-icon" title="Lihat jadwal {{ $c['name'] }}" aria-label="Lihat jadwal {{ $c['name'] }}">&#128197;</a>
                            <form method="POST" action="{{ route('admin.trainer-profiles.toggle-status', $c['id']) }}" style="margin:0;"
                                onsubmit="return confirm('{{ $c['is_active'] ? 'Nonaktifkan' : 'Aktifkan' }} coach {{ $c['name'] }}?');">
                                @csrf @method('PATCH')
                                <button type="submit" class="tr-btn-icon" title="{{ $c['is_active'] ? 'Nonaktifkan' : 'Aktifkan' }} coach" aria-label="Nonaktifkan {{ $c['name'] }}">&#128683;</button>
                            </form>
                        </div>
                    </div>
                </div>
            @endforeach
        </div>
    @endif

    {{-- (5) OTHER TRAINERS QUEUE --}}
    <div class="tr-queue">
        <div class="tr-queue__head">
            <span class="tr-queue__title">Other Trainers Queue</span>
            <div class="tr-queue__meta">
                <span class="tr-queue__sub" id="trainerViewingCount">Viewing {{ min(2, $queue->count()) }} of {{ $totalCoaches }} Coaches</span>
                <div class="tr-queue__nav" id="trainerQueueNavigation" {{ $queue->count() > 2 ? '' : 'hidden' }}>
                    <button type="button" class="tr-queue__arrow" id="trainerQueuePrevious" onclick="trChangeQueuePage(-1)" aria-label="Coach sebelumnya">&#8592;</button>
                    <button type="button" class="tr-queue__arrow" id="trainerQueueNext" onclick="trChangeQueuePage(1)" aria-label="Coach berikutnya">&#8594;</button>
                </div>
            </div>
        </div>
        <div class="tr-qgrid tr-qthead">
            <div>Coach Name</div>
            <div class="tr-qcol-spec">Specialty</div>
            <div class="tr-qcol-rating">Rating</div>
            <div class="tr-qcol-clients">Clients</div>
            <div>Status</div>
            <div>Actions</div>
        </div>
        <div id="trainerQueueRows">
        @foreach ($allDisplayedCoaches as $c)
            @php
                $initial = strtoupper(mb_substr($c['name'], 0, 1));
                $qav = $c['avatar_url'] ?? null;
                $qavSrc = $qav
                    ? (\Illuminate\Support\Str::startsWith($qav, ['http://', 'https://'])
                        ? $qav
                        : asset('storage/' . ltrim($qav, '/')))
                    : null;
            @endphp
            <div class="tr-qgrid tr-qrow" data-trainer-id="{{ $c['id'] }}" data-active="{{ $c['is_active'] ? 'true' : 'false' }}" {{ $initialQueueIds->take(2)->contains((int) $c['id']) ? '' : 'hidden' }}>
                <div class="tr-qname">
                    <div class="tr-qavatar">
                        @if ($qavSrc)
                            <img src="{{ $qavSrc }}" alt="Foto {{ $c['name'] }}"
                                 style="width:100%;height:100%;border-radius:50%;object-fit:cover;">
                        @else
                            {{ $initial }}
                        @endif
                    </div>
                    <div>
                        <div class="tr-qname__name">{{ $c['name'] }}</div>
                        <div class="tr-qname__sub">Joined {{ $c['joined'] }}</div>
                    </div>
                </div>
                <div class="tr-qcol-spec" style="font-size: 13px; color: var(--text);">
                    {{ collect($c['specialties'])->take(2)->join(', ') }}@if(count($c['specialties']) > 2) +{{ count($c['specialties']) - 2 }}@endif
                </div>
                <div class="tr-qcol-rating" style="font-size: 13px; color: var(--text);">
                    @if ($c['rating'] !== null)
                        {{ number_format($c['rating'], 1) }} <span style="color: var(--accent);">&#9733;</span>
                    @else
                        Belum ada rating
                    @endif
                    <small style="display:block;color:var(--muted);">{{ $c['reviews_count'] }} ulasan</small>
                </div>
                <div class="tr-qcol-clients" style="font-size: 13px; color: var(--text);">{{ $c['active_clients'] }}</div>
                <div>
                    <span class="tr-badge {{ $c['is_active'] ? 'tr-badge-active' : 'tr-badge-leave' }}">{{ $c['is_active'] ? 'Active' : 'On Leave' }}</span>
                </div>
                <div class="tr-kebab" data-kebab>
                    <button type="button" class="tr-kebab__btn" onclick="trToggleKebab(this)" aria-label="Aksi {{ $c['name'] }}">&#8942;</button>
                    <div class="tr-kebab__menu">
                        <a href="{{ route('admin.trainer-profiles.show', $c['id']) }}">Lihat Profil</a>
                        <a href="{{ route('admin.trainer-profiles.edit', $c['id']) }}">Edit Profil</a>
                        <a href="{{ route('admin.trainer-profiles.schedule', $c['id']) }}">Lihat Jadwal</a>
                        <form method="POST" action="{{ route('admin.trainer-profiles.toggle-status', $c['id']) }}"
                            onsubmit="return confirm('{{ $c['is_active'] ? 'Nonaktifkan' : 'Aktifkan' }} coach {{ $c['name'] }}?');">
                            @csrf @method('PATCH')
                            <button type="submit">{{ $c['is_active'] ? 'Nonaktifkan' : 'Aktifkan' }}</button>
                        </form>
                    </div>
                </div>
            </div>
        @endforeach
        </div>
        <div class="tr-empty" id="trainerQueueEmpty" {{ $queue->isEmpty() ? '' : 'hidden' }}>Tidak ada coach lain dalam antrian.</div>
    </div>

    <script>
        const trainerFeaturedStorageKey = 'admin_trainer_featured_order';
        const backendTrainerIds = @json($allDisplayedCoachIds);
        const activeTrainerIds = @json($activeDisplayedCoachIds);
        const trainerResultIsFiltered = @json($hasTrainerFilter);
        let topTrainerIds = [];
        let queueTrainerIds = [];
        const trainerQueuePageSize = 2;
        let trainerQueuePage = 0;

        function trReadStoredFeaturedIds() {
            try {
                const decoded = JSON.parse(window.localStorage.getItem(trainerFeaturedStorageKey) ?? '[]');
                if (!Array.isArray(decoded)) return [];

                return [...new Set(decoded
                    .map(id => Number(id))
                    .filter(id => Number.isInteger(id) && id > 0))];
            } catch (_) {
                return [];
            }
        }

        function trWriteStoredFeaturedIds(ids = topTrainerIds) {
            try {
                const normalized = [...new Set(ids
                    .map(id => Number(id))
                    .filter(id => Number.isInteger(id) && id > 0))]
                    .slice(0, 2);
                window.localStorage.setItem(trainerFeaturedStorageKey, JSON.stringify(normalized));
            } catch (_) {
                // Storage dapat ditolak browser/private mode; rotasi in-memory tetap jalan.
            }
        }

        function trRestorePreviewSlots() {
            const storedIds = trReadStoredFeaturedIds();
            const eligibleIds = activeTrainerIds.filter(id => backendTrainerIds.includes(id));
            const restoredIds = storedIds.filter(id => eligibleIds.includes(id));
            const fallbackIds = eligibleIds.filter(id => !restoredIds.includes(id));

            topTrainerIds = [...restoredIds, ...fallbackIds].slice(0, 2);
            queueTrainerIds = backendTrainerIds.filter(id => !topTrainerIds.includes(id));

            // Pada hasil penuh, bersihkan ID terhapus/nonaktif dan simpan fallback valid.
            // Pada filter/search, jangan menghapus preference global hanya karena ID
            // sedang tidak termasuk result set halaman ini.
            if (!trainerResultIsFiltered) trWriteStoredFeaturedIds();
        }

        function trRenderPreviewSlots() {
            topTrainerIds = [...new Set(topTrainerIds)]
                .filter(id => activeTrainerIds.includes(id) && backendTrainerIds.includes(id))
                .slice(0, 2);
            queueTrainerIds = [...new Set(queueTrainerIds)]
                .filter(id => backendTrainerIds.includes(id) && !topTrainerIds.includes(id));
            const topContainer = document.getElementById('trainerTopCards');
            const queueContainer = document.getElementById('trainerQueueRows');

            document.querySelectorAll('.tr-card[data-trainer-id]').forEach(card => {
                const id = Number(card.dataset.trainerId);
                card.hidden = !topTrainerIds.includes(id);
            });
            topTrainerIds.forEach(id => {
                const card = topContainer?.querySelector(`.tr-card[data-trainer-id="${id}"]`);
                if (card) topContainer.appendChild(card);
            });

            const totalQueuePages = Math.max(1, Math.ceil(queueTrainerIds.length / trainerQueuePageSize));
            trainerQueuePage = Math.min(trainerQueuePage, totalQueuePages - 1);
            const visibleQueueIds = queueTrainerIds.slice(
                trainerQueuePage * trainerQueuePageSize,
                (trainerQueuePage + 1) * trainerQueuePageSize
            );

            document.querySelectorAll('.tr-qrow[data-trainer-id]').forEach(row => {
                const id = Number(row.dataset.trainerId);
                row.hidden = !visibleQueueIds.includes(id);
            });
            visibleQueueIds.forEach(id => {
                const row = queueContainer?.querySelector(`.tr-qrow[data-trainer-id="${id}"]`);
                if (row) queueContainer.appendChild(row);
            });

            document.getElementById('trainerQueueEmpty').hidden = queueTrainerIds.length > 0;
            document.getElementById('trainerViewingCount').textContent =
                `Viewing ${visibleQueueIds.length} of ${queueTrainerIds.length} Coaches`;
            document.getElementById('trainerQueueNavigation').hidden = queueTrainerIds.length <= trainerQueuePageSize;
            document.getElementById('trainerQueuePrevious').disabled = trainerQueuePage === 0;
            document.getElementById('trainerQueueNext').disabled = trainerQueuePage >= totalQueuePages - 1;
        }

        function trChangeQueuePage(direction) {
            const totalPages = Math.ceil(queueTrainerIds.length / trainerQueuePageSize);
            trainerQueuePage = Math.max(0, Math.min(trainerQueuePage + direction, totalPages - 1));
            trRenderPreviewSlots();
        }

        function trPromoteFromQueue(trainerId) {
            trainerId = Number(trainerId);
            if (!queueTrainerIds.includes(trainerId) || !activeTrainerIds.includes(trainerId)) return;

            const outgoingId = topTrainerIds.length >= 2 ? topTrainerIds.shift() : null;
            topTrainerIds.push(trainerId);
            queueTrainerIds = queueTrainerIds.filter(id => id !== trainerId);
            if (outgoingId !== null) queueTrainerIds.unshift(outgoingId);
            trWriteStoredFeaturedIds();
            trainerQueuePage = 0;
            trRenderPreviewSlots();
        }

        document.querySelectorAll('.tr-qrow[data-trainer-id]').forEach(row => {
            row.addEventListener('click', event => {
                if (event.target.closest('a, button, form, [data-kebab]')) return;
                trPromoteFromQueue(row.dataset.trainerId);
            });
        });

        function trToggleKebab(btn) {
            const kebab = btn.closest('[data-kebab]');
            const wasOpen = kebab.classList.contains('is-open');
            document.querySelectorAll('[data-kebab].is-open').forEach(k => k.classList.remove('is-open'));
            if (!wasOpen) kebab.classList.add('is-open');
        }
        document.addEventListener('click', (e) => {
            if (!e.target.closest('[data-kebab]')) {
                document.querySelectorAll('[data-kebab].is-open').forEach(k => k.classList.remove('is-open'));
            }
        });

        trRestorePreviewSlots();
        trRenderPreviewSlots();
    </script>
@endsection
