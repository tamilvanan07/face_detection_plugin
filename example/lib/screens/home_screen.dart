import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:face_detection_plugin/face_detection_plugin.dart';

import '../db/person.dart';
import '../db/objectbox_store.dart';
import 'identify_camera_screen.dart';
import 'register_camera_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store});

  final ObjectBoxVectorStore store;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _facePlugin = FaceDetectionPlugin();
  String _platformVersion = 'Checking...';
  List<Person> _records = [];

  @override
  void initState() {
    super.initState();
    _fetchPlatformVersion();
    _refreshRecords();
  }

  Future<void> _fetchPlatformVersion() async {
    String version;
    try {
      version = await _facePlugin.getPlatformVersion() ?? 'Unknown';
    } on PlatformException {
      version = 'Unavailable';
    }
    if (!mounted) return;
    setState(() => _platformVersion = version);
  }

  void _refreshRecords() {
    if (!mounted) return;
    setState(() => _records = widget.store.getAllPersons());
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  Future<void> _openRegister() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RegisterCameraScreen(store: widget.store),
      ),
    );
    _refreshRecords();
  }

  Future<void> _openIdentify() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IdentifyCameraScreen(store: widget.store),
      ),
    );
  }

  Future<void> _deleteRecord(Person record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove person?'),
        content: Text('Delete "${record.name}" from the database?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      widget.store.removePerson(record.id);
      _refreshRecords();
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ───────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.tertiary,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.35,
                          ),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.face_retouching_natural,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Face Recognition',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _platformVersion,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // ── Two main action buttons ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  // Register
                  Expanded(
                    child: _ActionCard(
                      icon: Icons.person_add_rounded,
                      label: 'Register\nFace',
                      subtitle: 'Add a new person',
                      color: theme.colorScheme.primary,
                      onTap: _openRegister,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Identify
                  Expanded(
                    child: _ActionCard(
                      icon: Icons.manage_search_rounded,
                      label: 'Identify\nFace',
                      subtitle: 'Recognise a person',
                      color: Colors.tealAccent.shade400,
                      onTap: _records.isEmpty ? null : _openIdentify,
                      disabledHint: _records.isEmpty
                          ? 'Register someone first'
                          : null,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Registered persons list ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Registered Persons',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_records.length}',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // List or empty state
            Expanded(
              child: _records.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      itemCount: _records.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (_, i) => _PersonTile(
                        record: _records[i],
                        angleCount: widget.store
                            .embeddingCountForPerson(_records[i].id),
                        onDelete: () => _deleteRecord(_records[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.group_outlined,
            size: 56,
            color: Colors.white.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 12),
          Text(
            'No faces registered yet',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap "Register Face" to get started',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.2),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Action card widget ─────────────────────────────────────────────────────────

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.disabledHint,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;
  final String? disabledHint;

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null;

    return GestureDetector(
      onTap: isDisabled
          ? () {
              if (disabledHint != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(disabledHint!),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              }
            }
          : onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: isDisabled ? 0.45 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: color.withValues(alpha: 0.25),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 14),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Person tile widget ─────────────────────────────────────────────────────────

class _PersonTile extends StatelessWidget {
  const _PersonTile({
    required this.record,
    required this.angleCount,
    required this.onDelete,
  });

  final Person record;
  final int angleCount;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final initials = record.name
        .trim()
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();

    final registeredAt =
        DateTime.fromMillisecondsSinceEpoch(record.createdAt);
    final dateStr =
        '${registeredAt.day}/${registeredAt.month}/${registeredAt.year}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 24,
            backgroundColor: Theme.of(context)
                .colorScheme
                .primary
                .withValues(alpha: 0.2),
            child: Text(
              initials,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Age ${record.age}  ·  Added $dateStr',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 4),
                // Angle count badge
                Row(
                  children: [
                    Icon(Icons.rotate_90_degrees_ccw_rounded,
                        size: 11,
                        color: Colors.white.withValues(alpha: 0.35)),
                    const SizedBox(width: 4),
                    Text(
                      '$angleCount angle${angleCount == 1 ? '' : 's'} captured',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Delete
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Colors.white30,
              size: 20,
            ),
            onPressed: onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
