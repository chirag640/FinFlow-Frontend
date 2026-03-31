import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/components/ds_button.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/auth_interceptor.dart';
import '../../../../core/ui/error_feedback.dart';
import '../../../../core/utils/responsive.dart';
import '../providers/group_provider.dart';

class CreateGroupPage extends ConsumerStatefulWidget {
  const CreateGroupPage({super.key});

  @override
  ConsumerState<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends ConsumerState<CreateGroupPage> {
  final _nameCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  String _selectedEmoji = '👥';
  final List<Map<String, dynamic>> _selectedMembers = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _isLoading = false;
  Timer? _debounce;

  static const _emojis = [
    '👥',
    '🏠',
    '✈️',
    '🎉',
    '💼',
    '🍽️',
    '🏖️',
    '⚽',
    '🎓',
    '💑',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    _debounce?.cancel();
    if (val.trim().length < 2) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    _debounce = Timer(
        const Duration(milliseconds: 350), () => _searchUsers(val.trim()));
  }

  Future<void> _searchUsers(String q) async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get(
        ApiEndpoints.userSearch,
        queryParameters: {'username': q},
      );
      final list = (res.data['data'] as List?) ?? [];
      if (mounted) {
        setState(() {
          _searchResults = list.cast<Map<String, dynamic>>();
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _selectUser(Map<String, dynamic> user) {
    if (_selectedMembers.any((m) => m['id'] == user['id'])) return;
    setState(() {
      _selectedMembers.add(user);
      _searchResults = [];
      _searchCtrl.clear();
    });
  }

  Future<void> _create() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group name')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      await ref.read(groupProvider.notifier).createGroup(
            name: _nameCtrl.text.trim(),
            emoji: _selectedEmoji,
            memberUsers: _selectedMembers
                .map((m) => {
                      'userId': m['id'] as String,
                      'name': (m['name'] as String?) ??
                          (m['username'] as String? ?? 'Member'),
                    })
                .toList(),
          );
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final colorScheme = Theme.of(context).colorScheme;
    listenForProviderError<GroupState>(
      ref: ref,
      context: context,
      provider: groupProvider,
      errorSelector: (s) => s.error,
      onErrorShown: () {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      },
    );
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Create Group'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(R.s(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Emoji picker
            const _FieldLabel('GROUP ICON'),
            SizedBox(height: R.s(10)),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _emojis.map((e) {
                final selected = e == _selectedEmoji;
                return GestureDetector(
                  onTap: () => setState(() => _selectedEmoji = e),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: R.s(52),
                    height: R.s(52),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primaryExtraLight
                          : Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(R.s(14)),
                      border: Border.all(
                        color: selected ? AppColors.primary : AppColors.border,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(e, style: TextStyle(fontSize: R.t(24))),
                    ),
                  ),
                );
              }).toList(),
            ).animate().fadeIn(duration: 300.ms),
            SizedBox(height: R.s(24)),
            // Group name
            const _FieldLabel('GROUP NAME'),
            SizedBox(height: R.sm),
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              style: TextStyle(
                fontSize: R.t(16),
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'e.g. Goa Trip 2026',
                prefixText: '$_selectedEmoji  ',
                prefixStyle: TextStyle(fontSize: R.t(16)),
                filled: true,
                fillColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(R.s(14)),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(R.s(14)),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 2,
                  ),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: R.md,
                  vertical: R.s(14),
                ),
              ),
            ).animate(delay: 80.ms).fadeIn(duration: 300.ms),
            SizedBox(height: R.s(24)),
            // Members
            const _FieldLabel('ADD MEMBERS'),
            SizedBox(height: R.sm),
            // Search field
            TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search by username…',
                prefixIcon: const Icon(Icons.person_search_outlined),
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => setState(() {
                              _searchCtrl.clear();
                              _searchResults = [];
                            }),
                          )
                        : null,
                filled: true,
                fillColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(R.s(14)),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(R.s(14)),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 2,
                  ),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: R.md,
                  vertical: R.s(14),
                ),
              ),
            ).animate(delay: 120.ms).fadeIn(duration: 300.ms),
            // Live suggestions
            if (_searchResults.isNotEmpty) ...[
              SizedBox(height: R.s(6)),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(R.s(14)),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.symmetric(vertical: R.s(4)),
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _searchResults.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: AppColors.border,
                    indent: R.s(56),
                  ),
                  itemBuilder: (_, i) {
                    final user = _searchResults[i];
                    final alreadyAdded =
                        _selectedMembers.any((m) => m['id'] == user['id']);
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: R.s(18),
                        backgroundColor: AppColors.primaryExtraLight,
                        child: Text(
                          (user['username'] as String? ?? 'U')
                              .substring(0, 1)
                              .toUpperCase(),
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: R.t(14),
                          ),
                        ),
                      ),
                      title: Text(
                        '@${user['username'] ?? ''}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: R.t(14),
                          color: alreadyAdded
                              ? AppColors.textTertiary
                              : AppColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        user['name'] as String? ?? '',
                        style: TextStyle(fontSize: R.t(12)),
                      ),
                      trailing: alreadyAdded
                          ? Icon(Icons.check_circle_rounded,
                              color: AppColors.primary, size: R.s(18))
                          : null,
                      onTap: alreadyAdded ? null : () => _selectUser(user),
                    );
                  },
                ),
              ),
            ],
            // Selected member chips
            if (_selectedMembers.isNotEmpty) ...[
              SizedBox(height: R.s(12)),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MemberChip(name: 'You', isYou: true, onRemove: null),
                  ..._selectedMembers.map(
                    (m) => _MemberChip(
                      name: '@${m['username'] ?? m['name'] ?? 'Member'}',
                      isYou: false,
                      onRemove: () =>
                          setState(() => _selectedMembers.remove(m)),
                    ),
                  ),
                ],
              ),
            ] else ...[
              SizedBox(height: R.s(12)),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MemberChip(name: 'You', isYou: true, onRemove: null),
                ],
              ),
            ],
            SizedBox(height: R.s(40)),
            DSButton(
              label: 'Create Group',
              onPressed: _isLoading ? null : _create,
              isLoading: _isLoading,
              leadingIcon: Text(
                _selectedEmoji,
                style: TextStyle(fontSize: R.t(18)),
              ),
            ).animate(delay: 200.ms).fadeIn(duration: 300.ms),
            SizedBox(height: R.s(20)),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: R.t(11),
          fontWeight: FontWeight.w700,
          color: AppColors.textTertiary,
          letterSpacing: 1.2,
        ),
      );
}

class _MemberChip extends StatelessWidget {
  final String name;
  final bool isYou;
  final VoidCallback? onRemove;
  const _MemberChip({
    required this.name,
    required this.isYou,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: R.s(12), vertical: R.s(6)),
      decoration: BoxDecoration(
        color: isYou
            ? AppColors.primaryExtraLight
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: isYou ? AppColors.primary : AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: TextStyle(
              fontSize: R.t(13),
              fontWeight: FontWeight.w600,
              color: isYou ? AppColors.primaryDark : AppColors.textPrimary,
            ),
          ),
          if (onRemove != null) ...[
            SizedBox(width: R.s(6)),
            GestureDetector(
              onTap: onRemove,
              child: Icon(
                Icons.close_rounded,
                size: R.s(14),
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
