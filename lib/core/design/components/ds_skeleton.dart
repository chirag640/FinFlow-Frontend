import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../app_colors.dart';
import '../app_radius.dart';
import '../../utils/responsive.dart';

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
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceVariant,
      highlightColor: AppColors.surface,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
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
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceVariant,
      highlightColor: AppColors.surface,
      child: Container(
        height: height,
        width: width ?? double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: AppColors.border),
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
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceVariant,
      highlightColor: AppColors.surface,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: R.s(10)),
        child: Row(
          children: [
            Container(
              width: R.s(44),
              height: R.s(44),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
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
                      color: AppColors.surfaceVariant,
                      borderRadius: AppRadius.smAll,
                    ),
                  ),
                  SizedBox(height: R.s(6)),
                  Container(
                    height: R.s(11),
                    width: R.s(80),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
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
                color: AppColors.surfaceVariant,
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
