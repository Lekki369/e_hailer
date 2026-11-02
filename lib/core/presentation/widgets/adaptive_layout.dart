import 'package:flutter/material.dart';

abstract final class AppBreakpoints {
  static const medium = 600.0;
  static const expanded = 840.0;
}

/// Bounded content measured against the available window, including split view.
class AdaptiveContent extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final bool scrollable;
  final EdgeInsetsGeometry? padding;
  const AdaptiveContent({
    super.key,
    required this.child,
    this.maxWidth = 1120,
    this.scrollable = true,
    this.padding,
  });
  @override
  Widget build(BuildContext context) {
    final content = LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(
            padding:
                padding ??
                EdgeInsets.all(
                  constraints.maxWidth < AppBreakpoints.medium ? 16 : 32,
                ),
            child: SizedBox(width: double.infinity, child: child),
          ),
        ),
      ),
    );
    return SafeArea(
      child: scrollable
          ? SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: content,
            )
          : content,
    );
  }
}

class AdaptiveColumns extends StatelessWidget {
  final Widget primary;
  final Widget secondary;
  const AdaptiveColumns({
    super.key,
    required this.primary,
    required this.secondary,
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide =
          constraints.maxWidth >= AppBreakpoints.expanded &&
          MediaQuery.textScalerOf(context).scale(16) <= 24;
      return wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: primary),
                const SizedBox(width: 24),
                Expanded(flex: 2, child: secondary),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [primary, const SizedBox(height: 24), secondary],
            );
    },
  );
}

class FeedbackPanel extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;
  const FeedbackPanel({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
  });
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Text(message),
          if (onRetry != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ),
        ],
      ),
    ),
  );
}
