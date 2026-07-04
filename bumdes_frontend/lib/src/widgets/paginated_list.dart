import 'package:flutter/material.dart';

/// Widget list generik dengan pagination (bukan scroll panjang).
///
/// Cara pakai — ganti pola lama:
///   ListView.separated(
///     shrinkWrap: true,
///     physics: const NeverScrollableScrollPhysics(),
///     itemCount: items.length,
///     separatorBuilder: (_, __) => const Divider(height: 1),
///     itemBuilder: (context, index) => ...,
///   )
///
/// menjadi:
///   PaginatedListView<Map<String, dynamic>>(
///     items: items,
///     itemBuilder: (context, item, index) => ...,
///     separatorBuilder: (_, __) => const Divider(height: 1),
///   )
class PaginatedListView<T> extends StatefulWidget {
  const PaginatedListView({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.separatorBuilder,
    this.pageSize = 10,
    this.emptyWidget,
  });

  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final Widget Function(BuildContext context, int index)? separatorBuilder;
  final int pageSize;
  final Widget? emptyWidget;

  @override
  State<PaginatedListView<T>> createState() => _PaginatedListViewState<T>();
}

class _PaginatedListViewState<T> extends State<PaginatedListView<T>> {
  int _page = 0; // 0-based

  @override
  void didUpdateWidget(covariant PaginatedListView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Kalau data berubah (misal habis refresh/filter) dan halaman sekarang
    // sudah di luar jangkauan, balik ke halaman pertama supaya tidak blank.
    final lastPage = _lastPageIndex;
    if (_page > lastPage) {
      _page = 0;
    }
  }

  int get _totalPages =>
      widget.items.isEmpty ? 1 : (widget.items.length / widget.pageSize).ceil();

  int get _lastPageIndex => _totalPages - 1;

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return widget.emptyWidget ?? const SizedBox.shrink();
    }

    final start = _page * widget.pageSize;
    final end = (start + widget.pageSize).clamp(0, widget.items.length);
    final pageItems = widget.items.sublist(start, end);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: pageItems.length,
          separatorBuilder:
              widget.separatorBuilder ?? (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) =>
              widget.itemBuilder(context, pageItems[index], start + index),
        ),
        if (_totalPages > 1) _buildPager(),
      ],
    );
  }

  Widget _buildPager() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: 'Sebelumnya',
            onPressed: _page > 0 ? () => setState(() => _page--) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Text(
            'Halaman ${_page + 1} dari $_totalPages',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          IconButton(
            tooltip: 'Berikutnya',
            onPressed:
                _page < _lastPageIndex ? () => setState(() => _page++) : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}