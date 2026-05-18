import 'package:flutter/material.dart';

import '../../../core/theme/wicara_colors.dart';
import '../data/litert_gemma_runtime.dart';
import '../domain/edge_ai_runtime.dart';

class EdgeAiStatusChip extends StatefulWidget {
  const EdgeAiStatusChip({
    this.runtime = defaultEdgeAiRuntime,
    this.onTap,
    super.key,
  });

  final EdgeAiRuntime runtime;
  final VoidCallback? onTap;

  @override
  State<EdgeAiStatusChip> createState() => _EdgeAiStatusChipState();
}

class _EdgeAiStatusChipState extends State<EdgeAiStatusChip> {
  String _label = 'checking';
  Color _color = WicaraColors.secondary;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final status = await widget.runtime.getStatus();
      if (!mounted) {
        return;
      }
      setState(() {
        if (status.isReady) {
          _label = 'ready';
          _color = WicaraColors.accentMint;
        } else if (!status.available) {
          _label = 'unavailable';
          _color = WicaraColors.accentCoral;
        } else if (!status.defaultModelExists) {
          _label = 'needs-install';
          _color = const Color(0xFFF4A44E);
        } else {
          _label = 'needs-init';
          _color = const Color(0xFFF4A44E);
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _label = 'unknown';
        _color = WicaraColors.secondary;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: _color,
          fontWeight: FontWeight.w800,
          fontSize: 10.5,
        ),
      ),
    );
    if (widget.onTap == null) {
      return chip;
    }
    return InkWell(
      onTap: () {
        widget.onTap?.call();
        _refresh();
      },
      borderRadius: BorderRadius.circular(999),
      child: chip,
    );
  }
}
