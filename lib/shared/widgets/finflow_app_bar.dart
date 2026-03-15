import 'package:flutter/material.dart';
import '../../core/design/app_colors.dart';
import '../../core/utils/responsive.dart';

class FinFlowAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showLogo;
  final Widget? bottom;
  final double bottomHeight;
  final bool pinned;
  final bool floating;

  const FinFlowAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showLogo = false,
    this.bottom,
    this.bottomHeight = 0,
    this.pinned = true,
    this.floating = false,
  });

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + bottomHeight);

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: showLogo ? 0 : null,
      title: showLogo
          ? Row(
              children: [
                SizedBox(width: R.md),
                Container(
                  width: R.s(28),
                  height: R.s(28),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(R.s(8)),
                  ),
                  child: Center(
                    child: Text(
                      '₹',
                      style: TextStyle(
                        fontSize: R.t(16),
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: R.sm),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: R.t(20),
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            )
          : Text(
              title,
              style: TextStyle(
                fontSize: R.t(20),
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
      actions: actions,
      bottom: bottom != null
          ? PreferredSize(
              preferredSize: Size.fromHeight(bottomHeight),
              child: bottom!,
            )
          : null,
    );
  }
}
