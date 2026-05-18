import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/theme/wicara_colors.dart';

enum _CanvasTool { pen, hand, eraser, shape }

enum _CanvasShapeType { line, arrow, rectangle }

enum _CanvasActionType { add, erase }

class CanvasWorkSnapshot {
  CanvasWorkSnapshot._({
    required this.version,
    required this.elementCount,
    required this.hasAttachment,
    required this.showGrid,
    required this.canvasSize,
    required List<_CanvasElement> elements,
  }) : _elements = List<_CanvasElement>.unmodifiable(elements);

  final int version;
  final int elementCount;
  final bool hasAttachment;
  final bool showGrid;
  final Size canvasSize;
  final List<_CanvasElement> _elements;
}

Future<Uint8List?> renderCanvasSnapshotPng(
  CanvasWorkSnapshot snapshot, {
  int maxEdgePx = 1080,
}) async {
  final sceneSize = snapshot.canvasSize == Size.zero
      ? const Size(360, 240)
      : snapshot.canvasSize;
  final longestEdge = math.max(sceneSize.width, sceneSize.height);
  if (longestEdge <= 0) {
    return null;
  }
  final scale = (maxEdgePx / longestEdge).clamp(0.25, 1.0).toDouble();
  final outputSize = Size(sceneSize.width * scale, sceneSize.height * scale);

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Offset.zero & outputSize);
  final painter = _WorkCanvasPainter(
    elements: snapshot._elements,
    hasAttachment: snapshot.hasAttachment,
    showGrid: snapshot.showGrid,
    zoom: scale,
    panOffset: Offset.zero,
    sceneSize: sceneSize,
    previewShape: null,
  );
  painter.paint(canvas, outputSize);
  final picture = recorder.endRecording();
  final imageWidth = outputSize.width.ceil().clamp(1, maxEdgePx).toInt();
  final imageHeight = outputSize.height.ceil().clamp(1, maxEdgePx).toInt();
  final image = await picture.toImage(imageWidth, imageHeight);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return byteData?.buffer.asUint8List();
}

class CanvasWorkPreview extends StatelessWidget {
  const CanvasWorkPreview({required this.snapshot, super.key});

  final CanvasWorkSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFAFCFF),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: WicaraColors.line),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final snapshotSize = snapshot.canvasSize == Size.zero
                ? const Size(360, 240)
                : snapshot.canvasSize;
            final scale = math.min(
              constraints.maxWidth / snapshotSize.width,
              constraints.maxHeight / snapshotSize.height,
            );
            final fittedSize = Size(
              snapshotSize.width * scale,
              snapshotSize.height * scale,
            );
            final panOffset = Offset(
              (constraints.maxWidth - fittedSize.width) / 2,
              (constraints.maxHeight - fittedSize.height) / 2,
            );

            return CustomPaint(
              painter: _WorkCanvasPainter(
                elements: snapshot._elements,
                hasAttachment: snapshot.hasAttachment,
                showGrid: snapshot.showGrid,
                zoom: scale,
                panOffset: panOffset,
                sceneSize: snapshotSize,
                previewShape: null,
              ),
              child: const SizedBox.expand(),
            );
          },
        ),
      ),
    );
  }
}

abstract class _CanvasElement {
  const _CanvasElement();

  bool hitTest(Offset point, double radius);
}

class _CanvasStroke extends _CanvasElement {
  _CanvasStroke({
    required this.points,
    required this.color,
    required this.strokeWidth,
  });

  final List<Offset> points;
  final Color color;
  final double strokeWidth;

  @override
  bool hitTest(Offset point, double radius) {
    final hitRadius = radius + strokeWidth / 2;
    if (points.length == 1) {
      return (points.first - point).distance <= hitRadius;
    }

    for (var i = 1; i < points.length; i++) {
      if (_distanceToSegment(point, points[i - 1], points[i]) <= hitRadius) {
        return true;
      }
    }
    return false;
  }
}

class _CanvasShape extends _CanvasElement {
  const _CanvasShape({
    required this.type,
    required this.start,
    required this.end,
    required this.color,
    required this.strokeWidth,
  });

  final _CanvasShapeType type;
  final Offset start;
  final Offset end;
  final Color color;
  final double strokeWidth;

  Rect get rect => Rect.fromPoints(start, end);

  @override
  bool hitTest(Offset point, double radius) {
    final hitRadius = radius + strokeWidth / 2;
    if (type == _CanvasShapeType.rectangle) {
      final targetRect = rect;
      if (!targetRect.inflate(hitRadius).contains(point)) {
        return false;
      }

      final topLeft = targetRect.topLeft;
      final topRight = targetRect.topRight;
      final bottomRight = targetRect.bottomRight;
      final bottomLeft = targetRect.bottomLeft;

      return _distanceToSegment(point, topLeft, topRight) <= hitRadius ||
          _distanceToSegment(point, topRight, bottomRight) <= hitRadius ||
          _distanceToSegment(point, bottomRight, bottomLeft) <= hitRadius ||
          _distanceToSegment(point, bottomLeft, topLeft) <= hitRadius;
    }

    return _distanceToSegment(point, start, end) <= hitRadius;
  }
}

