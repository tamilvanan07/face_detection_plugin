import 'package:flutter/material.dart';
import 'package:face_detection_plugin/face_detection_plugin.dart';

import '../db/objectbox_store.dart';
import '../widgets/camera_permission_gate.dart';
import 'register_details_screen.dart';

/// Maximum number of angle captures per person.
const _kMaxCaptures = 5;

class RegisterCameraScreen extends StatefulWidget {
  const RegisterCameraScreen({super.key, required this.store});

  final ObjectBoxVectorStore store;

  @override
  State<RegisterCameraScreen> createState() => _RegisterCameraScreenState();
}

class _RegisterCameraScreenState extends State<RegisterCameraScreen> {
  final _facePlugin = FaceDetectionPlugin();

  bool _faceDetected = false;
  bool _isCapturing = false;

  /// The latest embedding from the live camera frame.
  List<double>? _latestEmbedding;

  /// All captured embeddings so far (one per angle shot).
  final List<List<double>> _capturedEmbeddings = [];

  // ── Angle labels shown as hints ──────────────────────────────────────────
  static const _angleHints = [
    'Look straight at the camera',
    'Turn slightly to the left',
    'Turn slightly to the right',
    'Tilt your head up a little',
    'Tilt your head down a little',
  ];

  String get _currentHint =>
      _angleHints[_capturedEmbeddings.length.clamp(0, _angleHints.length - 1)];

  bool get _canProceed => _capturedEmbeddings.isNotEmpty;
  bool get _isComplete => _capturedEmbeddings.length >= _kMaxCaptures;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  @override
  void dispose() {
    _facePlugin.removeNativeCallbackListener();
    super.dispose();
  }

  void _startListening() {
    _facePlugin.listenToNativeCallbacks(
      onFrameData: (frameData) {
        if (!mounted) return;
        final raw = frameData['embedding'];
        if (raw is List && raw.isNotEmpty) {
          _latestEmbedding = raw.map((e) => (e as num).toDouble()).toList();
          if (!_faceDetected) setState(() => _faceDetected = true);
        } else {
          _latestEmbedding = null;
          if (_faceDetected) setState(() => _faceDetected = false);
        }
      },
      onEmbeddingExtracted: (embedding, _) {
        if (!mounted) return;
        _latestEmbedding = embedding;
        if (!_faceDetected) setState(() => _faceDetected = true);
      },
    );
  }

  // ── Capture one angle ────────────────────────────────────────────────────

  Future<void> _captureAngle() async {
    if (_isCapturing || _isComplete) return;
    if (_latestEmbedding == null || _latestEmbedding!.isEmpty) {
      _showSnack('No face detected — look into the camera and try again.');
      return;
    }

    setState(() => _isCapturing = true);
    final captured = List<double>.from(_latestEmbedding!);

    // Brief visual pause so the shutter flash feels intentional.
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    setState(() {
      _capturedEmbeddings.add(captured);
      _isCapturing = false;
    });
  }

  // ── Remove last capture (retake) ─────────────────────────────────────────

  void _retakeLast() {
    if (_capturedEmbeddings.isEmpty) return;
    setState(() => _capturedEmbeddings.removeLast());
  }

  // ── Proceed to details form ──────────────────────────────────────────────

