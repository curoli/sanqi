import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'app_language.dart';
import 'choice_scroll_frame.dart';
import 'l10n/generated/app_localizations.dart';

class LanguagePicker extends StatefulWidget {
  const LanguagePicker({
    super.key,
    required this.selected,
    required this.onBackup,
    this.firstLaunch = false,
    this.onSelected,
    this.enabled = true,
    this.error,
  });
  final AppLanguage selected;
  final Future<bool> Function() onBackup;
  final bool firstLaunch;
  final ValueChanged<String>? onSelected;
  final bool enabled;
  final String? error;
  @override
  State<LanguagePicker> createState() => _LanguagePickerState();
}

class _LanguagePickerState extends State<LanguagePicker> {
  ScrollController? _controller;
  double get _extent =>
      math.max(56, 28 + MediaQuery.textScalerOf(context).scale(24));
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??= ScrollController(
      initialScrollOffset: widget.selected.index * _extent,
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: 440,
        height: math.min(640, MediaQuery.sizeOf(context).height * .9),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.language,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: l.settingsBackup,
                    icon: const Icon(Icons.save_outlined),
                    onPressed: !widget.enabled
                        ? null
                        : () async {
                            final restored = await widget.onBackup();
                            if (restored &&
                                context.mounted &&
                                !widget.firstLaunch) {
                              Navigator.pop(context);
                            }
                          },
                  ),
                  if (!widget.firstLaunch)
                    IconButton(
                      tooltip: l.close,
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                ],
              ),
            ),
            if (widget.firstLaunch)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  l.firstLanguageHint,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (widget.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  widget.error!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Expanded(
              child: ChoiceScrollFrame(
                controller: _controller!,
                child: SingleChildScrollView(
                  key: const Key('language-list'),
                  controller: _controller,
                  padding: const EdgeInsetsDirectional.only(start: 12, end: 20),
                  child: Column(
                    children: [
                      for (final language in AppLanguage.values)
                        SizedBox(
                          height: _extent,
                          child: ListTile(
                            selected: language == widget.selected,
                            title: Text(
                              '${language.flag} ${language.name}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textDirection: language.isRtl
                                  ? TextDirection.rtl
                                  : TextDirection.ltr,
                            ),
                            trailing: language == widget.selected
                                ? const Icon(Icons.check)
                                : null,
                            onTap: !widget.enabled
                                ? null
                                : () {
                                    if (widget.onSelected != null) {
                                      widget.onSelected!(language.code);
                                    } else {
                                      Navigator.pop(context, language.code);
                                    }
                                  },
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
