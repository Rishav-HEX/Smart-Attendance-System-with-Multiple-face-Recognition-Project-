import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

import '../services/api_service.dart';

class AttendanceCameraScreen extends StatefulWidget {
  const AttendanceCameraScreen({super.key});

  @override
  State<AttendanceCameraScreen> createState() =>
      _AttendanceCameraScreenState();
}

class _AttendanceCameraScreenState extends State<AttendanceCameraScreen> {
  CameraController? _cameraController;

  CameraLensDirection _currentLensDirection = CameraLensDirection.front;

  final api = ApiService();

  bool isCameraInitialized = false;
  bool isRecognizing = false;

  Timer? recognitionTimer;

  List<dynamic> recognizedFaces = [];
  String recognitionStatus = "Scanning...";

  // Dimensions of the actual JPEG that was just analyzed by the backend.
  // Measured directly from the captured file every cycle — never hardcoded.
  double _capturedImageWidth = 480;
  double _capturedImageHeight = 640;

  // Debounce counter so a single missed detection frame doesn't wipe
  // all boxes and cause visible flicker.
  int _missCount = 0;
  static const int _missThreshold = 2;

  // Zoom state. minZoom/maxZoom come from the controller and differ by
  // device and by lens (front cameras often only support 1x), so they
  // are read fresh every time the camera initializes rather than assumed.
  double _currentZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 1.0;

  // The chip levels offered in the UI. Any level above _maxZoom is
  // simply clamped to _maxZoom when tapped, so this list can stay
  // static even though actual hardware support varies.
  static const List<double> _zoomLevels = [1.0, 2.0, 3.0];

  @override
  void initState() {
    super.initState();
    initializeCamera();
  }

  Future<void> initializeCamera() async {
    final cameras = await availableCameras();

    final selectedCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == _currentLensDirection,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      selectedCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _cameraController!.initialize();

    if (!mounted) return;

    // Read the real zoom range for this lens. Front cameras frequently
    // report minZoom == maxZoom == 1.0 (no optical/digital zoom support),
    // so the UI below disables zoom chips gracefully in that case instead
    // of pretending zoom is available.
    final minZoom = await _cameraController!.getMinZoomLevel();
    final maxZoom = await _cameraController!.getMaxZoomLevel();

    setState(() {
      isCameraInitialized = true;
      _currentLensDirection = selectedCamera.lensDirection;
      _minZoom = minZoom;
      _maxZoom = maxZoom;
      _currentZoom = minZoom; // always start at the lowest (1x) level
    });

    debugPrint(
      "Camera: ${selectedCamera.lensDirection}, "
      "sensorOrientation: ${selectedCamera.sensorOrientation}, "
      "previewSize: ${_cameraController!.value.previewSize}, "
      "previewAspectRatio: ${_cameraController!.value.aspectRatio}",
    );

    startAutoRecognition();
  }

  Future<void> toggleCamera() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    recognitionTimer?.cancel();

    await _cameraController!.dispose();
    _cameraController = null;

    setState(() {
      isCameraInitialized = false;
      recognizedFaces = [];
      _missCount = 0;
      _currentZoom = 1.0;
      _minZoom = 1.0;
      _maxZoom = 1.0;
      _currentLensDirection = _currentLensDirection == CameraLensDirection.front
          ? CameraLensDirection.back
          : CameraLensDirection.front;
    });

