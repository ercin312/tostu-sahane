import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../shared/domain/entities/waiter_preparation_option.dart';

class AdminWaiterPreparationTab extends StatefulWidget {
  const AdminWaiterPreparationTab({
    super.key,
    required this.options,
    required this.onChanged,
  });

  final List<WaiterPreparationOption> options;
  final ValueChanged<List<WaiterPreparationOption>> onChanged;

  @override
  State<AdminWaiterPreparationTab> createState() =>
      _AdminWaiterPreparationTabState();
}

class _AdminWaiterPreparationTabState extends State<AdminWaiterPreparationTab> {
  final _trControllers = <String, TextEditingController>{};
  final _enControllers = <String, TextEditingController>{};

  @override
  void dispose() {
    for (final c in _trControllers.values) {
      c.dispose();
    }
    for (final c in _enControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _trController(WaiterPreparationOption option) {
    return _trControllers.putIfAbsent(
      option.id,
      () => TextEditingController(text: option.labelTr),
    );
  }

  TextEditingController _enController(WaiterPreparationOption option) {
    return _enControllers.putIfAbsent(
      option.id,
      () => TextEditingController(text: option.labelEn),
    );
  }

  void _updateOption(int index, WaiterPreparationOption updated) {
    final list = [...widget.options];
    list[index] = updated;
    widget.onChanged(list);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text(
          LocaleKeys.adminWaiterPrepTabHint.tr(),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        const SizedBox(height: AppSpacing.md),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () {
              final id = 'prep_${DateTime.now().millisecondsSinceEpoch}';
              widget.onChanged([
                ...widget.options,
                WaiterPreparationOption(
                  id: id,
                  labelTr: '',
                  labelEn: '',
                  sortOrder: widget.options.length,
                ),
              ]);
            },
            icon: const Icon(Icons.add),
            label: Text(LocaleKeys.adminWaiterPrepAdd.tr()),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.options.length,
          onReorder: (oldIndex, newIndex) {
            final updated = [...widget.options];
            if (newIndex > oldIndex) newIndex -= 1;
            final item = updated.removeAt(oldIndex);
            updated.insert(newIndex, item);
            widget.onChanged([
              for (var i = 0; i < updated.length; i++)
                updated[i].copyWith(sortOrder: i),
            ]);
          },
          itemBuilder: (context, index) {
            final option = widget.options[index];
            return Card(
              key: ValueKey(option.id),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.drag_handle),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              option.labelTr.isEmpty
                                  ? option.id
                                  : option.labelTr,
                            ),
                            value: option.enabled,
                            onChanged: (value) =>
                                _updateOption(index, option.copyWith(enabled: value)),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            _trControllers.remove(option.id)?.dispose();
                            _enControllers.remove(option.id)?.dispose();
                            widget.onChanged(
                              widget.options
                                  .where((o) => o.id != option.id)
                                  .toList(),
                            );
                          },
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                    TextField(
                      decoration: InputDecoration(
                        labelText: LocaleKeys.adminWaiterPrepLabelTr.tr(),
                        isDense: true,
                      ),
                      controller: _trController(option),
                      onChanged: (value) =>
                          _updateOption(index, option.copyWith(labelTr: value)),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    TextField(
                      decoration: InputDecoration(
                        labelText: LocaleKeys.adminWaiterPrepLabelEn.tr(),
                        isDense: true,
                      ),
                      controller: _enController(option),
                      onChanged: (value) =>
                          _updateOption(index, option.copyWith(labelEn: value)),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 80),
      ],
    );
  }
}
