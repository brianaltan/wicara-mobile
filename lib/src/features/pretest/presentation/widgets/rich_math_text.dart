import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../../../../core/theme/wicara_colors.dart';

class RichMathText extends StatelessWidget {
  const RichMathText(
    this.text, {
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    super.key,
  });

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final baseStyle =
        style ?? DefaultTextStyle.of(context).style.copyWith(height: 1.3);
    return Text.rich(
      TextSpan(children: _spans(text, baseStyle)),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
    );
  }
}

List<InlineSpan> _spans(String text, TextStyle baseStyle) {
  final spans = <InlineSpan>[];
  final formulaRegex = RegExp(
    r'(\$\$.*?\$\$|\$.*?\$|\\\(.*?\\\)|\\\[.*?\\\]|\\begin\{(?:bmatrix|pmatrix|matrix|vmatrix|Vmatrix)\}.*?\\end\{(?:bmatrix|pmatrix|matrix|vmatrix|Vmatrix)\})',
    dotAll: true,
  );
  var cursor = 0;
  for (final match in formulaRegex.allMatches(text)) {
    if (match.start > cursor) {
      spans.addAll(_markdownSpans(text.substring(cursor, match.start), baseStyle));
    }
    spans.add(_mathSpan(match.group(0) ?? '', baseStyle));
    cursor = match.end;
  }
  if (cursor < text.length) {
    spans.addAll(_markdownSpans(text.substring(cursor), baseStyle));
  }
  return spans;
}

List<InlineSpan> _markdownSpans(String text, TextStyle baseStyle) {
  final spans = <InlineSpan>[];
  final boldRegex = RegExp(r'\*\*(.+?)\*\*');
  var cursor = 0;
  for (final match in boldRegex.allMatches(text)) {
    if (match.start > cursor) {
      spans.add(TextSpan(text: text.substring(cursor, match.start), style: baseStyle));
    }
    spans.add(
      TextSpan(
        text: match.group(1) ?? '',
        style: baseStyle.copyWith(fontWeight: FontWeight.w800),
      ),
    );
    cursor = match.end;
  }
  if (cursor < text.length) {
    spans.add(TextSpan(text: text.substring(cursor), style: baseStyle));
  }
  return spans;
}

InlineSpan _mathSpan(String value, TextStyle baseStyle) {
  final formula = _stripFormulaDelimiters(value);
  final display = value.trim().startsWith(r'$$') || value.trim().startsWith(r'\[');
  final mathStyle = display ? MathStyle.display : MathStyle.text;
  return WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: Padding(
      padding: EdgeInsets.symmetric(
        horizontal: display ? 2 : 1,
        vertical: display ? 5 : 1,
      ),
      child: Math.tex(
        formula,
        mathStyle: mathStyle,
        textStyle: baseStyle.copyWith(
          color: WicaraColors.primaryDeep,
          fontWeight: FontWeight.w700,
        ),
        onErrorFallback: (error) => Text(
          _fallbackFormulaText(formula),
          style: baseStyle.copyWith(
            color: WicaraColors.primaryDeep,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w700,
            backgroundColor: WicaraColors.primarySoft.withValues(alpha: 0.55),
          ),
        ),
      ),
    ),
  );
}

String _stripFormulaDelimiters(String value) {
  var text = value.trim();
  if (text.startsWith(r'$$') && text.endsWith(r'$$') && text.length >= 4) {
    return text.substring(2, text.length - 2).trim();
  }
  if (text.startsWith(r'$') && text.endsWith(r'$') && text.length >= 2) {
    return text.substring(1, text.length - 1).trim();
  }
  if (text.startsWith(r'\(') && text.endsWith(r'\)') && text.length >= 4) {
    return text.substring(2, text.length - 2).trim();
  }
  if (text.startsWith(r'\[') && text.endsWith(r'\]') && text.length >= 4) {
    return text.substring(2, text.length - 2).trim();
  }
  return text;
}

String _fallbackFormulaText(String value) {
  return value
      .replaceAll(r'\to', '->')
      .replaceAll(r'\times', 'x')
      .replaceAll(r'\cdot', '*')
      .replaceAll(r'\frac', 'frac')
      .replaceAll('{', '')
      .replaceAll('}', '');
}
