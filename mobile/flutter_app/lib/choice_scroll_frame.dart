import 'package:material_ui/material_ui.dart';

import 'l10n/generated/app_localizations.dart';

/// Persistent, actionable cues for choices above and below the viewport.
class ChoiceScrollFrame extends StatefulWidget {
  const ChoiceScrollFrame({
    super.key,
    required this.controller,
    required this.child,
  });
  final ScrollController controller;
  final Widget child;
  @override
  State<ChoiceScrollFrame> createState() => _ChoiceScrollFrameState();
}

class _ChoiceScrollFrameState extends State<ChoiceScrollFrame> {
  bool _above = false, _below = false;
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_update);
  }

  void _update() {
    if (!mounted || !widget.controller.hasClients) return;
    final position = widget.controller.position;
    final above = position.extentBefore > 1, below = position.extentAfter > 1;
    if (above != _above || below != _below) {
      setState(() {
        _above = above;
        _below = below;
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_update);
    super.dispose();
  }

  void _scroll(int direction) {
    final p = widget.controller.position;
    widget.controller.animateTo(
      (p.pixels + direction * p.viewportDimension * .8).clamp(
        0.0,
        p.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    Widget cue(bool visible, bool above) => SizedBox(
      height: 32,
      child: visible
          ? TextButton.icon(
              key: Key(above ? 'choices-above' : 'choices-below'),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
              ),
              onPressed: () => _scroll(above ? -1 : 1),
              icon: Icon(
                above ? Icons.expand_less : Icons.expand_more,
                size: 18,
              ),
              label: Text(
                above ? l.moreAbove : l.moreBelow,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            )
          : null,
    );
    return Column(
      children: [
        cue(_above, true),
        Expanded(
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: (_) {
              WidgetsBinding.instance.addPostFrameCallback((_) => _update());
              return false;
            },
            child: Scrollbar(
              controller: widget.controller,
              thumbVisibility: true,
              trackVisibility: true,
              child: widget.child,
            ),
          ),
        ),
        cue(_below, false),
      ],
    );
  }
}
