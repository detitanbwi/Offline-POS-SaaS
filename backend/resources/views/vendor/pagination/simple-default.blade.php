@if ($paginator->hasPages())
    <nav class="pagination-container" role="navigation" aria-label="Navigasi Halaman">
        <ul class="pagination-list" style="margin-left: auto;">
            {{-- Previous Page Link --}}
            @if ($paginator->onFirstPage())
                <li class="page-item disabled" aria-disabled="true">
                    <span class="page-link">&laquo; Sebelumnya</span>
                </li>
            @else
                <li class="page-item">
                    <a class="page-link" href="{{ $paginator->previousPageUrl() }}" rel="prev">&laquo; Sebelumnya</a>
                </li>
            @endif

            {{-- Next Page Link --}}
            @if ($paginator->hasMorePages())
                <li class="page-item">
                    <a class="page-link" href="{{ $paginator->nextPageUrl() }}" rel="next">Selanjutnya &raquo;</a>
                </li>
            @else
                <li class="page-item disabled" aria-disabled="true">
                    <span class="page-link">Selanjutnya &raquo;</span>
                </li>
            @endif
        </ul>
    </nav>
@endif
