import 'package:material_ui/material_ui.dart';
import '../app_scope.dart';
import '../theme/one_ui_theme.dart';
import '../utils/transit_format.dart';

/// Samsung One UI 9 inspired collapsible scaffold with large thumb-reachable title header.
class OneUiScaffold extends StatelessWidget {
  const OneUiScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.showBackButton = true,
    this.expandedHeight = 148,
    this.pinnedTopWidget,
    required this.slivers,
    this.floatingActionButton,
    this.onRefresh,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final bool showBackButton;
  final double expandedHeight;
  final Widget? pinnedTopWidget;
  final List<Widget> slivers;
  final Widget? floatingActionButton;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final p = context.oneUi;
    final canPop = showBackButton && Navigator.of(context).canPop();

    final scrollView = CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        SliverAppBar(
          expandedHeight: expandedHeight,
          pinned: true,
          stretch: true,
          automaticallyImplyLeading: false,
          backgroundColor: p.canvas,
          surfaceTintColor: Colors.transparent,
          leading: canPop
              ? Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: p.ink),
                    onPressed: () => Navigator.of(context).maybePop(),
                    tooltip: 'Wstecz',
                  ),
                )
              : null,
          actions: [
            ...actions,
            const SizedBox(width: 8),
          ],
          flexibleSpace: LayoutBuilder(
            builder: (context, constraints) {
              final topPad = MediaQuery.paddingOf(context).top;
              final minH = kToolbarHeight + topPad;
              final maxH = expandedHeight + topPad;
              final t = ((constraints.maxHeight - minH) / (maxH - minH).clamp(1.0, 999.0))
                  .clamp(0.0, 1.0);
              final collapsedOpacity = (1.0 - t * 1.6).clamp(0.0, 1.0);
              final expandedOpacity = ((t - 0.25) / 0.75).clamp(0.0, 1.0);

              return Stack(
                fit: StackFit.expand,
                children: [
                  Positioned(
                    left: canPop ? 52 : 20,
                    right: 80,
                    top: topPad,
                    height: kToolbarHeight,
                    child: Opacity(
                      opacity: collapsedOpacity,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: p.ink,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 22,
                    right: 22,
                    bottom: 14,
                    child: Opacity(
                      opacity: expandedOpacity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 29,
                              fontWeight: FontWeight.w700,
                              height: 1.12,
                              letterSpacing: -0.7,
                              color: p.ink,
                            ),
                          ),
                          if (subtitle != null && subtitle!.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Text(
                              subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                                color: p.inkSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        if (pinnedTopWidget != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: pinnedTopWidget!,
            ),
          ),
        SliverToBoxAdapter(
          child: OfflineStatusStrip(onRetry: onRefresh),
        ),
        ...slivers,
        const SliverToBoxAdapter(child: SizedBox(height: 36)),
      ],
    );

    return Scaffold(
      backgroundColor: p.canvas,
      floatingActionButton: floatingActionButton,
      body: onRefresh != null
          ? RefreshIndicator(
              color: p.accent,
              backgroundColor: p.card,
              onRefresh: onRefresh!,
              child: scrollView,
            )
          : scrollView,
    );
  }
}

/// Deeply rounded One UI 9 grouped surface card without harsh shadows.
class OneUiCard extends StatelessWidget {
  const OneUiCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.radius = 26,
    this.backgroundColor,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final double radius;
  final Color? backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final p = context.oneUi;
    final bg = backgroundColor ?? p.card;
    final border = borderColor ?? p.divider.withValues(alpha: 0.7);
    final br = BorderRadius.circular(radius);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: br,
        border: Border.all(color: border, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: br,
        clipBehavior: Clip.antiAlias,
        child: onTap != null
            ? InkWell(
                onTap: onTap,
                borderRadius: br,
                child: Padding(padding: padding, child: child),
              )
            : Padding(padding: padding, child: child),
      ),
    );
  }
}

/// One UI section label placed just above a rounded card group.
class OneUiSectionLabel extends StatelessWidget {
  const OneUiSectionLabel(
    this.text, {
    super.key,
    this.trailing,
  });

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.oneUi;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 16, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
                color: p.inkSecondary,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Soft pill search input matching Samsung One UI 9 search bars.
class OneUiSearchBar extends StatelessWidget {
  const OneUiSearchBar({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    this.onClear,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final p = context.oneUi;
    return Container(
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.divider, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 22, color: p.inkSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: TextStyle(fontSize: 15.5, color: p.ink),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(fontSize: 15, color: p.inkSecondary),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            IconButton(
              icon: Icon(Icons.close_rounded, size: 19, color: p.inkSecondary),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: () {
                controller.clear();
                onChanged('');
                onClear?.call();
              },
            ),
        ],
      ),
    );
  }
}

/// Horizontal One UI pill segmented control.
class OneUiSegmentedPills<T> extends StatelessWidget {
  const OneUiSegmentedPills({
    super.key,
    required this.selected,
    required this.options,
    required this.onSelected,
  });

