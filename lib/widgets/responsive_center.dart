import 'package:flutter/material.dart';

/// Makes a Column's content center vertically when there's enough room (as
/// usual in portrait), and instead of shrinking/clipping when space gets
/// tight (landscape orientation on a phone), becomes scrollable instead of
/// losing any part of the content (was a real bug across several screens,
/// see NEXT_STEPS.md).
///
/// Use this instead of [Column] directly inside [SafeArea]/[Padding] on
/// any screen with a [Spacer] or `mainAxisAlignment: MainAxisAlignment.center`
/// whose content might exceed the screen height in landscape.
class ResponsiveCenter extends StatelessWidget {
  const ResponsiveCenter({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.all(24),
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  final List<Widget> children;
  final EdgeInsets padding;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - padding.vertical,
            ),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: crossAxisAlignment,
                children: children,
              ),
            ),
          ),
        );
      },
    );
  }
}