  Future<void> _proceed() async {
    if (!_canProceed) return;

    final embeddings = List<List<double>>.from(_capturedEmbeddings);
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RegisterDetailsScreen(
          embeddings: embeddings,
          store: widget.store,
        ),
      ),
    );

    if (!mounted) return;
    if (saved == true) Navigator.pop(context, true);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return CameraPermissionGate(
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Register Face',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ── Live camera ──────────────────────────────────────────────
            const FaceCameraView(),

            // ── Top: angle hint + progress dots ──────────────────────────
            Positioned(
              top: MediaQuery.of(context).padding.top + kToolbarHeight + 12,
              left: 16,
              right: 16,
              child: Column(
                children: [
                  // Progress dots
                  _AngleDots(
                    total: _kMaxCaptures,
                    filled: _capturedEmbeddings.length,
                    color: primary,
                  ),
                  const SizedBox(height: 10),
                  // Status pill
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _isCapturing
                        ? _Pill(
                            key: const ValueKey('capturing'),
                            icon: Icons.hourglass_top_rounded,
                            label: 'Saving angle…',
                            color: Colors.amberAccent,
                          )
                        : _isComplete
                        ? _Pill(
                            key: const ValueKey('complete'),
                            icon: Icons.check_circle_rounded,
                            label: 'All angles captured — tap Next',
                            color: Colors.greenAccent,
                          )
                        : _faceDetected
                        ? _Pill(
                            key: ValueKey(
                                'detected-${_capturedEmbeddings.length}'),
                            icon: Icons.face_retouching_natural,
                            label: _currentHint,
                            color: Colors.greenAccent,
                          )
                        : _Pill(
                            key: const ValueKey('waiting'),
                            icon: Icons.face_outlined,
                            label: 'Look into the camera',
                            color: Colors.white54,
                          ),
                  ),
                ],
              ),
            ),

            // ── Bottom: shutter + retake + next ─────────────────────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Counter label
                      Text(
                        _isComplete
                            ? 'All $_kMaxCaptures angles captured'
                            : '${_capturedEmbeddings.length} / $_kMaxCaptures angles captured',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Shutter + retake row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Retake button (only shown when at least 1 captured)
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: _capturedEmbeddings.isEmpty ? 0.0 : 1.0,
                            child: _RetakeButton(onTap: _retakeLast),
                          ),

                          const SizedBox(width: 32),

                          // Shutter
                          _ShutterButton(
                            faceDetected: _faceDetected,
                            isCapturing: _isCapturing,
                            isComplete: _isComplete,
                            onTap: _captureAngle,
                          ),

                          const SizedBox(width: 32),

                          // Next button (visible once ≥1 captured)
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: _canProceed ? 1.0 : 0.0,
                            child: _NextButton(
                              onTap: _canProceed ? _proceed : () {},
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),
                      Text(
                        _isComplete
                            ? 'Tap Next to continue'
                            : _faceDetected
                            ? 'Tap shutter to capture this angle'
                            : 'Waiting for face…',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Angle progress dots ────────────────────────────────────────────────────────

class _AngleDots extends StatelessWidget {
  const _AngleDots({
    required this.total,
    required this.filled,
    required this.color,
  });

  final int total;
  final int filled;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final done = i < filled;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: done ? 28 : 10,
          height: 10,
          decoration: BoxDecoration(
            color: done ? color : Colors.white24,
            borderRadius: BorderRadius.circular(5),
          ),
        );
      }),
    );
  }
}

// ── Shutter button ─────────────────────────────────────────────────────────────

class _ShutterButton extends StatelessWidget {
  const _ShutterButton({
    required this.faceDetected,
    required this.isCapturing,
    required this.isComplete,
    required this.onTap,
  });

  final bool faceDetected;
  final bool isCapturing;
  final bool isComplete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final active = faceDetected && !isComplete;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isCapturing
              ? Colors.white24
              : isComplete
              ? Colors.white12
              : active
              ? primary
              : Colors.white.withValues(alpha: 0.15),
          border: Border.all(
            color: active ? primary : Colors.white38,
            width: 3,
          ),
          boxShadow: active && !isCapturing
              ? [
                  BoxShadow(
                    color: primary.withValues(alpha: 0.5),
                    blurRadius: 22,
                    spreadRadius: 3,
                  ),
                ]
              : [],
        ),
        child: isCapturing
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Icon(
                isComplete
                    ? Icons.check_rounded
                    : Icons.camera_alt_rounded,
                color: Colors.white,
                size: 34,
              ),
      ),
    );
  }
}

// ── Retake button ──────────────────────────────────────────────────────────────

class _RetakeButton extends StatelessWidget {
  const _RetakeButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.12),
          border: Border.all(color: Colors.white30, width: 1.5),
        ),
        child: const Icon(Icons.undo_rounded, color: Colors.white70, size: 22),
      ),
    );
  }
}

// ── Next button ────────────────────────────────────────────────────────────────

class _NextButton extends StatelessWidget {
  const _NextButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: primary.withValues(alpha: 0.2),
          border: Border.all(color: primary, width: 1.5),
        ),
        child: Icon(Icons.arrow_forward_rounded, color: primary, size: 22),
      ),
    );
  }
}

// ── Status pill ────────────────────────────────────────────────────────────────

class _Pill extends StatelessWidget {
  const _Pill({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
