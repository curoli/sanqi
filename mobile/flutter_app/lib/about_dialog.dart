import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_language.dart';
import 'build_info.dart';
import 'l10n/generated/app_localizations.dart';

Future<bool> _openInBrowser(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

class SanqiAboutDialog extends StatefulWidget {
  const SanqiAboutDialog({
    super.key,
    this.buildInfo = const AppBuildInfo(),
    this.openLink = _openInBrowser,
  });

  final AppBuildInfo buildInfo;
  final Future<bool> Function(Uri) openLink;

  @override
  State<SanqiAboutDialog> createState() => _SanqiAboutDialogState();
}

class _SanqiAboutDialogState extends State<SanqiAboutDialog> {
  final _scrollController = ScrollController();
  bool _moreBelow = false;
  Uri? _failedLink;
  int _linkEpoch = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateScrollHint);
  }

  void _updateScrollHint() {
    if (!mounted || !_scrollController.hasClients) return;
    final moreBelow = _scrollController.position.extentAfter > 1;
    if (_moreBelow != moreBelow) setState(() => _moreBelow = moreBelow);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _open(Uri uri) async {
    final epoch = ++_linkEpoch;
    setState(() => _failedLink = null);
    try {
      if (await widget.openLink(uri)) return;
    } catch (_) {
      // Keep the URL available to copy if the platform cannot open a browser.
    }
    if (mounted && epoch == _linkEpoch) setState(() => _failedLink = uri);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final language = AppLanguage.fromCode(l.localeName) ?? AppLanguage.english;
    final repository = Uri.https('github.com', '/curoli/sanqi');
    final rules = Uri.https(
      'github.com',
      '/curoli/sanqi/blob/main/docs/rules/sanqi-${language.code}.md',
    );
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
      title: Row(
        children: [
          SvgPicture.asset(
            'assets/branding/sanqi-logo.svg',
            width: 40,
            height: 40,
            semanticsLabel: l.logoLabel,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(l.aboutTitle)),
          IconButton(
            tooltip: l.close,
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: NotificationListener<ScrollMetricsNotification>(
                onNotification: (_) {
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _updateScrollHint(),
                  );
                  return false;
                },
                child: Scrollbar(
                  key: const Key('about-scrollbar'),
                  controller: _scrollController,
                  thumbVisibility: true,
                  trackVisibility: true,
                  child: SingleChildScrollView(
                    key: const Key('about-scroll-content'),
                    controller: _scrollController,
                    padding: const EdgeInsetsDirectional.only(end: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.pronunciation),
                        const SizedBox(height: 12),
                        Text(
                          l.slogan,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        Text(l.author),
                        const SizedBox(height: 20),
                        Text(l.buildDate),
                        SelectableText(
                          widget.buildInfo.date.isEmpty
                              ? l.buildNotRecorded
                              : widget.buildInfo.date,
                          key: const Key('build-date'),
                          textDirection: widget.buildInfo.date.isEmpty
                              ? null
                              : TextDirection.ltr,
                        ),
                        const SizedBox(height: 12),
                        Text(l.commitLabel),
                        SelectableText(
                          widget.buildInfo.commit.isEmpty
                              ? l.buildNotRecorded
                              : widget.buildInfo.commit,
                          key: const Key('build-commit'),
                          textDirection: widget.buildInfo.commit.isEmpty
                              ? null
                              : TextDirection.ltr,
                        ),
                        if (_failedLink != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            l.openLinkError,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                          SelectableText(
                            _failedLink.toString(),
                            textDirection: TextDirection.ltr,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 32,
              child: _moreBelow
                  ? TextButton.icon(
                      key: const Key('about-more-below'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                      ),
                      onPressed: () => _scrollController.animateTo(
                        (_scrollController.offset +
                                _scrollController.position.viewportDimension *
                                    .8)
                            .clamp(
                              0.0,
                              _scrollController.position.maxScrollExtent,
                            ),
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                      ),
                      icon: const Icon(Icons.expand_more, size: 18),
                      label: Text(
                        l.moreBelow,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        SizedBox(
          width: 420,
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('about-rules'),
                  onPressed: () => _open(rules),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(l.rulesLink),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  key: const Key('about-repository'),
                  onPressed: () => _open(repository),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(l.repositoryLink),
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
