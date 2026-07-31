import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../widgets/kyle_design/feedback/mealvana_snackbar.dart';

/// The live policy, and the same URL registered as the Privacy Policy in App
/// Store Connect. Apple Guideline 5.1.1(i) expects the policy to be reachable
/// from inside the app as well as from the store listing — until now it was
/// only ever the store metadata URL and appeared nowhere in the app.
///
/// Both verified live 2026-07-13. Note the paths are not symmetrical:
/// `/privacy-policy` and `/terms-of-service` resolve; `/privacy` and `/terms`
/// 404 on this host.
const kPrivacyPolicyUrl = 'https://www.mealvana.io/privacy-policy';
const kTermsOfServiceUrl = 'https://www.mealvana.io/terms-of-service';

Future<void> openPrivacyPolicy(BuildContext context) =>
    _openExternal(context, kPrivacyPolicyUrl, 'privacy policy');

Future<void> openTermsOfService(BuildContext context) =>
    _openExternal(context, kTermsOfServiceUrl, 'terms of service');

/// Opens [url], surfacing a failure rather than silently doing nothing.
///
/// Deliberately does not gate on `canLaunchUrl`: it is unreliable for https on
/// some platforms (and can report false for a URL that would in fact open).
/// We attempt the launch and trust its return value, which is the thing that
/// actually tells us whether the page opened. These links are a compliance
/// surface — a policy link that silently fails is the same as not having one.
Future<void> _openExternal(
  BuildContext context,
  String url,
  String label,
) async {
  var launched = false;
  try {
    launched = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    launched = false;
  }

  if (!launched && context.mounted) {
    MealvanaSnackbar.showError(context, 'Could not open the $label');
  }
}
