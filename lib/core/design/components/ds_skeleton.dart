import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../utils/responsive.dart';
import '../app_radius.dart';

class DSSkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  const DSSkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final colors = Theme.of(context).colorScheme;
    return Shimmer.fromColors(
      baseColor: colors.surfaceContainerHighest,
      highlightColor: colors.surface,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: borderRadius ?? AppRadius.smAll,
        ),
      ),
    );
  }
}

class DSSkeletonCard extends StatelessWidget {
  final double height;
  final double? width;

  const DSSkeletonCard({super.key, this.height = 80, this.width});

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final colors = Theme.of(context).colorScheme;
    return Shimmer.fromColors(
      baseColor: colors.surfaceContainerHighest,
      highlightColor: colors.surface,
      child: Container(
        height: height,
        width: width ?? double.infinity,
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: colors.outlineVariant),
        ),
      ),
    );
  }
}

class DSSkeletonTransactionTile extends StatelessWidget {
  const DSSkeletonTransactionTile({super.key});

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final colors = Theme.of(context).colorScheme;
    return Shimmer.fromColors(
      baseColor: colors.surfaceContainerHighest,
      highlightColor: colors.surface,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: R.s(10)),
        child: Row(
          children: [
            Container(
              width: R.s(44),
              height: R.s(44),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: AppRadius.mdAll,
              ),
            ),
            SizedBox(width: R.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: R.s(13),
                    width: R.s(140),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: AppRadius.smAll,
                    ),
                  ),
                  SizedBox(height: R.s(6)),
                  Container(
                    height: R.s(11),
                    width: R.s(80),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: AppRadius.smAll,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: R.sm),
            Container(
              height: R.s(14),
              width: R.s(60),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: AppRadius.smAll,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DSSkeletonList extends StatelessWidget {
  final int count;
  const DSSkeletonList({super.key, this.count = 5});

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: count,
      separatorBuilder: (_, __) => SizedBox(height: R.xs),
      itemBuilder: (_, __) => const DSSkeletonTransactionTile(),
    );
  }
}