  final T selected;
  final List<(T value, String label, Color? accent)> options;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final p = context.oneUi;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.cardAlt,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: p.divider, width: 1),
      ),
      child: Row(
        children: options.map((opt) {
          final isSel = opt.$1 == selected;
          final activeColor = opt.$3 ?? p.accent;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelected(opt.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                decoration: BoxDecoration(
                  color: isSel ? activeColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: Text(
                  opt.$2,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w600,
                    color: isSel ? Colors.white : p.inkSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Bordered uniform line badge with neutral One UI surface and operator-colored outline.
class LineBadge extends StatelessWidget {
  const LineBadge({
    super.key,
    required this.shortName,
    required this.operatorId,
    this.compact = false,
  });

  final String shortName;
  final String operatorId;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = context.oneUi;
    final night = isNightLine(operatorId, shortName);
    final borderColor = night
        ? p.ink
        : (operatorId == 'ztm' ? p.ztmOrange : p.pksBlue);

    return Container(
      width: compact ? 50 : 62,
      height: compact ? 30 : 38,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: p.cardAlt,
        borderRadius: BorderRadius.circular(compact ? 11 : 14),
        border: Border.all(
          color: night ? p.ztmOrange : borderColor,
          width: 1.8,
        ),
      ),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          shortName,
          maxLines: 1,
          style: TextStyle(
            fontSize: compact ? 13.5 : 16.5,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
            color: p.ink,
          ),
        ),
      ),
    );
  }
}

/// Clear operator badge distinguishing MPK (orange) and MKS/PKS (blue).
class OperatorTag extends StatelessWidget {
  const OperatorTag({
    super.key,
    required this.operatorId,
    this.routeShortName = '',
  });

  final String operatorId;
  final String routeShortName;

  @override
  Widget build(BuildContext context) {
    final p = context.oneUi;
    final isZtm = operatorId == 'ztm';
    final fg = isZtm ? p.ztmOrange : p.pksBlue;
    final bg = isZtm ? p.ztmSoft : p.pksSoft;
    final label = routeShortName.isNotEmpty
        ? operatorDisplayLabel(operatorId, routeShortName)
        : (isZtm ? 'MPK' : 'PKS');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

/// Indicator showing whether live GPS bus location is available for this departure/trip.
class LiveLocationPill extends StatelessWidget {
  const LiveLocationPill({
    super.key,
    required this.hasLiveLocation,
    required this.isRealtime,
    this.verbose = false,
  });

  final bool hasLiveLocation;
  final bool isRealtime;
  final bool verbose;

  @override
  Widget build(BuildContext context) {
    final p = context.oneUi;
    if (hasLiveLocation) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: p.liveGreenSoft,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.gps_fixed_rounded, size: 12, color: p.liveGreen),
            const SizedBox(width: 4),
            Text(
              verbose ? 'GPS na żywo' : 'GPS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: p.liveGreen,
              ),
            ),
          ],
        ),
      );
    }
    if (isRealtime) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: p.accentSoft,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sensors_rounded, size: 12, color: p.accent),
            const SizedBox(width: 4),
            Text(
              verbose ? 'Tylko czas LIVE' : 'LIVE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: p.accent,
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: p.cardAlt,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        verbose ? 'Brak GPS · Rozkład' : 'Rozkład',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: p.inkSecondary,
        ),
      ),
    );
  }
}

/// Delay status pill (+3 min, Planowo, -1 min).
class DelayPill extends StatelessWidget {
  const DelayPill({
    super.key,
    required this.delaySeconds,
    required this.isRealtime,
  });

  final int? delaySeconds;
  final bool isRealtime;

  @override
  Widget build(BuildContext context) {
    final p = context.oneUi;
    if (!isRealtime) return const SizedBox.shrink();
    final sec = delaySeconds ?? 0;
    final min = (sec / 60).round();

    late final String label;
    late final Color fg;
    late final Color bg;
    if (min >= 2) {
      label = '+$min min';
      fg = p.dangerRed;
      bg = p.dangerSoft;
    } else if (min <= -2) {
      label = '$min min';
      fg = p.warnAmber;
      bg = p.warnAmber.withValues(alpha: 0.14);
    } else {
      label = 'Planowo';
      fg = p.liveGreen;
      bg = p.liveGreenSoft;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9)),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

/// Shared loading / error / empty state view styled as a One UI 9 rounded card.
class OneUiStatusCard extends StatelessWidget {
  const OneUiStatusCard({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final p = context.oneUi;
    return OneUiCard(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: p.accentSoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, size: 28, color: p.accent),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: p.ink),
          ),
          if (message != null && message!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: p.inkSecondary),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: p.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              ),
              child: Text(actionLabel!, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact One UI banner rendered whenever API requests run in offline mode.
class OfflineStatusStrip extends StatelessWidget {
  const OfflineStatusStrip({super.key, this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final api = AppScope.maybeOf(context)?.api;
    if (api == null) return const SizedBox.shrink();

    return ValueListenableBuilder<bool>(
      valueListenable: api.isOffline,
      builder: (context, offline, _) {
        if (!offline) return const SizedBox.shrink();
        final p = context.oneUi;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: p.warnAmber.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: p.warnAmber.withValues(alpha: 0.36)),
            ),
            child: Row(
              children: [
                Icon(Icons.cloud_off_rounded, size: 17, color: p.warnAmber),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Tryb offline · zapisane rozkłady',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: p.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    if (onRetry != null) {
                      onRetry!();
                    } else {
                      api.syncStaticVersion(force: true);
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: p.warnAmber.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Odśwież',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: p.warnAmber,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
