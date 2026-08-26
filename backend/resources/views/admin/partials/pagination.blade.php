{{--
    Reusable pagination footer — dipakai di semua halaman admin.
    Pakai: @include('admin.partials.pagination', ['paginator' => $paginator])
    Menyatu sebagai footer di dalam card tabel (kelas .adm-pager-foot).
--}}
@if ($paginator->total() > 0)
    <div class="adm-pager-foot">
        <div class="adm-pager-foot__info">
            Menampilkan {{ $paginator->firstItem() }}&ndash;{{ $paginator->lastItem() }} dari {{ number_format($paginator->total(), 0, ',', '.') }} {{ $itemLabel ?? 'hasil' }}
        </div>

        @if ($paginator->lastPage() > 1)
            @php
                $cur = $paginator->currentPage();
                $last = $paginator->lastPage();
                $pages = collect(range(1, $last))
                    ->filter(fn ($p) => $p === 1 || $p === $last || abs($p - $cur) <= 1)
                    ->values();
            @endphp
            <div class="adm-pager">
                @if ($paginator->onFirstPage())
                    <span class="adm-pager__nav is-disabled">Prev</span>
                @else
                    <a class="adm-pager__nav" href="{{ $paginator->previousPageUrl() }}" rel="prev">Prev</a>
                @endif

                @php $prev = 0; @endphp
                @foreach ($pages as $p)
                    @if ($p - $prev > 1)
                        <span class="adm-pager__ellipsis">&middot;&middot;&middot;</span>
                    @endif
                    @if ($p === $cur)
                        <span class="adm-pager__page is-active" aria-current="page">{{ $p }}</span>
                    @else
                        <a class="adm-pager__page" href="{{ $paginator->url($p) }}" aria-label="Halaman {{ $p }}">{{ $p }}</a>
                    @endif
                    @php $prev = $p; @endphp
                @endforeach

                @if ($paginator->hasMorePages())
                    <a class="adm-pager__nav" href="{{ $paginator->nextPageUrl() }}" rel="next">Next</a>
                @else
                    <span class="adm-pager__nav is-disabled">Next</span>
                @endif
            </div>
        @endif
    </div>
@endif
