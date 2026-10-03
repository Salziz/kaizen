import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Opens the Groq Live API Settings modal bottom sheet.
Future<void> showGroqApiKeyModal(
  BuildContext context, {
  VoidCallback? onKeyChanged,
}) async {
  final preferences = SharedPreferencesAsync();
  final currentKey = (await preferences.getString('groq_api_key')) ?? '';
  var savedModel = await preferences.getString('groq_model');
  if (savedModel == null || savedModel == 'openai/gpt-oss-120b') {
    savedModel = 'llama-3.3-70b-versatile';
  }
  final currentModel = savedModel;

  final keyController = TextEditingController(text: currentKey);
  final modelController = TextEditingController(text: currentModel);
  bool obscureKey = true;

  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF14151B),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (modalContext, setModalState) {
          final hasKey = keyController.text.trim().isNotEmpty;
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 24,
              bottom: MediaQuery.of(modalContext).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          hasKey ? Icons.bolt_rounded : Icons.key_rounded,
                          color: hasKey
                              ? const Color(0xFF10B981)
                              : Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Groq Live API Settings',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(modalContext),
                      icon: const Icon(Icons.close, color: Color(0xFFA1A1AA)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  hasKey
                      ? 'Live Groq API mode is ACTIVE. Messages will be sent to the real Groq completion endpoint.'
                      : 'Currently using Stage-Safe Demo Fallback. Enter your Groq API key to test live LLM fact extraction.',
                  style: TextStyle(
                    color: hasKey
                        ? const Color(0xFF34D399)
                        : const Color(0xFFA1A1AA),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'GROQ API KEY',
                  style: TextStyle(
                    color: Color(0xFF71717A),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const Key('groq_api_key_input'),
                  controller: keyController,
                  obscureText: obscureKey,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'gsk_...',
                    hintStyle: const TextStyle(color: Color(0xFF52525B)),
                    filled: true,
                    fillColor: const Color(0xFF1C1D24),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF27272A)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF27272A)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF10B981)),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureKey ? Icons.visibility_off : Icons.visibility,
                        color: const Color(0xFFA1A1AA),
                        size: 20,
                      ),
                      onPressed: () {
                        setModalState(() => obscureKey = !obscureKey);
                      },
                    ),
                  ),
                  onChanged: (_) => setModalState(() {}),
                ),
                const SizedBox(height: 14),
                const Text(
                  'MODEL',
                  style: TextStyle(
                    color: Color(0xFF71717A),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const Key('groq_model_input'),
                  controller: modelController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'e.g. llama-3.3-70b-versatile',
                    hintStyle: const TextStyle(color: Color(0xFF52525B)),
                    filled: true,
                    fillColor: const Color(0xFF1C1D24),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF27272A)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF27272A)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF10B981)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ActionChip(
                      label: const Text('llama-3.3-70b-versatile',
                          style: TextStyle(fontSize: 11, color: Color(0xFF10B981))),
                      backgroundColor: const Color(0xFF1C1D24),
                      side: const BorderSide(color: Color(0xFF27272A)),
                      onPressed: () {
                        setModalState(() {
                          modelController.text = 'llama-3.3-70b-versatile';
                        });
                      },
                    ),
                    ActionChip(
                      label: const Text('llama-3.1-8b-instant',
                          style: TextStyle(fontSize: 11, color: Color(0xFFA1A1AA))),
                      backgroundColor: const Color(0xFF1C1D24),
                      side: const BorderSide(color: Color(0xFF27272A)),
                      onPressed: () {
                        setModalState(() {
                          modelController.text = 'llama-3.1-8b-instant';
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (currentKey.isNotEmpty) ...[
                      Expanded(
                        child: OutlinedButton(
                          key: const Key('clear_groq_key_button'),
                          onPressed: () async {
                            await preferences.remove('groq_api_key');
                            onKeyChanged?.call();
                            if (ctx.mounted) Navigator.pop(modalContext);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFEF4444),
                            side: const BorderSide(color: Color(0xFF7F1D1D)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Clear Key'),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: ElevatedButton(
                        key: const Key('save_groq_key_button'),
                        onPressed: () async {
                          final key = keyController.text.trim();
                          final model = modelController.text.trim();
                          if (key.isNotEmpty) {
                            await preferences.setString('groq_api_key', key);
                          } else {
                            await preferences.remove('groq_api_key');
                          }
                          if (model.isNotEmpty) {
                            await preferences.setString('groq_model', model);
                          }
                          onKeyChanged?.call();
                          if (ctx.mounted) Navigator.pop(modalContext);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          hasKey ? 'Save & Connect' : 'Use Fallback',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
