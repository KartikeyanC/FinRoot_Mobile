import 'dart:convert';

import 'package:finroot_mobile/features/backup/drive_backup.dart';
import 'package:finroot_mobile/features/backup/drive_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('driveSignInProblem: Google\'s reason, turned into what to do', () {
    test('DEVELOPER_ERROR: the Android OAuth client / SHA-1 is missing', () {
      final m = driveSignInProblem(
        'unknownError',
        'SDK reported an exception: 10: Developer console is not set up '
            'correctly.',
      );
      expect(m, contains('com.finroot.mobile'));
      expect(m, contains(driveSigningSha1));
    });

    test('an account that is not a test user', () {
      expect(
        driveSignInProblem(
          'unknownError',
          'Authorization failed: access_denied',
        ),
        contains('test user'),
      );
    });

    test('no network', () {
      expect(
        driveSignInProblem('unknownError', 'SDK reported an exception: 7: '),
        contains('connection'),
      );
    });

    test('anything else keeps Google\'s own words', () {
      expect(
        driveSignInProblem('uiUnavailable', 'No activity'),
        'Google sign-in failed (uiUnavailable: No activity).',
      );
      expect(
        driveSignInProblem('unknownError', null),
        'Google sign-in failed (unknownError).',
      );
    });
  });

  group('driveErrorMessage', () {
    String body(String message) => jsonEncode({
      'error': {'code': 403, 'message': message},
    });

    test(
      'Drive API switched off in the Cloud project says how to enable it',
      () {
        final m = driveErrorMessage(
          403,
          body(
            'Google Drive API has not been used in project 1234 before or it '
            'is disabled.',
          ),
        );
        expect(m, contains('Google Drive API → Enable'));
      },
    );

    test('expired sign-in', () {
      expect(
        driveErrorMessage(401, '{}'),
        'Google sign-in expired. Try again.',
      );
    });

    test('other refusals keep Google\'s message, or the status', () {
      expect(
        driveErrorMessage(403, body('The user has exceeded their quota.')),
        'Google Drive: The user has exceeded their quota.',
      );
      expect(driveErrorMessage(500, 'oops'), 'Google Drive said 500.');
    });
  });
}
