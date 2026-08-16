import 'package:flutter/material.dart';

/// يخلي محتوى Column يتمركز عمودياً لما فيه مساحة كافية (زي المعتاد
/// بالوضع الطولي)، وبدل ما ينقص/يُقصّ من الشاشة لما المساحة تضيق (وضع
/// landscape/العرض على جوال) يصير قابل للتمرير بدل ما يطيح أي جزء من
/// المحتوى (كان بق حقيقي بأكثر من شاشة، راجعي NEXT_STEPS.md).
///
/// استخدميه بدل [Column] مباشرة داخل [SafeArea]/[Padding] بأي شاشة فيها
/// [Spacer] أو `mainAxisAlignment: MainAxisAlignment.center` بمحتوى قد
/// يطول عن الشاشة بوضع العرض.
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
