/// The credit a Land Info card owes for the ground it just described.
library;

import 'models.dart';

/// One credit line per source that actually answered the tap.
///
/// Built from the layers hit rather than from the province, because a province
/// is not one licence. Four of Ontario's layers are federal and carry the Open
/// Government Licence – Canada, so a tap on a reserve or a defence property used
/// to credit Ontario for a boundary Ontario did not publish. Quebec was worse:
/// its manifest names a licence that none of its layers use.
///
/// Each open licence obliges us to name *its* provider — OGL-Ontario puts it as
/// acknowledging the source "by including any attribution statement specified by
/// the Information Provider(s)" — so crediting one province for all of them
/// satisfies neither licence.
///
/// Falls back to the province's own licence when nothing was hit, which is the
/// honest answer for a tap on ground no layer covers: the pack is still the
/// province's work even where it has no parcel to show.
String landCredit(
  Iterable<LandFeature> hits,
  Map<String, LoadedLayer> layers, {
  required String provinceLicense,
  required String provinceLicenseUrl,
}) {
  // Insertion-ordered, and hits arrive in overlay order, so two taps on the same
  // ground credit the same sources in the same order.
  final credits = <String, String>{};
  for (final hit in hits) {
    final layer = layers[hit.layerId];
    if (layer == null) continue;
    final license = layer.license?.trim() ?? '';
    // What a layer with no features says about its licence. Not a credit.
    if (license.isEmpty || license == 'n/a') continue;
    final url = layer.licenseUrl?.trim() ?? '';
    // Keyed on the URL, because Ontario's overlays spell one licence two ways —
    // `OGL-Ontario` and `Open Government Licence – Ontario` — while pointing at
    // the same document. Naming it twice would read as two separate obligations.
    credits.putIfAbsent(
      url.isEmpty ? license.toLowerCase() : url,
      () => _creditLine(layer.attribution, license, url),
    );
  }
  if (credits.isEmpty) {
    return _creditLine(null, provinceLicense, provinceLicenseUrl);
  }
  return credits.values.join('\n');
}

/// The source's own wording wins where it gave us one. Several of these licences
/// specify the sentence to use, and a paraphrase of a specified statement is not
/// the specified statement.
String _creditLine(String? attribution, String license, String url) {
  final specified = attribution?.trim() ?? '';
  if (specified.isNotEmpty) return specified;
  return url.isEmpty ? '$license.' : '$license. $url';
}
