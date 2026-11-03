import '../controllers/multi_selection.dart';
import '../signals/locale.dart';
import 'share_bundle.dart';
import 'share_document.dart';
import 'share_routes.dart';
import 'share_targets.dart';

/// The location that shares [selection]'s targets ([kind]), or null after
/// reporting why it cannot.
///
/// A selection the sender cannot share whole leaves selection mode on and
/// reports why, so the user can drop a target; a shareable one leaves selection
/// and returns the location to open.
String? shareSelection({
  required ShareKind kind,
  required MultiSelection selection,
  required void Function(String message) showMessage,
}) {
  final ids = selection.orderedSelection;
  final unshareable = [
    for (final id in ids)
      if (resolveShareTarget(kind, id).reason != null) id,
  ].length;
  if (unshareable > 0) {
    showMessage(l10n.value.selectionUnavailable(unshareable));
    return null;
  }

  final target = resolveShareItems(kind, ids);
  if (target.reason != null || target.documents.isEmpty) {
    // Every target resolves on its own, so the failure is the bundle: too many
    // items, or a set the receiver's own validator would refuse.
    showMessage(
      ids.length > shareMaxBundleItems
          ? l10n.value.selectionTooMany(ids.length, shareMaxBundleItems)
          : l10n.value.selectionUnavailable(ids.length),
    );
    return null;
  }

  selection.exit();
  return shareSendPaths(kind, ids);
}