class _CanvasElementRecord {
  const _CanvasElementRecord({required this.index, required this.element});

  final int index;
  final _CanvasElement element;
}

class _CanvasAction {
  const _CanvasAction({required this.type, required this.records});

  final _CanvasActionType type;
  final List<_CanvasElementRecord> records;
}

double _distanceToSegment(Offset point, Offset start, Offset end) {
  final segment = end - start;
  final lengthSquared = segment.dx * segment.dx + segment.dy * segment.dy;
  if (lengthSquared == 0) {
    return (point - start).distance;
  }

  final pointVector = point - start;
  final t =
      ((pointVector.dx * segment.dx) + (pointVector.dy * segment.dy)) /
      lengthSquared;
  final clampedT = t.clamp(0.0, 1.0);
  final projection = Offset(
    start.dx + segment.dx * clampedT,
    start.dy + segment.dy * clampedT,
  );

  return (point - projection).distance;
}

class FishboneCanvas extends StatefulWidget {
  const FishboneCanvas({
    this.height = 560,
    this.isLargePanel = false,
    this.onOpenLargePanel,
    this.onSendToChat,
    super.key,
  });

  final double height;
  final bool isLargePanel;
  final VoidCallback? onOpenLargePanel;
  final ValueChanged<CanvasWorkSnapshot>? onSendToChat;

  @override
  State<FishboneCanvas> createState() => _FishboneCanvasState();
}

class _FishboneCanvasState extends State<FishboneCanvas> {
  static const _minZoom = 0.75;
  static const _maxZoom = 3.0;
  static const _zoomStep = 0.25;
  static const _penSizes = [2.5, 4.0, 6.0];
  static const _palette = [
    WicaraColors.secondaryDeep,
    WicaraColors.primaryDeep,
    WicaraColors.accentCoral,
    WicaraColors.accentAmber,
    WicaraColors.ink,
  ];

  final List<_CanvasElement> _elements = [];
  final List<_CanvasAction> _undoStack = [];
  final List<_CanvasAction> _redoStack = [];

  _CanvasTool _selectedTool = _CanvasTool.pen;
  _CanvasShapeType _selectedShape = _CanvasShapeType.line;
  _CanvasStroke? _activeStroke;
  Offset? _shapeStart;
  Offset? _shapeEnd;
  Color _selectedColor = WicaraColors.secondaryDeep;
  double _selectedStrokeWidth = 4;
  double _zoom = 1;
  Offset _panOffset = Offset.zero;
  Size _canvasSize = Size.zero;
  bool _hasAttachment = false;
  bool _showGrid = true;
  bool _hasUnsavedChanges = false;
  int _savedVersion = 0;
  int _sentVersion = 0;
  CanvasWorkSnapshot? _savedSnapshot;

  bool get _hasCanvasContent => _elements.isNotEmpty || _hasAttachment;
  bool get _canSave => _hasCanvasContent && _hasUnsavedChanges;
  bool get _canSend =>
      _hasCanvasContent &&
      !_hasUnsavedChanges &&
      _savedSnapshot != null &&
      _sentVersion != _savedVersion;

  String get _statusText {
    if (!_hasCanvasContent) {
      return 'Draft empty';
    }
    if (_hasUnsavedChanges) {
      return _savedVersion == 0 ? 'Unsaved sketch' : 'Unsaved changes';
    }
    if (_sentVersion == _savedVersion) {
      return 'Sent to chat';
    }
    return 'Saved, ready to send';
  }

  void _setTool(_CanvasTool tool) {
    setState(() {
      _selectedTool = tool;
      _activeStroke = null;
      _shapeStart = null;
      _shapeEnd = null;
    });
  }

  void _startInteraction(DragStartDetails details) {
    final point = _toScene(details.localPosition);
    if (!_containsScenePoint(point)) {
      return;
    }

    switch (_selectedTool) {
      case _CanvasTool.hand:
        return;
      case _CanvasTool.pen:
        _beginStroke(point);
      case _CanvasTool.eraser:
        _eraseAt(point);
      case _CanvasTool.shape:
        setState(() {
          _shapeStart = point;
          _shapeEnd = point;
        });
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_selectedTool == _CanvasTool.hand) {
      setState(() {
        _panOffset = _clampPan(_panOffset + details.delta, _zoom, _canvasSize);
      });
      return;
    }

    final point = _toScene(details.localPosition);
    if (!_containsScenePoint(point)) {
      return;
    }

    switch (_selectedTool) {
      case _CanvasTool.hand:
        return;
      case _CanvasTool.pen:
        final activeStroke = _activeStroke;
        if (activeStroke == null) {
          return;
        }
        setState(() => activeStroke.points.add(point));
      case _CanvasTool.eraser:
        _eraseAt(point);
      case _CanvasTool.shape:
        if (_shapeStart == null) {
          return;
        }
        setState(() => _shapeEnd = point);
    }
  }

