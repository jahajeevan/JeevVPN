import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'theme.dart';
import 'update_service.dart';
import 'widgets.dart';

/// Opens the APK download URL in the browser, which downloads it; the user then
/// taps the file to install (they already allow "unknown apps" for sideloading).
Future<void> openApk(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  final messenger = ScaffoldMessenger.of(context);
  var ok = false;
  if (uri != null) {
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
  }
  if (!ok) {
    messenger.showSnackBar(
        const SnackBar(content: Text('Could not open the download. Try again.')));
  }
}

/// Splits the manifest's `notes` into individual changelog lines. Accepts
/// newline- or bullet-separated text and strips any leading bullet glyphs.
List<String> changelogLines(String notes) {
  return notes
      .split(RegExp(r'[\n•]+'))
      .map((l) => l.trim().replaceFirst(RegExp(r'^[-*]\s*'), '').trim())
      .where((l) => l.isNotEmpty)
      .toList();
}

/// The full "What's new" sheet: version, the feature list, and a Download
/// button. This is where the user reads what changed and gets the new build —
/// no separate installer to hunt for.
Future<void> showWhatsNewSheet(BuildContext context, UpdateInfo info) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final c = AppColors.of(ctx);
      final lines = changelogLines(info.notes);
      return Container(
        decoration: BoxDecoration(
          color: c.dark ? const Color(0xFF0C1119) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
        child: SafeArea(
          top: false,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: c.track, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [kMint, kGreenCore]),
                    borderRadius: BorderRadius.circular(13)),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("What's new",
                          style:
                              display(20, weight: FontWeight.w700, color: c.ink)),
                      Text('Version ${info.versionName}',
                          style: TextStyle(color: c.sub, fontSize: 13)),
                    ]),
              ),
              if (info.mandatory)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: const Color(0xFFEAA23B).withOpacity(0.16),
                      borderRadius: BorderRadius.circular(999)),
                  child: const Text('Required',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFB9791F))),
                ),
            ]),
            const SizedBox(height: 20),
            Flexible(
              child: SingleChildScrollView(
                child: lines.isEmpty
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                            'A newer version of JeevVPN is available with '
                            'improvements and fixes.',
                            style: TextStyle(color: c.sub, fontSize: 13.5)),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [for (final l in lines) _ChangeRow(text: l, c: c)],
                      ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                label: 'Download update',
                icon: Icons.download_rounded,
                onTap: () => openApk(ctx, info.apkUrl),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                  'Opens the download in your browser · tap the file to install',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, color: c.faint)),
            ),
          ]),
        ),
      );
    },
  );
}

class _ChangeRow extends StatelessWidget {
  final String text;
  final AppColors c;
  const _ChangeRow({required this.text, required this.c});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(Icons.check_circle_rounded, size: 18, color: kGreenDeep),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: TextStyle(color: c.ink, fontSize: 13.5, height: 1.4)),
        ),
      ]),
    );
  }
}

/// Dismissible "update available" banner (for optional updates). Tapping it —
/// or the Update button — opens the What's new sheet where the user downloads.
class UpdateBanner extends StatelessWidget {
  final UpdateInfo info;
  final VoidCallback onDismiss;
  const UpdateBanner({super.key, required this.info, required this.onDismiss});
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GlassCard(
      blur: 14,
      tint: kGreen.withOpacity(c.dark ? 0.12 : 0.14),
      border: Border.all(color: kGreen.withOpacity(0.4)),
      onTap: () => showWhatsNewSheet(context, info),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [kMint, kGreenCore]),
              borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.system_update_rounded, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Update available · v${info.versionName}',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: c.ink, fontSize: 14)),
            const SizedBox(height: 2),
            Text('See what’s new and download',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: c.sub, fontSize: 12)),
          ]),
        ),
        const SizedBox(width: 8),
        Column(mainAxisSize: MainAxisSize.min, children: [
          GestureDetector(
            onTap: () => showWhatsNewSheet(context, info),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [kGreen, kGreenCore]),
                  borderRadius: BorderRadius.circular(10)),
              child: const Text('Update',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5)),
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Later', style: TextStyle(color: c.faint, fontSize: 11)),
            ),
          ),
        ]),
      ]),
    );
  }
}

/// Non-dismissible dialog for an important (mandatory) update.
Future<void> showMandatoryUpdateDialog(BuildContext context, UpdateInfo info) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      final c = AppColors.of(ctx);
      final lines = changelogLines(info.notes);
      return PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: c.dark ? const Color(0xFF0C1119) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            const Icon(Icons.system_update_rounded, color: kGreenDeep),
            const SizedBox(width: 10),
            Expanded(
                child: Text('Update required',
                    style: display(18, weight: FontWeight.w700, color: c.ink))),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'A newer version (v${info.versionName}) is needed to keep JeevVPN working.',
                  style: TextStyle(color: c.sub, fontSize: 13.5)),
              if (lines.isNotEmpty) ...[
                const SizedBox(height: 14),
                for (final l in lines) _ChangeRow(text: l, c: c),
              ],
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                  label: 'Update now',
                  icon: Icons.download_rounded,
                  onTap: () => openApk(ctx, info.apkUrl)),
            ),
          ],
        ),
      );
    },
  );
}
