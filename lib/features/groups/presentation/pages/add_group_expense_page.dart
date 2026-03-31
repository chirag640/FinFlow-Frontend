import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/components/ds_button.dart';
import '../../../../core/design/components/ds_text_field.dart';
import '../../../../core/ui/error_feedback.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/utils/validators.dart';
import '../../domain/entities/group.dart';
import '../../domain/entities/group_expense.dart';
import '../../domain/entities/group_member.dart';
import '../providers/group_provider.dart';

class AddGroupExpensePage extends ConsumerStatefulWidget {
  final String groupId;
  const AddGroupExpensePage({super.key, required this.groupId});

  @override
  ConsumerState<AddGroupExpensePage> createState() =>
      _AddGroupExpensePageState();
}

class _AddGroupExpensePageState extends ConsumerState<AddGroupExpensePage> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String? _paidByMemberId;
  SplitType _splitType = SplitType.equal;
  final Map<String, TextEditingController> _customControllers = {};
  bool _isLoading = false;
  bool _showNoteField = false;

  Group get _group {
    final gs = ref.read(groupProvider);
    return gs.groups.firstWhere(
      (g) => g.id == widget.groupId,
      orElse: () => Group(
        id: widget.groupId,
        name: '',
        emoji: '👥',
        members: [],
        currentUserId: '',
        createdAt: DateTime.now(),
      ),
    );
  }

  List<GroupMember> _uniqueMembers(Group group) {
    final byKey = <String, GroupMember>{};
    for (final member in group.members) {
      final key = _memberUniqueKey(member);
      byKey.putIfAbsent(key, () => member);
    }
    return byKey.values.toList();
  }

  String _memberUniqueKey(GroupMember member) {
    final userId = member.userId?.trim();
    if (userId != null && userId.isNotEmpty) {
      return 'user:$userId';
    }
    final username = member.username?.trim().toLowerCase();
    if (username != null && username.isNotEmpty) {
      return 'username:${username.startsWith('@') ? username.substring(1) : username}';
    }
    final handle = member.handle.trim().toLowerCase();
    if (handle.isNotEmpty) {
      return 'handle:${handle.startsWith('@') ? handle.substring(1) : handle}';
    }
    return 'id:${member.id}';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final group = _group;
      final members = _uniqueMembers(group);
      if (members.isNotEmpty && mounted) {
        setState(() {
          final hasCurrent = members.any((m) => m.id == group.currentUserId);
          _paidByMemberId = hasCurrent ? group.currentUserId : members.first.id;
          _ensureCustomControllers(group);
        });
      }
    });
  }

  void _ensureCustomControllers(Group group) {
    final members = _uniqueMembers(group);
    for (final m in members) {
      _customControllers.putIfAbsent(m.id, TextEditingController.new);
    }
    final staleIds = _customControllers.keys
        .where((id) => members.every((m) => m.id != id))
        .toList();
    for (final id in staleIds) {
      _customControllers[id]?.dispose();
      _customControllers.remove(id);
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _noteCtrl.dispose();
    for (final c in _customControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_paidByMemberId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Select who paid')));
      return;
    }
    final group = _group;
    final members = _uniqueMembers(group);
    if (members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one member first')),
      );
      return;
    }
    if (_paidByMemberId == null ||
        members.every((m) => m.id != _paidByMemberId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a valid payer from members')),
      );
      return;
    }
    final amount = double.parse(_amountCtrl.text.trim());
    List<SplitShare> shares;

    if (_splitType == SplitType.equal) {
      final each = amount / members.length;
      shares =
          members.map((m) => SplitShare(memberId: m.id, amount: each)).toList();
    } else if (_splitType == SplitType.custom) {
      shares = members.map((m) {
        final v = double.tryParse(_customControllers[m.id]?.text ?? '0') ?? 0;
        return SplitShare(memberId: m.id, amount: v);
      }).toList();
      final total = shares.fold(0.0, (s, x) => s + x.amount);
      if ((total - amount).abs() > 0.01) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Custom amounts must sum to total')));
        return;
      }
    } else if (_splitType == SplitType.percentage) {
      // percentage
      shares = members.map((m) {
        final pct = double.tryParse(_customControllers[m.id]?.text ?? '0') ?? 0;
        return SplitShare(memberId: m.id, amount: amount * pct / 100);
      }).toList();
      final totalPct = members.fold(
          0.0,
          (s, m) =>
              s +
              (double.tryParse(_customControllers[m.id]?.text ?? '0') ?? 0));
      if ((totalPct - 100).abs() > 0.1) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Percentages must sum to 100%')));
        return;
      }
    } else {
      // incomeRatio — split proportionally by each member's monthly income
      final incomes = members
          .map((m) =>
              double.tryParse(_customControllers[m.id]?.text ?? '0') ?? 0.0)
          .toList();
      final totalIncome = incomes.fold(0.0, (s, v) => s + v);
      if (totalIncome <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Enter monthly income for at least one member')));
        return;
      }
      shares = members.asMap().entries.map((e) {
        return SplitShare(
          memberId: e.value.id,
          amount: amount * incomes[e.key] / totalIncome,
        );
      }).toList();
    }

    setState(() => _isLoading = true);
    await ref.read(groupExpenseProvider(widget.groupId).notifier).addExpense(
          amount: amount,
          description: _descCtrl.text.trim(),
          paidByMemberId: _paidByMemberId!,
          splitType: _splitType,
          shares: shares,
          date: DateTime.now(),
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        );
    if (mounted) {
      setState(() => _isLoading = false);
      context.pop();
    }
  }

  double get _enteredAmount => double.tryParse(_amountCtrl.text.trim()) ?? 0;

  double _sumCustomValues(List<GroupMember> members) {
    return members.fold<double>(
      0,
      (sum, member) =>
          sum +
          (double.tryParse(_customControllers[member.id]?.text ?? '0') ?? 0),
    );
  }

  String _splitHint(List<GroupMember> members) {
    if (members.isEmpty) return 'Add members to configure split.';

    if (_splitType == SplitType.equal) {
      if (members.length == 1) {
        return 'Only one member in this group. Split is not needed.';
      }
      if (_enteredAmount <= 0) {
        return 'Enter amount to preview equal split.';
      }
      final perHead = _enteredAmount / members.length;
      return 'Each member pays ${perHead.isFinite ? perHead.toStringAsFixed(2) : '0.00'}';
    }

    final total = _sumCustomValues(members);
    if (_splitType == SplitType.custom) {
      final diff = _enteredAmount - total;
      if (_enteredAmount <= 0) return 'Enter amount to validate custom split.';
      if (diff.abs() <= 0.01) return 'Custom split is balanced.';
      return diff > 0
          ? 'Add ${diff.toStringAsFixed(2)} more to match total.'
          : 'Reduce ${(diff.abs()).toStringAsFixed(2)} to match total.';
    }

    if (_splitType == SplitType.percentage) {
      final diff = 100 - total;
      if (diff.abs() <= 0.1) return 'Percentage split totals 100%.';
      return diff > 0
          ? 'Add ${diff.toStringAsFixed(1)}% more.'
          : 'Remove ${(diff.abs()).toStringAsFixed(1)}%.';
    }

    if (total <= 0) {
      return 'Enter at least one monthly income for ratio split.';
    }
    return 'Income ratio split ready (${total.toStringAsFixed(0)} total income).';
  }

  Color _splitHintColor(BuildContext context, List<GroupMember> members) {
    final colorScheme = Theme.of(context).colorScheme;
    if (_splitType == SplitType.equal) return colorScheme.primary;
    final hint = _splitHint(members).toLowerCase();
    if (hint.contains('balanced') ||
        hint.contains('ready') ||
        hint.contains('100%')) {
      return colorScheme.tertiary;
    }
    if (hint.contains('add') ||
        hint.contains('remove') ||
        hint.contains('enter')) {
      return colorScheme.error;
    }
    return colorScheme.onSurfaceVariant;
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);
    listenForProviderError<GroupExpenseState>(
      ref: ref,
      context: context,
      provider: groupExpenseProvider(widget.groupId),
      errorSelector: (s) => s.error,
      onErrorShown: () {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      },
    );
    final group = _group;
    final members = _uniqueMembers(group);
    _ensureCustomControllers(group);
    if ((_paidByMemberId == null ||
            members.every((m) => m.id != _paidByMemberId)) &&
        members.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final hasCurrent = members.any((m) => m.id == group.currentUserId);
        setState(() => _paidByMemberId =
            hasCurrent ? group.currentUserId : members.first.id);
      });
    }
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Add Group Expense',
          style: TextStyle(
              fontSize: R.t(17),
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(R.s(14)),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(R.s(10)),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(R.s(12)),
                ),
                child: Row(
                  children: [
                    Text(group.emoji, style: TextStyle(fontSize: R.t(20))),
                    SizedBox(width: R.s(10)),
                    Expanded(
                      child: Text(
                        '${group.name} • ${members.length} members',
                        style: TextStyle(
                          fontSize: R.t(13),
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: R.s(14)),
              // Amount
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: R.s(14), vertical: R.s(10)),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(R.md),
                ),
                child: TextFormField(
                  controller: _amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(
                    fontSize: R.t(30),
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                  decoration: InputDecoration(
                    prefixText: '\u20b9 ',
                    prefixStyle: TextStyle(
                      fontSize: R.t(30),
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                    hintText: '0',
                    hintStyle: TextStyle(
                      fontSize: R.t(30),
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryLight,
                    ),
                    border: InputBorder.none,
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: Validators.amount,
                ),
              ),
              SizedBox(height: R.s(14)),

              // Description
              DSTextField(
                controller: _descCtrl,
                label: 'Description',
                hint: 'e.g., Dinner at restaurant',
                prefixIcon: const Icon(Icons.description_outlined),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _showNoteField = !_showNoteField;
                    });
                  },
                  icon: Icon(
                    _showNoteField ? Icons.remove_rounded : Icons.add_rounded,
                    size: R.s(16),
                  ),
                  label: Text(_showNoteField ? 'Hide note' : 'Add note'),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: _showNoteField || _noteCtrl.text.trim().isNotEmpty
                    ? Padding(
                        key: const ValueKey('note-open'),
                        padding: EdgeInsets.only(bottom: R.s(12)),
                        child: DSTextField(
                          controller: _noteCtrl,
                          label: 'Note (optional)',
                          hint: 'Add context, location, or tags',
                          prefixIcon: const Icon(Icons.sticky_note_2_outlined),
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey('note-closed')),
              ),
              SizedBox(height: R.s(8)),

              // Paid By
              Text(
                'Paid By',
                style: TextStyle(
                    fontSize: R.t(13),
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant),
              ),
              SizedBox(height: R.s(8)),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: members.map((m) {
                  final selected = _paidByMemberId == m.id;
                  return GestureDetector(
                    onTap: () => setState(() => _paidByMemberId = m.id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: EdgeInsets.symmetric(
                          horizontal: R.md, vertical: R.sm),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary
                            : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(R.s(24)),
                        border: Border.all(
                          color: selected
                              ? colorScheme.primary
                              : colorScheme.outlineVariant,
                        ),
                      ),
                      child: Text(
                        m.handle,
                        style: TextStyle(
                          fontSize: R.t(13),
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? colorScheme.onPrimary
                              : colorScheme.onSurface,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: R.s(14)),

              // Split Type
              Text(
                'How to Split',
                style: TextStyle(
                    fontSize: R.t(13),
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant),
              ),
              SizedBox(height: R.s(8)),
              Wrap(
                spacing: R.s(8),
                runSpacing: R.s(8),
                children: SplitType.values.map((st) {
                  final selected = _splitType == st;
                  return ChoiceChip(
                    label: Text(
                      st.label,
                      style: TextStyle(
                        fontSize: R.t(12),
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? colorScheme.onPrimary
                            : colorScheme.onSurface,
                      ),
                    ),
                    selected: selected,
                    showCheckmark: false,
                    selectedColor: colorScheme.primary,
                    backgroundColor: colorScheme.surfaceContainerHigh,
                    side: BorderSide(
                      color:
                          selected ? colorScheme.primary : colorScheme.outline,
                    ),
                    onSelected: (_) => setState(() => _splitType = st),
                  );
                }).toList(),
              ),
              SizedBox(height: R.s(8)),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: R.s(12),
                  vertical: R.s(10),
                ),
                decoration: BoxDecoration(
                  color:
                      _splitHintColor(context, members).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(R.s(10)),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: Text(
                    _splitHint(members),
                    key: ValueKey('${_splitType.name}-${_splitHint(members)}'),
                    style: TextStyle(
                      fontSize: R.t(12),
                      fontWeight: FontWeight.w700,
                      color: _splitHintColor(context, members),
                    ),
                  ),
                ),
              ),

              if (_splitType == SplitType.equal &&
                  members.length > 1 &&
                  _enteredAmount > 0)
                Container(
                  margin: EdgeInsets.only(top: R.s(14)),
                  padding: EdgeInsets.all(R.s(12)),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(R.s(12)),
                  ),
                  child: Column(
                    children: [
                      ...members.map((m) {
                        final perHead =
                            (double.tryParse(_amountCtrl.text.trim()) ?? 0) /
                                members.length;
                        return Padding(
                          padding: EdgeInsets.symmetric(vertical: R.s(4)),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  m.handle,
                                  style: TextStyle(
                                    fontSize: R.t(13),
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              Text(
                                '\u20b9 ${perHead.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: R.t(13),
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),

              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: _splitType == SplitType.equal
                    ? const SizedBox.shrink(key: ValueKey('split-equal'))
                    : Column(
                        key: ValueKey('split-${_splitType.name}'),
                        children: [
                          SizedBox(height: R.s(14)),
                          if (_splitType == SplitType.incomeRatio)
                            Padding(
                              padding: EdgeInsets.only(bottom: R.s(8)),
                              child: Text(
                                'Enter each member\'s monthly income. Expense is split proportionally.',
                                style: TextStyle(
                                    fontSize: R.t(12),
                                    color: colorScheme.onSurfaceVariant),
                              ),
                            ),
                          ...members.map((m) {
                            return Padding(
                              padding: EdgeInsets.only(bottom: R.s(8)),
                              child: Row(
                                children: [
                                  Container(
                                    width: R.s(34),
                                    height: R.s(34),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryExtraLight,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Builder(builder: (_) {
                                        final handle = m.handle;
                                        final seed = handle.startsWith('@')
                                            ? handle.substring(1)
                                            : handle;
                                        final letter = seed.isNotEmpty
                                            ? seed[0].toUpperCase()
                                            : '?';
                                        return Text(
                                          letter,
                                          style: TextStyle(
                                            fontSize: R.t(13),
                                            fontWeight: FontWeight.w700,
                                            color: colorScheme.primary,
                                          ),
                                        );
                                      }),
                                    ),
                                  ),
                                  SizedBox(width: R.s(10)),
                                  Expanded(
                                    child: Text(
                                      m.handle,
                                      style: TextStyle(
                                        fontSize: R.t(13),
                                        fontWeight: FontWeight.w600,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 98,
                                    child: TextFormField(
                                      controller: _customControllers[m.id],
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      onChanged: (_) => setState(() {}),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: R.t(14),
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                      decoration: InputDecoration(
                                        prefixText:
                                            (_splitType == SplitType.custom ||
                                                    _splitType ==
                                                        SplitType.incomeRatio)
                                                ? '\u20b9 '
                                                : null,
                                        suffixText:
                                            _splitType == SplitType.percentage
                                                ? '%'
                                                : null,
                                        filled: true,
                                        fillColor: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest,
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(R.s(10)),
                                          borderSide: BorderSide.none,
                                        ),
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: R.s(12),
                                            vertical: R.s(8)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
              ),
              SizedBox(height: R.s(20)),

              DSButton(
                label: 'Add Expense',
                onPressed: _save,
                isLoading: _isLoading,
                fullWidth: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension on SplitType {
  String get label => switch (this) {
        SplitType.equal => 'Equal',
        SplitType.custom => 'Custom',
        SplitType.percentage => 'Percent',
        SplitType.incomeRatio => 'Income',
      };
}