  void _endInteraction(DragEndDetails details) {
    if (_selectedTool == _CanvasTool.shape) {
      _commitShape();
      return;
    }

    _activeStroke = null;
  }

  void _beginStroke(Offset point) {
    final stroke = _CanvasStroke(
      points: [point],
      color: _selectedColor,
      strokeWidth: _selectedStrokeWidth,
    );

    setState(() {
      _activeStroke = stroke;
      _addElement(stroke);
    });
  }

  void _commitShape() {
    final start = _shapeStart;
    final end = _shapeEnd;
    if (start == null || end == null) {
      return;
    }

    setState(() {
      _shapeStart = null;
      _shapeEnd = null;

      if ((end - start).distance < 6) {
        return;
      }

      _addElement(
        _CanvasShape(
          type: _selectedShape,
          start: start,
          end: end,
          color: _selectedColor,
          strokeWidth: _selectedStrokeWidth,
        ),
      );
    });
  }

  void _addElement(_CanvasElement element) {
    final index = _elements.length;
    _elements.add(element);
    _undoStack.add(
      _CanvasAction(
        type: _CanvasActionType.add,
        records: [_CanvasElementRecord(index: index, element: element)],
      ),
    );
    _redoStack.clear();
    _markDirty();
  }

  void _eraseAt(Offset point) {
    final eraseRadius = math.max(12.0, _selectedStrokeWidth * 3);
    for (var index = _elements.length - 1; index >= 0; index--) {
      final element = _elements[index];
      if (!element.hitTest(point, eraseRadius)) {
        continue;
      }

      setState(() {
        final removed = _elements.removeAt(index);
        _undoStack.add(
          _CanvasAction(
            type: _CanvasActionType.erase,
            records: [_CanvasElementRecord(index: index, element: removed)],
          ),
        );
        _redoStack.clear();
        _markDirty();
      });
      return;
    }
  }

  void _undo() {
    if (_undoStack.isEmpty) {
      return;
    }

    setState(() {
      final action = _undoStack.removeLast();
      _applyInverseAction(action);
      _redoStack.add(action);
      _markDirty();
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) {
      return;
    }

    setState(() {
      final action = _redoStack.removeLast();
      _applyAction(action);
      _undoStack.add(action);
      _markDirty();
    });
  }

  void _applyAction(_CanvasAction action) {
    switch (action.type) {
      case _CanvasActionType.add:
        _insertRecords(action.records);
      case _CanvasActionType.erase:
        _removeRecords(action.records);
    }
  }

  void _applyInverseAction(_CanvasAction action) {
    switch (action.type) {
      case _CanvasActionType.add:
        _removeRecords(action.records);
      case _CanvasActionType.erase:
        _insertRecords(action.records);
    }
  }

  void _insertRecords(List<_CanvasElementRecord> records) {
    final sortedRecords = [...records]
      ..sort((a, b) => a.index.compareTo(b.index));
    for (final record in sortedRecords) {
      if (_elements.contains(record.element)) {
        continue;
      }
      _elements.insert(record.index.clamp(0, _elements.length), record.element);
    }
  }

  void _removeRecords(List<_CanvasElementRecord> records) {
    for (final record in records.reversed) {
      _elements.remove(record.element);
    }
  }

  void _attachImage() {
    setState(() {
      _hasAttachment = true;
      _markDirty();
    });
  }

  void _markDirty() {
    _hasUnsavedChanges = true;
  }

  void _saveWork() {
    if (!_hasCanvasContent) {
      return;
    }

    final nextVersion = _savedVersion + 1;
    final snapshot = _captureSnapshot(nextVersion);

    setState(() {
      _savedVersion = nextVersion;
      _savedSnapshot = snapshot;
      _hasUnsavedChanges = false;
    });
  }

  void _sendSavedWork() {
    if (!_canSend) {
      return;
    }

    final snapshot = _savedSnapshot;
    if (snapshot == null) {
      return;
    }

    setState(() => _sentVersion = _savedVersion);
    widget.onSendToChat?.call(snapshot);
  }

  CanvasWorkSnapshot _captureSnapshot(int version) {
    final size = _canvasSize == Size.zero ? const Size(360, 240) : _canvasSize;

    return CanvasWorkSnapshot._(
      version: version,
      elementCount: _elements.length,
      hasAttachment: _hasAttachment,
      showGrid: _showGrid,
      canvasSize: size,
      elements: List<_CanvasElement>.of(_elements),
    );
  }

  Future<void> _confirmClear() async {
    if (!_hasCanvasContent) {
      return;
    }

    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            'Clear canvas?',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontSize: 20, height: 1.15),
          ),
          content: Text(
            'This removes the current sketch and attached paper note.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: WicaraColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: WicaraColors.secondary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );

    if (!mounted || shouldClear != true) {
      return;
    }

    setState(() {
      _elements.clear();
      _undoStack.clear();
      _redoStack.clear();
      _activeStroke = null;
      _shapeStart = null;
      _shapeEnd = null;
      _hasAttachment = false;
      _hasUnsavedChanges = false;
      _savedVersion = 0;
      _sentVersion = 0;
      _savedSnapshot = null;
      _zoom = 1;
      _panOffset = _clampPan(Offset.zero, _zoom, _canvasSize);
    });
  }