    await initializeCamera();
  }

  Future<void> _setZoom(double level) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    // Clamp to what this lens actually supports. Tapping "3x" on a lens
    // that maxes out at 2x will just settle at 2x instead of throwing.
    final clamped = level.clamp(_minZoom, _maxZoom);

    try {
      await _cameraController!.setZoomLevel(clamped);
      if (!mounted) return;
      setState(() {
        _currentZoom = clamped;
      });
    } catch (e) {
      debugPrint("ZOOM ERROR => $e");
    }
  }

  void startAutoRecognition() {
    recognitionTimer = Timer.periodic(
      const Duration(milliseconds: 700),
      (timer) {
        recognizeFace();
      },
    );
  }

  Future<void> recognizeFace() async {
    if (isRecognizing) return;
    if (_cameraController == null) return;
    if (!_cameraController!.value.isInitialized) return;

    isRecognizing = true;

    try {
      final image = await _cameraController!.takePicture();
      final file = File(image.path);

      // PERFORMANCE FIX: measuring image dimensions and uploading to the
      // backend are independent operations on the same file — they don't
      // need to happen one after another. Running them concurrently with
      // Future.wait shaves off whichever one is faster (usually the
      // measurement) instead of paying for both in sequence.
      final results = await Future.wait([
        _measureCapturedImage(file),
        api.recognizeFace(file),
      ]);

      final result = results[1] as Map<String, dynamic>;

      if (!mounted) return;

      if (result["success"] == true &&
          result["recognized"] != null &&
          result["recognized"].length > 0) {
        setState(() {
          recognizedFaces = result["recognized"];
          recognitionStatus = "${recognizedFaces.length} Face(s) Detected";
          _missCount = 0;
        });
      } else {
        _missCount++;
        if (_missCount >= _missThreshold) {
          setState(() {
            recognizedFaces = [];
            recognitionStatus = "No Face Detected";
          });
        }
      }
    } catch (e) {
      debugPrint("RECOGNITION ERROR => $e");

      if (!mounted) return;

      setState(() {
        recognitionStatus = "Recognition Error";
      });
    } finally {
      isRecognizing = false;
    }
  }

  Future<void> _measureCapturedImage(File file) async {
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    _capturedImageWidth = frame.image.width.toDouble();
    _capturedImageHeight = frame.image.height.toDouble();
    frame.image.dispose();
  }

  // ---------------------------------------------------------------------
  // COORDINATE TRANSFORM PIPELINE
  // ---------------------------------------------------------------------
  //
  // KEY FIX vs the previous version:
  // Instead of assuming the captured image is always portrait and always
  // needs a 90 degree rotation before scaling, we now COMPARE the captured
  // image's aspect ratio against the preview's aspect ratio at runtime.
  //
  // - If they're already a close match (within tolerance) -> NO rotation
  //   needed. This is the case if your backend decodes the JPEG without
  //   respecting EXIF orientation (e.g. cv2.imread in OpenCV), because then
  //   the raw pixel array InsightFace ran on is in the SAME orientation as
  //   previewSize reports.
  // - If the aspect ratio is inverted (w/h flipped) -> rotate 90 degrees
  //   before scaling, because the captured/decoded image is rotated 90
  //   degrees relative to the preview.
  //
  // This removes the guesswork of hardcoding a rotation direction from
  // sensorOrientation, which was the source of the residual offset you saw.

  _PreviewRect _computePreviewRect(Size stackSize, double previewAspectRatio) {
    final stackAspectRatio = stackSize.width / stackSize.height;

    double width, height;
    if (previewAspectRatio > stackAspectRatio) {
      width = stackSize.width;
      height = width / previewAspectRatio;
    } else {
      height = stackSize.height;
      width = height * previewAspectRatio;
    }

    final left = (stackSize.width - width) / 2;
    final top = (stackSize.height - height) / 2;

    return _PreviewRect(left, top, width, height);
  }

  /// Decides whether the captured image needs a 90-degree rotation to
  /// match the preview's orientation, by comparing aspect ratios directly
  /// instead of assuming based on sensorOrientation.
  bool _needsRotation(double imgW, double imgH, double previewAspectRatio) {
    final imgAspectRatio = imgW / imgH;

    // previewAspectRatio is typically > 1 (landscape-style, e.g. 720/480 = 1.5)
    // If imgAspectRatio is also > 1, image and preview already share
    // orientation -> no rotation needed.
    // If imgAspectRatio is < 1 (portrait, e.g. 480/640 = 0.75), it's rotated
    // relative to the preview -> rotation needed.
    final imgIsLandscapeLike = imgAspectRatio >= 1.0;
    final previewIsLandscapeLike = previewAspectRatio >= 1.0;

    return imgIsLandscapeLike != previewIsLandscapeLike;
  }

  Rect _rotateBoxClockwise(Rect box, double imgW, double imgH) {
    final newX1 = imgH - box.bottom;
    final newX2 = imgH - box.top;
    final newY1 = box.left;
    final newY2 = box.right;
    return Rect.fromLTRB(newX1, newY1, newX2, newY2);
  }

  Rect _scaleToPreviewRect(
    Rect box,
    double sourceW,
    double sourceH,
    _PreviewRect previewRect,
  ) {
    final scaleX = previewRect.width / sourceW;
    final scaleY = previewRect.height / sourceH;

    return Rect.fromLTRB(
      previewRect.left + box.left * scaleX,
      previewRect.top + box.top * scaleY,
      previewRect.left + box.right * scaleX,
      previewRect.top + box.bottom * scaleY,
    );
  }

  /// Mirrors a box horizontally within the preview rect's own bounds.
  /// Only applied for front camera, only after scaling.
  Rect _applyMirrorIfFront(Rect box, _PreviewRect previewRect, bool isFront) {
    if (!isFront) return box;

    final relLeft = box.left - previewRect.left;
    final relRight = box.right - previewRect.left;

    final mirroredLeft = previewRect.left + (previewRect.width - relRight);
    final mirroredRight = previewRect.left + (previewRect.width - relLeft);

    return Rect.fromLTRB(mirroredLeft, box.top, mirroredRight, box.bottom);
  }

  Rect _transformFaceBox(
    Map<String, dynamic> face,
    _PreviewRect previewRect,
    double previewAspectRatio,
    bool isFront,
  ) {
    final x1 = (face["x1"] as num).toDouble();
    final y1 = (face["y1"] as num).toDouble();
    final x2 = (face["x2"] as num).toDouble();
    final y2 = (face["y2"] as num).toDouble();

    var box = Rect.fromLTRB(x1, y1, x2, y2);
    double sourceW = _capturedImageWidth;
    double sourceH = _capturedImageHeight;

    if (_needsRotation(_capturedImageWidth, _capturedImageHeight, previewAspectRatio)) {
      box = _rotateBoxClockwise(box, _capturedImageWidth, _capturedImageHeight);
      // After rotation, width/height swap.
      sourceW = _capturedImageHeight;
      sourceH = _capturedImageWidth;
    }

    var screenBox = _scaleToPreviewRect(box, sourceW, sourceH, previewRect);
    screenBox = _applyMirrorIfFront(screenBox, previewRect, isFront);

    return screenBox;
  }

  @override
  void dispose() {
    recognitionTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.35),
        elevation: 0,
        title: const Text(
          "Live Attendance",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: toggleCamera,
            icon: const Icon(Icons.flip_camera_ios_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: !isCameraInitialized
          ? const Center(
              child: CircularProgressIndicator(color: Colors.greenAccent),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final stackSize = Size(constraints.maxWidth, constraints.maxHeight);
                final previewAspectRatio = _cameraController!.value.aspectRatio;
                final previewRect = _computePreviewRect(stackSize, previewAspectRatio);
                final isFront = _currentLensDirection == CameraLensDirection.front;

                return Stack(
                  children: [
                    Positioned.fill(child: CameraPreview(_cameraController!)),

                    ...recognizedFaces.map<Widget>((face) {
                      final screenBox = _transformFaceBox(
                        face,
                        previewRect,
                        previewAspectRatio,
                        isFront,
                      );

                      final name = (face["name"] ?? "Unknown").toString();
                      final score = face["score"] is num
                          ? (face["score"] as num).toDouble()
                          : null;

                      final faceKey = ValueKey(
                        "${name}_${face["x1"]}_${face["y1"]}",
                      );

                      return _FaceBox(
                        key: faceKey,
                        rect: screenBox,
                        name: name,
                        score: score,
                      );
                    }),

                    // Top status pill
                    Positioned(
                      top: 100,
                      left: 16,
                      right: 16,
                      child: _StatusPill(
                        faceCount: recognizedFaces.length,
                        status: recognitionStatus,
                      ),
                    ),

                    // Zoom level chips — only shown when this lens
                    // actually supports more than 1x, so front cameras
                    // that report minZoom==maxZoom don't show a dead control.
                    if (_maxZoom > _minZoom)
                      Positioned(
                        bottom: 92,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: _ZoomSelector(
                            levels: _zoomLevels,
                            currentZoom: _currentZoom,
                            maxZoom: _maxZoom,
                            onSelected: _setZoom,
                          ),
                        ),
                      ),

                    // Bottom hint bar
                    Positioned(
                      bottom: 28,
                      left: 24,
                      right: 24,
                      child: _BottomHint(isScanning: recognizedFaces.isNotEmpty),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _PreviewRect {
  final double left, top, width, height;
  _PreviewRect(this.left, this.top, this.width, this.height);
}

// ---------------------------------------------------------------------
// UI WIDGETS
// ---------------------------------------------------------------------

class _FaceBox extends StatelessWidget {
  final Rect rect;
  final String name;
  final double? score;

  const _FaceBox({
    super.key,
    required this.rect,
    required this.name,
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    final isKnown = name.toLowerCase() != "unknown";
    final accentColor = isKnown ? const Color(0xFF34D399) : const Color(0xFFF59E0B);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Corner-bracket style box (camera-app look) instead of a full
          // rectangle border.
          CustomPaint(
            size: Size(rect.width, rect.height),
            painter: _CornerBracketPainter(color: accentColor),
          ),

          // Label, anchored just above the box.
          Positioned(
            left: 0,
            top: -34,
            child: Container(
              constraints: BoxConstraints(maxWidth: rect.width + 60),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isKnown ? Icons.check_circle : Icons.help_outline,
                    size: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (score != null) ...[
                    const SizedBox(width: 5),
                    Text(
                      "${(score! * 100).toStringAsFixed(0)}%",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontWeight: FontWeight.w500,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Draws four L-shaped corner brackets instead of a full rectangle,
/// matching the look of modern camera-app face tracking UIs.
class _CornerBracketPainter extends CustomPainter {
  final Color color;
  _CornerBracketPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final double cornerLen = (size.shortestSide * 0.22).clamp(14.0, 28.0);
    final double r = 10;

    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(0, cornerLen)
        ..lineTo(0, r)
        ..quadraticBezierTo(0, 0, r, 0)
        ..lineTo(cornerLen, 0),
      paint,
    );

    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - cornerLen, 0)
        ..lineTo(size.width - r, 0)
        ..quadraticBezierTo(size.width, 0, size.width, r)
        ..lineTo(size.width, cornerLen),
      paint,
    );

    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height - cornerLen)
        ..lineTo(0, size.height - r)
        ..quadraticBezierTo(0, size.height, r, size.height)
        ..lineTo(cornerLen, size.height),
      paint,
    );

    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(size.width, size.height - cornerLen)
        ..lineTo(size.width, size.height - r)
        ..quadraticBezierTo(size.width, size.height, size.width - r, size.height)
        ..lineTo(size.width - cornerLen, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CornerBracketPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _StatusPill extends StatelessWidget {
  final int faceCount;
  final String status;

  const _StatusPill({required this.faceCount, required this.status});

  @override
  Widget build(BuildContext context) {
    final hasFaces = faceCount > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: (hasFaces ? const Color(0xFF34D399) : Colors.white)
                  .withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Text(
              "$faceCount",
              style: TextStyle(
                color: hasFaces ? const Color(0xFF34D399) : Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  faceCount == 1 ? "1 Face Detected" : "$faceCount Faces Detected",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  status,
                  style: TextStyle(
                    color: hasFaces ? const Color(0xFF34D399) : Colors.white60,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: hasFaces ? const Color(0xFF34D399) : Colors.white24,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomHint extends StatelessWidget {
  final bool isScanning;

  const _BottomHint({required this.isScanning});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: isScanning ? const Color(0xFF34D399) : Colors.white54,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            "Auto Recognition Running",
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoomSelector extends StatelessWidget {
  final List<double> levels;
  final double currentZoom;
  final double maxZoom;
  final ValueChanged<double> onSelected;

  const _ZoomSelector({
    required this.levels,
    required this.currentZoom,
    required this.maxZoom,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: levels.map((level) {
          // A chip is only meaningfully selectable if the lens supports
          // at least that level; otherwise tapping it just clamps to max,
          // so we still show it but visually de-emphasized.
          final isSupported = level <= maxZoom;
          final isActive = (currentZoom - level).abs() < 0.05 ||
              (level == levels.last && currentZoom >= maxZoom - 0.05 && currentZoom > levels[levels.length - 2]);

          return GestureDetector(
            onTap: () => onSelected(level),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF34D399)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                "${level.toStringAsFixed(0)}x",
                style: TextStyle(
                  color: isActive
                      ? Colors.black
                      : (isSupported ? Colors.white : Colors.white38),
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}