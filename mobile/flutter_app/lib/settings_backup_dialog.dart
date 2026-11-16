import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'app_language.dart';
import 'app_skin.dart';
import 'l10n/generated/app_localizations.dart';

class SettingsBackup {
  const SettingsBackup(this.language, this.skin);
  final AppLanguage language;
  final AppSkin skin;
  String encode() => const JsonEncoder.withIndent(
    '  ',
  ).convert({'sanqiSettings': 1, 'language': language.code, 'skin': skin.name});
  static SettingsBackup decode(String text) {
    final data = jsonDecode(text);
    if (data is! Map<String, dynamic> ||
        data['sanqiSettings'] != 1 ||
        data['language'] is! String ||
        data['skin'] is! String) {
      throw const FormatException();
    }
    final language = AppLanguage.fromCode(data['language']);
    final skin = AppSkin.fromId(data['skin']);
    if (language == null || skin == null) throw const FormatException();
    return SettingsBackup(language, skin);
  }
}

class SettingsBackupDialog extends StatefulWidget {
  const SettingsBackupDialog({
    super.key,
    required this.settings,
    required this.onRestore,
  });
  final SettingsBackup settings;
  final Future<void> Function(SettingsBackup) onRestore;
  @override
  State<SettingsBackupDialog> createState() => _SettingsBackupDialogState();
}

class _SettingsBackupDialogState extends State<SettingsBackupDialog> {
  late final _text = TextEditingController(text: widget.settings.encode());
  final _scroll = ScrollController();
  bool _busy = false;
  bool _failed = false;
  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(
        l.settingsBackup,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      content: SizedBox(
        width: 420,
        child: Scrollbar(
          controller: _scroll,
          thumbVisibility: true,
          trackVisibility: true,
          child: SingleChildScrollView(
            controller: _scroll,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l.settingsBackupHint),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('settings-backup-input'),
                  controller: _text,
                  enabled: !_busy,
                  textDirection: TextDirection.ltr,
                  minLines: 3,
                  maxLines: 6,
                ),
                if (_failed)
                  Text(
                    l.settingsRestoreError,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        SizedBox(
          width: 420,
          child: Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          try {
                            await Clipboard.setData(
                              ClipboardData(text: _text.text),
                            );
                          } catch (_) {
                            if (mounted) setState(() => _failed = true);
                          }
                        },
                  child: FittedBox(fit: BoxFit.scaleDown, child: Text(l.copy)),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: _busy ? null : () => Navigator.pop(context, false),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(l.cancel),
                  ),
                ),
              ),
              Expanded(
                child: FilledButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          setState(() {
                            _busy = true;
                            _failed = false;
                          });
                          try {
                            final settings = SettingsBackup.decode(_text.text);
                            await widget.onRestore(settings);
                            if (context.mounted) Navigator.pop(context, true);
                          } catch (_) {
                            if (mounted) {
                              setState(() {
                                _busy = false;
                                _failed = true;
                              });
                            }
                          }
                        },
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(l.restore),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