  void _zoomBy(double delta) {
    _setZoom(_zoom + delta);
  }

  void _resetView() {
    setState(() {
      _zoom = 1;
      _panOffset = _clampPan(Offset.zero, _zoom, _canvasSize);
    });
  }

  void _setZoom(double nextZoom) {
    if (_canvasSize == Size.zero) {
      setState(() => _zoom = _clampDouble(nextZoom, _minZoom, _maxZoom));
      return;
    }

    final clampedZoom = _clampDouble(nextZoom, _minZoom, _maxZoom);
    if (clampedZoom == _zoom) {
      return;
    }

    final center = Offset(_canvasSize.width / 2, _canvasSize.height / 2);
    final sceneCenter = (center - _panOffset) / _zoom;

    setState(() {
      _zoom = clampedZoom;
      _panOffset = _clampPan(
        center - (sceneCenter * _zoom),
        _zoom,
        _canvasSize,
      );
    });
  }

  Offset _toScene(Offset localPosition) {
    return (localPosition - _panOffset) / _zoom;
  }

  bool _containsScenePoint(Offset point) {
    return point.dx >= 0 &&
        point.dy >= 0 &&
        point.dx <= _canvasSize.width &&
        point.dy <= _canvasSize.height;
  }

  Offset _clampPan(Offset offset, double zoom, Size size) {
    if (size == Size.zero) {
      return Offset.zero;
    }

    return Offset(
      _clampAxis(offset.dx, size.width, zoom),
      _clampAxis(offset.dy, size.height, zoom),
    );
  }

  double _clampAxis(double value, double extent, double zoom) {
    final scaledExtent = extent * zoom;
    if (scaledExtent <= extent) {
      return (extent - scaledExtent) / 2;
    }

    return _clampDouble(value, extent - scaledExtent, 0);
  }

