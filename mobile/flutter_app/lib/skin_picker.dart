import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'app_skin.dart';
import 'game_background.dart';
import 'l10n/generated/app_localizations.dart';

class SkinPicker extends StatefulWidget {
  const SkinPicker({super.key, required this.selected});
  final AppSkin selected;

  @override
  State<SkinPicker> createState() => _SkinPickerState();
}

class _SkinPickerState extends State<SkinPicker> {
  ScrollController? _controller;
  double get _itemExtent =>
      math.max(80, 44 + MediaQuery.textScalerOf(context).scale(32));
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??= ScrollController(
      initialScrollOffset: widget.selected.index * _itemExtent,
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
        height: math.min(640, MediaQuery.sizeOf(context).height * .8),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.chooseSkin,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: l.close,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                l.skinScrollHint,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Scrollbar(
                controller: _controller,
                thumbVisibility: true,
                trackVisibility: true,
                child: ListView.builder(
                  key: const Key('skin-list'),
                  controller: _controller,
                  padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 20, 8),
                  itemCount: AppSkin.values.length,
                  itemExtent: _itemExtent,
                  itemBuilder: (context, index) {
                    final skin = AppSkin.values[index];
                    final selected = skin == widget.selected;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Semantics(
                        selected: selected,
                        child: Material(
                          color: skin.background,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: selected ? skin.accent : skin.border,
                              width: selected ? 3 : 1,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            key: Key('skin-${skin.name}'),
                            onTap: () => Navigator.pop(context, skin),
                            child: CustomPaint(
                              painter: GameBackground(skin: skin),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    Icon(
                                      skin.brightness == Brightness.light
                                          ? Icons.light_mode_outlined
                                          : Icons.dark_mode_outlined,
                                      color: skin.text,
                                      semanticLabel:
                                          skin.brightness == Brightness.light
                                          ? l.lightSkin
                                          : l.darkSkin,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        skin.label(l),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: skin.text,
                                          fontFamily: skin.fontFamily,
                                          fontFamilyFallback:
                                              skin.fallbackFonts,
                                          fontSize: 20,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: skin.button,
                                        border: Border.all(color: skin.border),
                                        borderRadius: BorderRadius.circular(
                                          skin.radius,
                                        ),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        child: Icon(
                                          selected
                                              ? Icons.check
                                              : Icons.palette_outlined,
                                          color: skin.buttonText,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () =>
                  showLicensePage(context: context, applicationName: 'Sanqi'),
              icon: const Icon(Icons.font_download_outlined),
              label: Text(l.fontLicenses),
            ),
          ],
        ),
      ),
    );
  }
}
