import 'package:flutter/material.dart';

class SearchSelectionField extends StatelessWidget {
  const SearchSelectionField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.emptyText = 'Seçilmedi',
    this.requiredMessage,
    this.allowClear = true,
    this.clearText = 'Temizle',
    this.prefixIcon,
    this.width,
    this.dense = false,
  });

  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  final String emptyText;
  final String? requiredMessage;
  final bool allowClear;
  final String clearText;
  final IconData? prefixIcon;
  final double? width;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final field = FormField<String?>(
      key: ValueKey('$label-$value-${options.length}-$requiredMessage'),
      initialValue: value,
      validator: (currentValue) {
        if (requiredMessage == null) {
          return null;
        }
        return currentValue == null ? requiredMessage : null;
      },
      builder: (state) {
        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () async {
            final selected = await showSearchSelectionDialog(
              context: context,
              title: label,
              options: options,
              selectedValue: state.value,
              allowClear: allowClear,
              clearText: clearText,
            );
            if (selected == _SearchDialogCancelled.value) {
              return;
            }
            state.didChange(selected);
            onChanged(selected);
          },
          child: InputDecorator(
            isEmpty: state.value == null,
            decoration: InputDecoration(
              isDense: dense,
              prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
              suffixIcon: const Icon(Icons.search),
              errorText: state.errorText,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  state.value ?? emptyText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: state.value == null
                        ? theme.colorScheme.onSurfaceVariant
                        : null,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (width == null) {
      return field;
    }
    return SizedBox(width: width, child: field);
  }
}

Future<String?> showSearchSelectionDialog({
  required BuildContext context,
  required String title,
  required List<String> options,
  required String? selectedValue,
  required bool allowClear,
  required String clearText,
}) async {
  final result = await showDialog<Object?>(
    context: context,
    builder: (context) => _SearchSelectionDialog(
      title: title,
      options: options,
      selectedValue: selectedValue,
      allowClear: allowClear,
      clearText: clearText,
    ),
  );
  if (result == _SearchDialogCancelled.value) {
    return _SearchDialogCancelled.value;
  }
  return result as String?;
}

class _SearchSelectionDialog extends StatefulWidget {
  const _SearchSelectionDialog({
    required this.title,
    required this.options,
    required this.selectedValue,
    required this.allowClear,
    required this.clearText,
  });

  final String title;
  final List<String> options;
  final String? selectedValue;
  final bool allowClear;
  final String clearText;

  @override
  State<_SearchSelectionDialog> createState() => _SearchSelectionDialogState();
}

class _SearchSelectionDialogState extends State<_SearchSelectionDialog> {
  final _queryController = TextEditingController();

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _queryController.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? widget.options
        : widget.options
            .where((item) => item.toLowerCase().contains(query))
            .toList();

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        height: 430,
        child: Column(
          children: [
            TextField(
              controller: _queryController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Ara',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            if (widget.allowClear)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(null),
                  icon: const Icon(Icons.close),
                  label: Text(widget.clearText),
                ),
              ),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('Sonuç bulunamadı.'))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        return ListTile(
                          title: Text(item),
                          selected: item == widget.selectedValue,
                          trailing: item == widget.selectedValue
                              ? const Icon(Icons.check)
                              : null,
                          onTap: () => Navigator.of(context).pop(item),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(_SearchDialogCancelled.value),
          child: const Text('Kapat'),
        ),
      ],
    );
  }
}

class _SearchDialogCancelled {
  const _SearchDialogCancelled._();

  static const value = '__sorgun_search_cancelled__';
}
