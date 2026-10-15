import 'package:flutter/material.dart';
import 'package:face_detection_plugin/face_detection_plugin.dart';

import '../db/objectbox_store.dart';
import '../widgets/camera_permission_gate.dart';

/// Identifies a face from the live camera and shows the matched person's
/// full details card in the UI.
class IdentifyCameraScreen extends StatefulWidget {
  const IdentifyCameraScreen({super.key, required this.store});

  final ObjectBoxVectorStore store;

  @override
  State<IdentifyCameraScreen> createState() => _IdentifyCameraScreenState();
}

class _IdentifyCameraScreenState extends State<IdentifyCameraScreen> {
  final _facePlugin = FaceDetectionPlugin();

  bool _faceDetected = false;
  FaceRecognitionResult? _result;

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
        final rawEmbedding = frameData['embedding'];
        if (rawEmbedding is List && rawEmbedding.isNotEmpty) {
          final embedding = rawEmbedding
              .map((e) => (e as num).toDouble())
              .toList();
          _processEmbedding(embedding);
        } else {
          if (_faceDetected) setState(() => _faceDetected = false);
        }
      },
      onEmbeddingExtracted: (embedding, _) {
        if (!mounted) return;
        _processEmbedding(embedding);
      },
    );
  }

  void _processEmbedding(List<double> embedding) {
    final result = widget.store.findNearestFace(embedding, threshold: 0.75);
    setState(() {
      _faceDetected = true;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CameraPermissionGate(
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Identify Face',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ── Native camera ────────────────────────────────────────────────
            const FaceCameraView(),

            // ── Border glow ───────────────────────────────────────────────────
            if (_faceDetected)
              IgnorePointer(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _result != null
                          ? Colors.greenAccent.withValues(alpha: 0.6)
                          : Colors.amberAccent.withValues(alpha: 0.4),
                      width: 3,
                    ),
                  ),
                ),
              ),

            // ── Result card at the bottom ─────────────────────────────────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.3),
                    end: Offset.zero,
                  ).animate(animation),
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: _faceDetected
                    ? (_result != null
                          ? _MatchedCard(
                              key: ValueKey(_result!.record.id),
                              result: _result!,
                            )
                          : const _UnknownCard(key: ValueKey('unknown')))
                    : const _WaitingCard(key: ValueKey('waiting')),
              ),
            ),
          ],
        ),
      ), // Scaffold
    ); // CameraPermissionGate
  }
}

// ── Waiting card ───────────────────────────────────────────────────────────────

class _WaitingCard extends StatelessWidget {
  const _WaitingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            const Icon(Icons.face_outlined, color: Colors.white30, size: 28),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Scanning...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Point the camera at a face',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Unknown face card ──────────────────────────────────────────────────────────

class _UnknownCard extends StatelessWidget {
  const _UnknownCard({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.80),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.amberAccent.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.amberAccent.withValues(alpha: 0.15),
              ),
              child: const Icon(
                Icons.help_outline_rounded,
                color: Colors.amberAccent,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Unknown Person',
                  style: TextStyle(
                    color: Colors.amberAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'No match found in the database',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Matched person card ────────────────────────────────────────────────────────

class _MatchedCard extends StatelessWidget {
  const _MatchedCard({super.key, required this.result});

  final FaceRecognitionResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final record = result.record;
    final pct = (result.similarityScore * 100).toStringAsFixed(1);

    final initials = record.name
        .trim()
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();

    final registeredAt = DateTime.fromMillisecondsSinceEpoch(record.createdAt);
    final dateStr =
        '${registeredAt.day}/${registeredAt.month}/${registeredAt.year}';

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.greenAccent.withValues(alpha: 0.45),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header row ────────────────────────────────────────────────
            Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 28,
                  backgroundColor: theme.colorScheme.primary.withValues(
                    alpha: 0.25,
                  ),
                  child: Text(
                    initials,
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.verified_rounded,
                            color: Colors.greenAccent,
                            size: 16,
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'Identity Confirmed',
                            style: TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        record.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Details grid ──────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _DetailChip(
                    icon: Icons.cake_outlined,
                    label: 'Age',
                    value: '${record.age} yrs',
                    color: theme.colorScheme.secondary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DetailChip(
                    icon: Icons.calendar_today_outlined,
                    label: 'Registered',
                    value: dateStr,
                    color: Colors.cyanAccent,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Match confidence bar ──────────────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Match confidence',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      '$pct%',
                      style: TextStyle(
                        color: result.similarityScore > 0.85
                            ? Colors.greenAccent
                            : Colors.amberAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: result.similarityScore.clamp(0.0, 1.0),
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation(
                      result.similarityScore > 0.85
                          ? Colors.greenAccent
                          : Colors.amberAccent,
                    ),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 10,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
