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

/// Dismissible "update available" banner (for optional updates).
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
            if (info.notes.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(info.notes,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.sub, fontSize: 12)),
            ],
          ]),
        ),
        const SizedBox(width: 8),
        Column(mainAxisSize: MainAxisSize.min, children: [
          GestureDetector(
            onTap: () => openApk(context, info.apkUrl),
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
              if (info.notes.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(info.notes, style: TextStyle(color: c.sub, fontSize: 12.5)),
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
