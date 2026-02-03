/// ProMould Design System - Data Table Pro Component
/// Dense, sortable data tables for manufacturing data

import 'package:flutter/material.dart';
import '../theme/theme.dart';

/// Column definition for DataTablePro
class DataColumnDef<T> {
  final String label;
  final String? tooltip;
  final double? width;
  final bool sortable;
  final bool numeric;
  final Widget Function(T item) cellBuilder;
  final int Function(T a, T b)? comparator;

  const DataColumnDef({
    required this.label,
    this.tooltip,
    this.width,
    this.sortable = false,
    this.numeric = false,
    required this.cellBuilder,
    this.comparator,
  });
}

/// Professional data table with sorting and selection
class DataTablePro<T> extends StatefulWidget {
  final List<DataColumnDef<T>> columns;
  final List<T> data;
  final bool selectable;
  final Set<T>? selectedItems;
  final ValueChanged<Set<T>>? onSelectionChanged;
  final ValueChanged<T>? onRowTap;
  final bool showHeader;
  final double rowHeight;
  final ScrollController? scrollController;
  final Widget? emptyState;

  const DataTablePro({
    super.key,
    required this.columns,
    required this.data,
    this.selectable = false,
    this.selectedItems,
    this.onSelectionChanged,
    this.onRowTap,
    this.showHeader = true,
    this.rowHeight = 52,
    this.scrollController,
    this.emptyState,
  });

  @override
  State<DataTablePro<T>> createState() => _DataTableProState<T>();
}

class _DataTableProState<T> extends State<DataTablePro<T>> {
  int? _sortColumnIndex;
  bool _sortAscending = true;
  late List<T> _sortedData;

  @override
  void initState() {
    super.initState();
    _sortedData = List.from(widget.data);
  }

  @override
  void didUpdateWidget(DataTablePro<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _sortedData = List.from(widget.data);
      if (_sortColumnIndex != null) {
        _sortData();
      }
    }
  }

  void _sortData() {
    if (_sortColumnIndex == null) return;
    final column = widget.columns[_sortColumnIndex!];
    if (column.comparator == null) return;

    _sortedData.sort((a, b) {
      final result = column.comparator!(a, b);
      return _sortAscending ? result : -result;
    });
  }

  void _onSort(int columnIndex) {
    final column = widget.columns[columnIndex];
    if (!column.sortable || column.comparator == null) return;

    setState(() {
      if (_sortColumnIndex == columnIndex) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumnIndex = columnIndex;
        _sortAscending = true;
      }
      _sortData();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_sortedData.isEmpty && widget.emptyState != null) {
      return widget.emptyState!;
    }

    return Column(
      children: [
        if (widget.showHeader) _buildHeader(),
        Expanded(
          child: ListView.builder(
            controller: widget.scrollController,
            itemCount: _sortedData.length,
            itemBuilder: (context, index) => _buildRow(_sortedData[index], index),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          if (widget.selectable)
            SizedBox(
              width: 48,
              child: Checkbox(
                value: widget.selectedItems?.length == _sortedData.length &&
                    _sortedData.isNotEmpty,
                tristate: true,
                onChanged: (value) {
                  if (value == true) {
                    widget.onSelectionChanged?.call(Set.from(_sortedData));
                  } else {
                    widget.onSelectionChanged?.call({});
                  }
                },
              ),
            ),
          ...widget.columns.asMap().entries.map((entry) {
            final index = entry.key;
            final column = entry.value;
            return _buildHeaderCell(column, index);
          }),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(DataColumnDef<T> column, int index) {
    final isSorted = _sortColumnIndex == index;

    return Expanded(
      flex: column.width != null ? 0 : 1,
      child: SizedBox(
        width: column.width,
        child: InkWell(
          onTap: column.sortable ? () => _onSort(index) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              mainAxisAlignment:
                  column.numeric ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                Flexible(
                  child: Text(
                    column.label,
                    style: AppTypography.labelMedium.copyWith(
                      color: isSorted ? AppColors.primary : AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (column.sortable) ...[
                  const SizedBox(width: 4),
                  Icon(
                    isSorted
                        ? (_sortAscending
                            ? Icons.arrow_upward
                            : Icons.arrow_downward)
                        : Icons.unfold_more,
                    size: 16,
                    color: isSorted ? AppColors.primary : AppColors.textTertiary,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(T item, int index) {
    final isSelected = widget.selectedItems?.contains(item) ?? false;
    final isEven = index % 2 == 0;

    return InkWell(
      onTap: widget.onRowTap != null ? () => widget.onRowTap!(item) : null,
      child: Container(
        height: widget.rowHeight,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.1)
              : (isEven ? Colors.transparent : AppColors.surface.withOpacity(0.3)),
          border: const Border(
            bottom: BorderSide(color: AppColors.border, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            if (widget.selectable)
              SizedBox(
                width: 48,
                child: Checkbox(
                  value: isSelected,
                  onChanged: (value) {
                    final newSelection = Set<T>.from(widget.selectedItems ?? {});
                    if (value == true) {
                      newSelection.add(item);
                    } else {
                      newSelection.remove(item);
                    }
                    widget.onSelectionChanged?.call(newSelection);
                  },
                ),
              ),
            ...widget.columns.map((column) => _buildCell(column, item)),
          ],
        ),
      ),
    );
  }

  Widget _buildCell(DataColumnDef<T> column, T item) {
    return Expanded(
      flex: column.width != null ? 0 : 1,
      child: SizedBox(
        width: column.width,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Align(
            alignment:
                column.numeric ? Alignment.centerRight : Alignment.centerLeft,
            child: column.cellBuilder(item),
          ),
        ),
      ),
    );
  }
}

/// Simple table row for quick layouts
class TableRowPro extends StatelessWidget {
  final List<Widget> cells;
  final VoidCallback? onTap;
  final bool selected;
  final Color? backgroundColor;

  const TableRowPro({
    super.key,
    required this.cells,
    this.onTap,
    this.selected = false,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withOpacity(0.1)
              : backgroundColor,
          border: const Border(
            bottom: BorderSide(color: AppColors.border, width: 0.5),
          ),
        ),
        child: Row(
          children: cells
              .map((cell) => Expanded(child: cell))
              .toList(),
        ),
      ),
    );
  }
}
