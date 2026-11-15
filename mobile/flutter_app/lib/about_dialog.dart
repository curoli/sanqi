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
  Uri? _failedLink;
  int _linkEpoch = 0;

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
        ],
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.pronunciation),
              const SizedBox(height: 12),
              Text(l.slogan, style: Theme.of(context).textTheme.titleMedium),
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
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    key: const Key('about-rules'),
                    onPressed: () => _open(rules),
                    icon: const Icon(Icons.menu_book),
                    label: Text(l.rulesLink),
                  ),
                  OutlinedButton.icon(
                    key: const Key('about-repository'),
                    onPressed: () => _open(repository),
                    icon: const Icon(Icons.open_in_new),
                    label: Text(l.repositoryLink),
                  ),
                ],
              ),
              if (_failedLink != null) ...[
                const SizedBox(height: 12),
                Text(
                  l.openLinkError,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
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
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.close),
        ),
      ],
    );
  }
}