  double _clampDouble(double value, double lowerBound, double upperBound) {
    if (value < lowerBound) {
      return lowerBound;
    }
    if (value > upperBound) {
      return upperBound;
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(widget.isLargePanel ? 18 : 16),
        border: Border.all(color: WicaraColors.line, width: 1.3),
        boxShadow: [
          BoxShadow(
            color: WicaraColors.shadowBlue.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              widget.isLargePanel ? 18 : 14,
              widget.isLargePanel ? 15 : 12,
              10,
              10,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isLargePanel ? 'Canvas workspace' : 'Canvas',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontSize: widget.isLargePanel ? 17 : 15,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.isLargePanel
                            ? 'Use the larger workspace for diagrams and notes.'
                            : 'Work through the reasoning before submitting.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: WicaraColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.onOpenLargePanel != null)
                  IconButton(
                    tooltip: widget.isLargePanel
                        ? 'Close panel'
                        : 'Larger panel',
                    onPressed: widget.onOpenLargePanel,
                    icon: Icon(
                      widget.isLargePanel
                          ? Icons.close_fullscreen_rounded
                          : Icons.open_in_full_rounded,
                      color: WicaraColors.secondary,
                      size: 20,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: widget.isLargePanel ? 16 : 12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CanvasToolbar(
                  selectedTool: _selectedTool,
                  zoom: _zoom,
                  showGrid: _showGrid,
                  canZoomOut: _zoom > _minZoom,
                  canZoomIn: _zoom < _maxZoom,
                  canUndo: _undoStack.isNotEmpty,
                  canRedo: _redoStack.isNotEmpty,
                  canClear: _hasCanvasContent,
                  onSelectTool: _setTool,
                  onZoomOut: () => _zoomBy(-_zoomStep),
                  onZoomIn: () => _zoomBy(_zoomStep),
                  onResetView: _resetView,
                  onToggleGrid: () => setState(() => _showGrid = !_showGrid),
                  onUndo: _undo,
                  onRedo: _redo,
                  onClear: _confirmClear,
                  onAttachImage: _attachImage,
                ),
                const SizedBox(height: 8),
                _PenOptionsBar(
                  sizes: _penSizes,
                  selectedSize: _selectedStrokeWidth,
                  selectedColor: _selectedColor,
                  palette: _palette,
                  onSizeChanged: (size) {
                    setState(() => _selectedStrokeWidth = size);
                  },
                  onColorChanged: (color) {
                    setState(() => _selectedColor = color);
                  },
                ),
                if (_selectedTool == _CanvasTool.shape) ...[
                  const SizedBox(height: 8),
                  _ShapeOptionsBar(
                    selectedShape: _selectedShape,
                    onShapeChanged: (shape) {
                      setState(() => _selectedShape = shape);
                    },
                  ),
                ],
                const SizedBox(height: 8),
                _CanvasCommitBar(
                  statusText: _statusText,
                  canSave: _canSave,
                  canSend: _canSend,
                  onSave: _saveWork,
                  onSend: _sendSavedWork,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                widget.isLargePanel ? 16 : 12,
                0,
                widget.isLargePanel ? 16 : 12,
                widget.isLargePanel ? 16 : 12,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFCFF),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: WicaraColors.secondary.withValues(alpha: 0.18),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      _canvasSize = Size(
                        constraints.maxWidth,
                        constraints.maxHeight,
                      );
                      _panOffset = _clampPan(_panOffset, _zoom, _canvasSize);

                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanStart: _startInteraction,
                        onPanUpdate: _handlePanUpdate,
                        onPanEnd: _endInteraction,
                        child: MouseRegion(
                          cursor: switch (_selectedTool) {
                            _CanvasTool.hand => SystemMouseCursors.grab,
                            _CanvasTool.eraser => SystemMouseCursors.click,
                            _CanvasTool.shape => SystemMouseCursors.precise,
                            _CanvasTool.pen => SystemMouseCursors.precise,
                          },
                          child: CustomPaint(
                            painter: _WorkCanvasPainter(
                              elements: _elements,
                              hasAttachment: _hasAttachment,
                              showGrid: _showGrid,
                              zoom: _zoom,
                              panOffset: _panOffset,
                              sceneSize: null,
                              previewShape:
                                  _shapeStart == null || _shapeEnd == null
                                  ? null
                                  : _CanvasShape(
                                      type: _selectedShape,
                                      start: _shapeStart!,
                                      end: _shapeEnd!,
                                      color: _selectedColor,
                                      strokeWidth: _selectedStrokeWidth,
                                    ),
                            ),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CanvasToolbar extends StatelessWidget {
  const _CanvasToolbar({
    required this.selectedTool,
    required this.zoom,
    required this.showGrid,
    required this.canZoomOut,
    required this.canZoomIn,
    required this.canUndo,
    required this.canRedo,
    required this.canClear,
    required this.onSelectTool,
    required this.onZoomOut,
    required this.onZoomIn,
    required this.onResetView,
    required this.onToggleGrid,
    required this.onUndo,
    required this.onRedo,
    required this.onClear,
    required this.onAttachImage,
  });

  final _CanvasTool selectedTool;
  final double zoom;
  final bool showGrid;
  final bool canZoomOut;
  final bool canZoomIn;
  final bool canUndo;
  final bool canRedo;
  final bool canClear;
  final ValueChanged<_CanvasTool> onSelectTool;
  final VoidCallback onZoomOut;
  final VoidCallback onZoomIn;
  final VoidCallback onResetView;
  final VoidCallback onToggleGrid;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onClear;
  final VoidCallback onAttachImage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ModeControlGroup(
          selectedTool: selectedTool,
          onSelectTool: onSelectTool,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.start,
          children: [
            _ControlGroup(
              title: 'View',
              children: [
                _CanvasIconButton(
                  icon: Icons.zoom_out_rounded,
                  tooltip: 'Zoom out',
                  onPressed: canZoomOut ? onZoomOut : null,
                ),
                _ZoomBadge(zoom: zoom),
                _CanvasIconButton(
                  icon: Icons.zoom_in_rounded,
                  tooltip: 'Zoom in',
                  onPressed: canZoomIn ? onZoomIn : null,
                ),
                _CanvasIconButton(
                  icon: Icons.center_focus_strong_outlined,
                  tooltip: 'Reset view',
                  onPressed: onResetView,
                ),
                _CanvasIconButton(
                  icon: showGrid
                      ? Icons.grid_on_rounded
                      : Icons.grid_off_rounded,
                  tooltip: showGrid ? 'Hide grid' : 'Show grid',
                  isActive: showGrid,
                  onPressed: onToggleGrid,
                ),
              ],
            ),
            _ControlGroup(
              title: 'Edit',
              children: [
                _CanvasIconButton(
                  icon: Icons.undo_rounded,
                  tooltip: 'Undo',
                  onPressed: canUndo ? onUndo : null,
                ),
                _CanvasIconButton(
                  icon: Icons.redo_rounded,
                  tooltip: 'Redo',
                  onPressed: canRedo ? onRedo : null,
                ),
                _CanvasIconButton(
                  icon: Icons.delete_outline_rounded,
                  tooltip: 'Clear canvas',
                  onPressed: canClear ? onClear : null,
                  activeColor: WicaraColors.accentCoral,
                ),
                _CanvasIconButton(
                  icon: Icons.upload_file_rounded,
                  tooltip: 'Upload image',
                  onPressed: onAttachImage,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _ModeControlGroup extends StatelessWidget {
  const _ModeControlGroup({
    required this.selectedTool,
    required this.onSelectTool,
  });

  final _CanvasTool selectedTool;
  final ValueChanged<_CanvasTool> onSelectTool;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 7, 9, 9),
      decoration: BoxDecoration(
        color: WicaraColors.fieldFill,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: WicaraColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 6),
            child: Text(
              'Mode',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: WicaraColors.muted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _ModeButton(
                  icon: Icons.edit_rounded,
                  label: 'Pen',
                  tooltip: 'Pen mode',
                  isActive: selectedTool == _CanvasTool.pen,
                  onPressed: () => onSelectTool(_CanvasTool.pen),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _ModeButton(
                  icon: Icons.open_with_rounded,
                  label: 'Hand',
                  tooltip: 'Hand mode',
                  isActive: selectedTool == _CanvasTool.hand,
                  onPressed: () => onSelectTool(_CanvasTool.hand),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _ModeButton(
                  icon: Icons.auto_fix_high_rounded,
                  label: 'Erase',
                  tooltip: 'Eraser mode',
                  isActive: selectedTool == _CanvasTool.eraser,
                  onPressed: () => onSelectTool(_CanvasTool.eraser),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _ModeButton(
                  icon: Icons.category_outlined,
                  label: 'Shape',
                  tooltip: 'Shape helper',
                  isActive: selectedTool == _CanvasTool.shape,
                  onPressed: () => onSelectTool(_CanvasTool.shape),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.isActive,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final bool isActive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final foreground = isActive ? Colors.white : WicaraColors.secondary;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(11),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: isActive ? WicaraColors.secondary : Colors.white,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: isActive ? WicaraColors.secondary : WicaraColors.line,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: foreground, size: 18),
                const SizedBox(height: 1),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: foreground,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ControlGroup extends StatelessWidget {
  const _ControlGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 7, 9, 9),
      decoration: BoxDecoration(
        color: WicaraColors.fieldFill,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: WicaraColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 6),
            child: Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: WicaraColors.muted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Row(mainAxisSize: MainAxisSize.min, children: children),
        ],
      ),
    );
  }
}

class _CanvasIconButton extends StatelessWidget {
  const _CanvasIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isActive = false,
    this.activeColor,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool isActive;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;
    final color = activeColor ?? WicaraColors.secondary;
    final foreground = isActive
        ? Colors.white
        : isEnabled
        ? color
        : WicaraColors.softMuted;
    final background = isActive
        ? color
        : isEnabled
        ? WicaraColors.speechBlue
        : WicaraColors.fieldFill;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 42,
            height: 42,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isEnabled
                    ? color.withValues(alpha: isActive ? 0.72 : 0.24)
                    : WicaraColors.line,
                width: 1.1,
              ),
            ),
            child: Icon(icon, color: foreground, size: 20),
          ),
        ),
      ),
    );
  }
}

class _ZoomBadge extends StatelessWidget {
  const _ZoomBadge({required this.zoom});

  final double zoom;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 42,
      margin: const EdgeInsets.only(right: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: WicaraColors.line, width: 1.1),
      ),
      child: Text(
        '${(zoom * 100).round()}%',
        maxLines: 1,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: WicaraColors.text,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PenOptionsBar extends StatelessWidget {
  const _PenOptionsBar({
    required this.sizes,
    required this.selectedSize,
    required this.selectedColor,
    required this.palette,
    required this.onSizeChanged,
    required this.onColorChanged,
  });

  final List<double> sizes;
  final double selectedSize;
  final Color selectedColor;
  final List<Color> palette;
  final ValueChanged<double> onSizeChanged;
  final ValueChanged<Color> onColorChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: WicaraColors.fieldFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WicaraColors.line),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Text(
              'Style',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: WicaraColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 9),
            for (final size in sizes) ...[
              _PenSizeButton(
                size: size,
                isSelected: size == selectedSize,
                onPressed: () => onSizeChanged(size),
              ),
              if (size != sizes.last) const SizedBox(width: 5),
            ],
            const SizedBox(width: 14),
            for (final color in palette) ...[
              _ColorSwatchButton(
                color: color,
                isSelected: color == selectedColor,
                onPressed: () => onColorChanged(color),
              ),
              if (color != palette.last) const SizedBox(width: 6),
            ],
          ],
        ),
      ),
    );
  }
}

class _PenSizeButton extends StatelessWidget {
  const _PenSizeButton({
    required this.size,
    required this.isSelected,
    required this.onPressed,
  });

  final double size;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Pen size ${size.toStringAsFixed(1)}',
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(9),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? WicaraColors.secondarySoft : Colors.white,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: isSelected ? WicaraColors.secondary : WicaraColors.line,
              width: isSelected ? 1.4 : 1,
            ),
          ),
          child: Container(
            width: size + 7,
            height: size + 7,
            decoration: BoxDecoration(
              color: isSelected ? WicaraColors.secondary : WicaraColors.muted,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorSwatchButton extends StatelessWidget {
  const _ColorSwatchButton({
    required this.color,
    required this.isSelected,
    required this.onPressed,
  });

  final Color color;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Pen color',
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(13),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 31,
          height: 31,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? WicaraColors.secondary : WicaraColors.line,
              width: isSelected ? 1.7 : 1,
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}

class _ShapeOptionsBar extends StatelessWidget {
  const _ShapeOptionsBar({
    required this.selectedShape,
    required this.onShapeChanged,
  });

  final _CanvasShapeType selectedShape;
  final ValueChanged<_CanvasShapeType> onShapeChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: WicaraColors.secondarySoft.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WicaraColors.secondaryLight),
      ),
      child: Row(
        children: [
          Text(
            'Shape',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: WicaraColors.secondaryDeep,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 9),
          _ShapeButton(
            icon: Icons.horizontal_rule_rounded,
            tooltip: 'Line shape',
            isSelected: selectedShape == _CanvasShapeType.line,
            onPressed: () => onShapeChanged(_CanvasShapeType.line),
          ),
          const SizedBox(width: 7),
          _ShapeButton(
            icon: Icons.arrow_forward_rounded,
            tooltip: 'Arrow shape',
            isSelected: selectedShape == _CanvasShapeType.arrow,
            onPressed: () => onShapeChanged(_CanvasShapeType.arrow),
          ),
          const SizedBox(width: 7),
          _ShapeButton(
            icon: Icons.crop_square_rounded,
            tooltip: 'Rectangle shape',
            isSelected: selectedShape == _CanvasShapeType.rectangle,
            onPressed: () => onShapeChanged(_CanvasShapeType.rectangle),
          ),
        ],
      ),
    );
  }
}

