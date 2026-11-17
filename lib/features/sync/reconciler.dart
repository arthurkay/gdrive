/// What to do with one file so both sides agree again.
enum SyncDecision {
  /// Already in agreement.
  none,

  /// Fetch the Drive version over the local one.
  download,

  /// Send the local version as a new revision of the Drive file.
  upload,

  /// Send the local file as a brand-new Drive file.
  uploadNew,

  /// Both sides hold identical content; just record that.
  link,

  /// Both sides changed. Keep the local version under a "conflicted copy"
  /// name and fetch the Drive version.
  conflict,

  /// Drive no longer has the file; move the local copy to the recycle folder.
  deleteLocal,

  /// The local copy was deleted; move the Drive file to Drive's trash.
  trashRemote,

  /// Gone on both sides; drop the record.
  forget,

  /// A Google Docs export was edited locally. Exports are download-only, so
  /// the edit is flagged and left in place.
  markLocalEdited,
}

/// The three-way merge rule for a single file.
///
/// [local] and [remote] say whether the file exists on each side now;
/// [base] whether it was in sync at some point before. [localChanged] and
/// [remoteChanged] compare each side with that earlier state and only matter
/// when [base] is true. [sameContent] says both sides currently hold
/// identical bytes. [native] marks Google Docs/Sheets/Slides exports.
SyncDecision decide({
  required bool local,
  required bool remote,
  required bool base,
  bool localChanged = false,
  bool remoteChanged = false,
  bool sameContent = false,
  bool native = false,
}) {
  if (!base) {
    if (local && remote) {
      return sameContent ? SyncDecision.link : SyncDecision.conflict;
    }
    if (local) return SyncDecision.uploadNew;
    if (remote) return SyncDecision.download;
    return SyncDecision.none;
  }
  if (local && remote) {
    if (localChanged && remoteChanged) {
      return sameContent ? SyncDecision.link : SyncDecision.conflict;
    }
    if (localChanged) {
      return native ? SyncDecision.markLocalEdited : SyncDecision.upload;
    }
    return remoteChanged ? SyncDecision.download : SyncDecision.none;
  }
  if (local) {
    // Deleted on Drive. An edited local copy is kept by sending it back up.
    return localChanged ? SyncDecision.uploadNew : SyncDecision.deleteLocal;
  }
  if (remote) {
    // Deleted locally. A Drive copy edited since is kept by fetching it.
    return remoteChanged ? SyncDecision.download : SyncDecision.trashRemote;
  }
  return SyncDecision.forget;
}

/// Whether a pass with [deletions] out of [tracked] synced files should stop
/// and ask first. Guards against a wiped or unmounted folder emptying Drive.
bool needsDeleteConfirmation({required int deletions, required int tracked}) =>
    deletions > 25 || (deletions >= 5 && deletions > tracked * 0.25);
