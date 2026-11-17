import 'package:flutter_test/flutter_test.dart';
import 'package:gdrive/features/sync/reconciler.dart';

void main() {
  group('decide: never synced before', () {
    test('only on Drive -> download', () {
      expect(
        decide(local: false, remote: true, base: false),
        SyncDecision.download,
      );
    });

    test('only on disk -> upload as new', () {
      expect(
        decide(local: true, remote: false, base: false),
        SyncDecision.uploadNew,
      );
    });

    test('on both with the same content -> link', () {
      expect(
        decide(local: true, remote: true, base: false, sameContent: true),
        SyncDecision.link,
      );
    });

    test('on both with different content -> conflict', () {
      expect(
        decide(local: true, remote: true, base: false),
        SyncDecision.conflict,
      );
    });

    test('on neither -> nothing', () {
      expect(
        decide(local: false, remote: false, base: false),
        SyncDecision.none,
      );
    });
  });

  group('decide: synced before, present on both sides', () {
    SyncDecision both({
      bool localChanged = false,
      bool remoteChanged = false,
      bool sameContent = false,
      bool native = false,
    }) => decide(
      local: true,
      remote: true,
      base: true,
      localChanged: localChanged,
      remoteChanged: remoteChanged,
      sameContent: sameContent,
      native: native,
    );

    test('nothing changed -> nothing', () {
      expect(both(), SyncDecision.none);
    });

    test('local changed -> upload', () {
      expect(both(localChanged: true), SyncDecision.upload);
    });

    test('Drive changed -> download', () {
      expect(both(remoteChanged: true), SyncDecision.download);
    });

    test('both changed -> conflict', () {
      expect(
        both(localChanged: true, remoteChanged: true),
        SyncDecision.conflict,
      );
    });

    test('both changed to the same content -> link', () {
      expect(
        both(localChanged: true, remoteChanged: true, sameContent: true),
        SyncDecision.link,
      );
    });

    test('a locally edited Google Docs export is flagged, not uploaded', () {
      expect(
        both(localChanged: true, native: true),
        SyncDecision.markLocalEdited,
      );
    });

    test('a changed Google Doc is exported again', () {
      expect(both(remoteChanged: true, native: true), SyncDecision.download);
    });

    test('an edited export whose document also changed -> conflict', () {
      expect(
        both(localChanged: true, remoteChanged: true, native: true),
        SyncDecision.conflict,
      );
    });
  });

  group('decide: synced before, missing on one side', () {
    test('deleted on Drive, untouched locally -> delete local', () {
      expect(
        decide(local: true, remote: false, base: true),
        SyncDecision.deleteLocal,
      );
    });

    test('deleted on Drive, edited locally -> upload as new', () {
      expect(
        decide(local: true, remote: false, base: true, localChanged: true),
        SyncDecision.uploadNew,
      );
    });

    test('deleted locally, untouched on Drive -> trash on Drive', () {
      expect(
        decide(local: false, remote: true, base: true),
        SyncDecision.trashRemote,
      );
    });

    test('deleted locally, edited on Drive -> download', () {
      expect(
        decide(local: false, remote: true, base: true, remoteChanged: true),
        SyncDecision.download,
      );
    });

    test('gone on both sides -> forget', () {
      expect(
        decide(local: false, remote: false, base: true),
        SyncDecision.forget,
      );
    });
  });

  test('no input combination can lose the only copy of changed data', () {
    for (final local in [true, false]) {
      for (final remote in [true, false]) {
        for (final base in [true, false]) {
          for (final localChanged in [true, false]) {
            for (final remoteChanged in [true, false]) {
              for (final native in [true, false]) {
                final decision = decide(
                  local: local,
                  remote: remote,
                  base: base,
                  localChanged: localChanged,
                  remoteChanged: remoteChanged,
                  native: native,
                );
                final context =
                    'local=$local remote=$remote base=$base '
                    'localChanged=$localChanged remoteChanged=$remoteChanged '
                    'native=$native -> $decision';
                if (local && localChanged) {
                  expect(
                    decision,
                    isNot(
                      anyOf(SyncDecision.deleteLocal, SyncDecision.download),
                    ),
                    reason: context,
                  );
                }
                if (remote && remoteChanged) {
                  expect(
                    decision,
                    isNot(anyOf(SyncDecision.trashRemote, SyncDecision.upload)),
                    reason: context,
                  );
                }
                if (!base) {
                  expect(
                    decision,
                    isNot(
                      anyOf(SyncDecision.deleteLocal, SyncDecision.trashRemote),
                    ),
                    reason: context,
                  );
                }
              }
            }
          }
        }
      }
    }
  });

  group('needsDeleteConfirmation', () {
    test('small deletions go through', () {
      expect(needsDeleteConfirmation(deletions: 0, tracked: 0), isFalse);
      expect(needsDeleteConfirmation(deletions: 4, tracked: 4), isFalse);
      expect(needsDeleteConfirmation(deletions: 5, tracked: 100), isFalse);
      expect(needsDeleteConfirmation(deletions: 25, tracked: 1000), isFalse);
    });

    test('more than 25 files always asks', () {
      expect(needsDeleteConfirmation(deletions: 26, tracked: 100000), isTrue);
    });

    test('five or more that exceed a quarter of tracked files asks', () {
      expect(needsDeleteConfirmation(deletions: 5, tracked: 19), isTrue);
      expect(needsDeleteConfirmation(deletions: 5, tracked: 20), isFalse);
      expect(needsDeleteConfirmation(deletions: 6, tracked: 8), isTrue);
    });
  });
}
