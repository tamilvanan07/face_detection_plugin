import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Wraps [child] behind a camera permission check.
/// Shows a request UI if permission is not yet granted,
/// and a settings prompt if permanently denied.
class CameraPermissionGate extends StatefulWidget {
  const CameraPermissionGate({super.key, required this.child});

  final Widget child;

  @override
  State<CameraPermissionGate> createState() => _CameraPermissionGateState();
}

class _CameraPermissionGateState extends State<CameraPermissionGate>
    with WidgetsBindingObserver {
  _PermState _state = _PermState.checking;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Re-check when app comes back from Settings
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _state == _PermState.denied) {
      _check();
    }
  }

  Future<void> _check() async {
    setState(() => _state = _PermState.checking);
    final status = await Permission.camera.status;
    if (!mounted) return;

    if (status.isGranted) {
      setState(() => _state = _PermState.granted);
    } else if (status.isPermanentlyDenied) {
      setState(() => _state = _PermState.permanentlyDenied);
    } else {
      setState(() => _state = _PermState.notDetermined);
    }
  }

  Future<void> _request() async {
    final result = await Permission.camera.request();
    if (!mounted) return;

    if (result.isGranted) {
      setState(() => _state = _PermState.granted);
    } else if (result.isPermanentlyDenied) {
      setState(() => _state = _PermState.permanentlyDenied);
    } else {
      setState(() => _state = _PermState.denied);
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case _PermState.granted:
        return widget.child;

      case _PermState.checking:
        return const _PermissionScaffold(
          icon: Icons.camera_alt_outlined,
          iconColor: Colors.white30,
          title: 'Checking permissions...',
          body: null,
          action: null,
        );

      case _PermState.notDetermined:
        return _PermissionScaffold(
          icon: Icons.camera_alt_rounded,
          iconColor: Colors.deepPurpleAccent,
          title: 'Camera access needed',
          body: 'This screen uses your camera for face detection.\n'
              'Please allow camera access to continue.',
          action: FilledButton.icon(
            onPressed: _request,
            icon: const Icon(Icons.camera_alt_rounded),
            label: const Text('Allow Camera'),
          ),
        );

      case _PermState.denied:
        return _PermissionScaffold(
          icon: Icons.no_photography_rounded,
          iconColor: Colors.amberAccent,
          title: 'Camera permission denied',
          body: 'Camera access was denied. Tap below to try again.',
          action: FilledButton.icon(
            onPressed: _request,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try Again'),
          ),
        );

      case _PermState.permanentlyDenied:
        return _PermissionScaffold(
          icon: Icons.no_photography_rounded,
          iconColor: Colors.redAccent,
          title: 'Camera permission blocked',
          body: 'Camera access is permanently blocked.\n'
              'Open Settings to enable it manually.',
          action: FilledButton.icon(
            onPressed: openAppSettings,
            icon: const Icon(Icons.settings_rounded),
            label: const Text('Open Settings'),
          ),
        );
    }
  }
}

enum _PermState { checking, granted, notDetermined, denied, permanentlyDenied }

class _PermissionScaffold extends StatelessWidget {
  const _PermissionScaffold({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
    required this.action,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 64, color: iconColor),
                const SizedBox(height: 20),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (body != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    body!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
                if (action != null) ...[
                  const SizedBox(height: 32),
                  action!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
