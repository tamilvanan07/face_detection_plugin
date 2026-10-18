import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../db/objectbox_store.dart';

/// Step 2 of the registration flow.
/// Receives pre-captured [embeddings] (one per angle) and the shared [store].
/// On save, calls [store.addPerson] and pops with `true`.
class RegisterDetailsScreen extends StatefulWidget {
  const RegisterDetailsScreen({
    super.key,
    required this.embeddings,
    required this.store,
  });

  /// One embedding per captured angle (1–5).
  final List<List<double>> embeddings;
  final ObjectBoxVectorStore store;

  @override
  State<RegisterDetailsScreen> createState() => _RegisterDetailsScreenState();
}

class _RegisterDetailsScreenState extends State<RegisterDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final name = _nameController.text.trim();
      final age = int.parse(_ageController.text.trim());

      widget.store.addPerson(
        name: name,
        age: age,
        embeddings: widget.embeddings,
      );

      if (!mounted) return;
      Navigator.pop(context, true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '"$name" registered with ${widget.embeddings.length} '
            'angle${widget.embeddings.length == 1 ? '' : 's'}!',
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final angleCount = widget.embeddings.length;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white),
          onPressed: () => Navigator.pop(context, false),
        ),
        title: const Text(
          'Register Details',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Face captured badge ──────────────────────────────────
                Center(
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.green.shade900
                          .withValues(alpha: 0.4),
                      border: Border.all(
                        color:
                            Colors.greenAccent.withValues(alpha: 0.6),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.face_retouching_natural,
                      size: 44,
                      color: Colors.greenAccent,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Center(
                  child: Text(
                    'Face captured ✓',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    '$angleCount angle${angleCount == 1 ? '' : 's'} · '
                    '${widget.embeddings.first.length}-dim embedding each',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.28),
                      fontSize: 11,
                    ),
                  ),
                ),

                // ── Angle dots preview ───────────────────────────────────
                const SizedBox(height: 16),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(5, (i) {
                      final done = i < angleCount;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin:
                            const EdgeInsets.symmetric(horizontal: 4),
                        width: done ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: done
                              ? Colors.greenAccent
                              : Colors.white12,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                ),

                const SizedBox(height: 36),

                // ── Name ─────────────────────────────────────────────────
                _buildField(
                  controller: _nameController,
                  label: 'Full name',
                  hint: 'e.g. Alice Johnson',
                  icon: Icons.person_outline_rounded,
                  theme: theme,
                  capitalization: TextCapitalization.words,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Enter a name';
                    }
                    if (v.trim().length < 2) {
                      return 'At least 2 characters';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 18),

                // ── Age ──────────────────────────────────────────────────
                _buildField(
                  controller: _ageController,
                  label: 'Age',
                  hint: 'e.g. 28',
                  icon: Icons.cake_outlined,
                  theme: theme,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly
                  ],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Enter an age';
                    }
                    final n = int.tryParse(v.trim());
                    if (n == null || n < 1 || n > 120) {
                      return 'Enter 1–120';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 36),

                // ── Save ─────────────────────────────────────────────────
                SizedBox(
                  height: 54,
                  child: FilledButton(
                    onPressed: _isSaving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      disabledBackgroundColor: theme
                          .colorScheme.primary
                          .withValues(alpha: 0.4),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.save_rounded,
                                  size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Save to Database ($angleCount angle'
                                '${angleCount == 1 ? '' : 's'})',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 14),

                TextButton(
                  onPressed: _isSaving
                      ? null
                      : () => Navigator.pop(context, false),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required ThemeData theme,
    required String? Function(String?) validator,
    TextCapitalization capitalization = TextCapitalization.none,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      textCapitalization: capitalization,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.55)),
        hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.22)),
        prefixIcon: Icon(icon, color: theme.colorScheme.primary),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.13)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: theme.colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: Colors.redAccent, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: Colors.redAccent, width: 2),
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
      ),
      validator: validator,
    );
  }
}
