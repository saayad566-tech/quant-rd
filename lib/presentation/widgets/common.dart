/// Reusable UI primitives built on the design tokens.
library;

import 'dart:ui' show FontFeature, ImageFilter;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';

/// A translucent, blurred surface with a hairline border — the core visual
/// building block of the app.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final bool strong;

  /// When true, a real backdrop blur is applied. This is expensive (it forces a
  /// backdrop re-sample every frame), so it is reserved for a handful of hero
  /// surfaces. List items and grids use the fast translucent style instead,
  /// which keeps scrolling at a full 60/120 Hz.
  final bool blur;
  final Color? tint;
  final VoidCallback? onTap;
  final Border? border;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Spacing.md),
    this.margin,
    this.radius = Radii.md,
    this.strong = false,
    this.blur = false,
    this.tint,
    this.onTap,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final decorated = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: tint ?? (strong ? c.glassFill.withValues(alpha: 0.12) : c.glassFill),
        borderRadius: BorderRadius.circular(radius),
        border: border ?? Border.all(color: c.glassBorder),
        boxShadow: Elevation.soft,
      ),
      child: child,
    );
    final content = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: blur
          ? RepaintBoundary(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: decorated,
              ),
            )
          : decorated,
    );
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: onTap == null
          ? content
          : MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(onTap: onTap, child: content),
            ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const SectionHeader({super.key, required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: Spacing.xxs),
                Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.action});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: c.accent.withValues(alpha: 0.12),
                borderRadius: Radii.rMd,
                border: Border.all(color: c.accent.withValues(alpha: 0.3)),
              ),
              child: Icon(icon, color: c.accent, size: 30),
            ),
            const SizedBox(height: Spacing.md),
            Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: Spacing.xs),
            Text(message, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
            if (action != null) ...[
              const SizedBox(height: Spacing.md),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorView({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: c.danger, size: 36),
            const SizedBox(height: Spacing.sm),
            Text(message, style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: Spacing.md),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  final String? label;
  const LoadingView({super.key, this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(strokeWidth: 2.6),
          ),
          if (label != null) ...[
            const SizedBox(height: Spacing.sm),
            Text(label!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

/// A labelled metric with an optional delta and accent colour.
class MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String? delta;
  final Color? accent;
  final IconData? icon;

  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    this.delta,
    this.accent,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = accent ?? c.accent;
    return GlassCard(
      padding: const EdgeInsets.all(Spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: color),
                const SizedBox(width: Spacing.xxs),
              ],
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.xxs),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: 26,
                      color: color,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
              ),
            ),
          ),
          if (delta != null) ...[
            const SizedBox(height: 2),
            Text(delta!, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class Pill extends StatelessWidget {
  final String label;
  final Color? color;
  final IconData? icon;

  const Pill({super.key, required this.label, this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final col = color ?? c.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: 5),
      decoration: BoxDecoration(
        color: col.withValues(alpha: 0.12),
        borderRadius: Radii.rPill,
        border: Border.all(color: col.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: col),
            const SizedBox(width: 4),
          ],
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: col, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// A small labelled form field wrapper with consistent spacing.
class FieldLabel extends StatelessWidget {
  final String label;
  final String? hint;
  final Widget child;

  const FieldLabel({super.key, required this.label, this.hint, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        if (hint != null) ...[
          const SizedBox(height: 2),
          Text(hint!, style: Theme.of(context).textTheme.bodySmall),
        ],
        const SizedBox(height: Spacing.xs),
        child,
      ],
    );
  }
}