class _ShapeButton extends StatelessWidget {
  const _ShapeButton({
    required this.icon,
    required this.tooltip,
    required this.isSelected,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(9),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 31,
          height: 27,
          decoration: BoxDecoration(
            color: isSelected ? WicaraColors.secondary : Colors.white,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: isSelected ? WicaraColors.secondary : WicaraColors.line,
            ),
          ),
          child: Icon(
            icon,
            color: isSelected ? Colors.white : WicaraColors.secondary,
            size: 17,
          ),
        ),
      ),
    );
  }
}

class _CanvasCommitBar extends StatelessWidget {
  const _CanvasCommitBar({
    required this.statusText,
    required this.canSave,
    required this.canSend,
    required this.onSave,
    required this.onSend,
  });

  final String statusText;
  final bool canSave;
  final bool canSend;
  final VoidCallback onSave;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
      decoration: BoxDecoration(
        color: WicaraColors.speechBlue,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: WicaraColors.primaryLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                color: _statusColor,
                size: 17,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  statusText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: WicaraColors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: _CanvasActionButton(
                  icon: Icons.save_outlined,
                  label: 'Save work',
                  onPressed: canSave ? onSave : null,
                  isPrimary: true,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _CanvasActionButton(
                  icon: Icons.forum_outlined,
                  label: 'Send to chat',
                  onPressed: canSend ? onSend : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color get _statusColor {
    if (statusText == 'Sent to chat') {
      return WicaraColors.accentMint;
    }
    if (statusText == 'Saved, ready to send') {
      return WicaraColors.secondary;
    }
    return WicaraColors.accentAmber;
  }
}

class _CanvasActionButton extends StatelessWidget {
  const _CanvasActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;
    final foreground = isPrimary && isEnabled
        ? Colors.white
        : isEnabled
        ? WicaraColors.secondary
        : WicaraColors.softMuted;
    final background = isPrimary && isEnabled
        ? WicaraColors.secondary
        : Colors.white;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: isEnabled
                  ? WicaraColors.secondary.withValues(alpha: 0.34)
                  : WicaraColors.line,
            ),
            boxShadow: [
              if (isPrimary && isEnabled)
                BoxShadow(
                  color: WicaraColors.secondary.withValues(alpha: 0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: foreground, size: 18),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkCanvasPainter extends CustomPainter {
  const _WorkCanvasPainter({
    required this.elements,
    required this.hasAttachment,
    required this.showGrid,
    required this.zoom,
    required this.panOffset,
    required this.sceneSize,
    required this.previewShape,
  });

  final List<_CanvasElement> elements;
  final bool hasAttachment;
  final bool showGrid;
  final double zoom;
  final Offset panOffset;
  final Size? sceneSize;
  final _CanvasShape? previewShape;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(panOffset.dx, panOffset.dy);
    canvas.scale(zoom);
    final sceneSize = this.sceneSize ?? size;

    if (showGrid) {
      final gridPaint = Paint()
        ..color = WicaraColors.primary.withValues(alpha: 0.08)
        ..strokeWidth = 1 / zoom;
      for (var x = 24.0; x < sceneSize.width; x += 24) {
        canvas.drawLine(Offset(x, 0), Offset(x, sceneSize.height), gridPaint);
      }
      for (var y = 24.0; y < sceneSize.height; y += 24) {
        canvas.drawLine(Offset(0, y), Offset(sceneSize.width, y), gridPaint);
      }
    }

    if (hasAttachment) {
      final paperRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(sceneSize.width * 0.08, sceneSize.height * 0.12, 132, 88),
        const Radius.circular(12),
      );
      final paperPaint = Paint()
        ..color = WicaraColors.secondarySoft.withValues(alpha: 0.68);
      canvas.drawRRect(paperRect, paperPaint);
      _drawText(
        canvas,
        'Paper work\nattached',
        Offset(sceneSize.width * 0.08 + 18, sceneSize.height * 0.12 + 24),
        WicaraColors.secondaryDeep,
      );
    }

    if (elements.isEmpty && !hasAttachment && previewShape == null) {
      _drawText(
        canvas,
        'Sketch formulas, diagrams, or working steps here.',
        Offset(sceneSize.width * 0.10, sceneSize.height * 0.46),
        WicaraColors.softMuted,
        maxWidth: sceneSize.width * 0.80,
      );
    }

    for (final element in elements) {
      switch (element) {
        case _CanvasStroke():
          _paintStroke(canvas, element);
        case _CanvasShape():
          _paintShape(canvas, element);
      }
    }

    final currentPreview = previewShape;
    if (currentPreview != null) {
      _paintShape(canvas, currentPreview, isPreview: true);
    }

    canvas.restore();
  }

  void _paintStroke(Canvas canvas, _CanvasStroke stroke) {
    final ink = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (stroke.points.length < 2) {
      canvas.drawCircle(stroke.points.first, stroke.strokeWidth / 2, ink);
      return;
    }

    final path = Path()..moveTo(stroke.points.first.dx, stroke.points.first.dy);
    for (final point in stroke.points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, ink);
  }

  void _paintShape(
    Canvas canvas,
    _CanvasShape shape, {
    bool isPreview = false,
  }) {
    final shapePaint = Paint()
      ..color = isPreview ? shape.color.withValues(alpha: 0.54) : shape.color
      ..strokeWidth = shape.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (isPreview) {
      shapePaint.strokeWidth = math.max(1.6, shape.strokeWidth - 0.6);
    }

    switch (shape.type) {
      case _CanvasShapeType.line:
        canvas.drawLine(shape.start, shape.end, shapePaint);
      case _CanvasShapeType.arrow:
        canvas.drawLine(shape.start, shape.end, shapePaint);
        _paintArrowHead(canvas, shape, shapePaint);
      case _CanvasShapeType.rectangle:
        canvas.drawRRect(
          RRect.fromRectAndRadius(shape.rect, const Radius.circular(8)),
          shapePaint,
        );
    }
  }

  void _paintArrowHead(Canvas canvas, _CanvasShape shape, Paint paint) {
    final direction = shape.end - shape.start;
    if (direction.distance < 8) {
      return;
    }

    final angle = math.atan2(direction.dy, direction.dx);
    final headLength = math.max(11.0, shape.strokeWidth * 3.2);
    final left = Offset(
      shape.end.dx - headLength * math.cos(angle - math.pi / 6),
      shape.end.dy - headLength * math.sin(angle - math.pi / 6),
    );
    final right = Offset(
      shape.end.dx - headLength * math.cos(angle + math.pi / 6),
      shape.end.dy - headLength * math.sin(angle + math.pi / 6),
    );

    canvas.drawLine(shape.end, left, paint);
    canvas.drawLine(shape.end, right, paint);
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    Color color, {
    double maxWidth = 140,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          height: 1.25,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _WorkCanvasPainter oldDelegate) {
    return oldDelegate.elements != elements ||
        oldDelegate.hasAttachment != hasAttachment ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.zoom != zoom ||
        oldDelegate.panOffset != panOffset ||
        oldDelegate.sceneSize != sceneSize ||
        oldDelegate.previewShape != previewShape;
  }
}
