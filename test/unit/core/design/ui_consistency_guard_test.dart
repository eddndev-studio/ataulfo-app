import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _source(String path) => File(path).readAsStringSync();

void main() {
  group('guard de congruencia UI', () {
    test('las selecciones genéricas usan los primitivos del kit', () {
      const forbidden = <String, List<String>>{
        'lib/features/wa_labels/presentation/widgets/wa_chat_labels_section.dart':
            <String>['Icons.check_box', 'Icons.check_box_outline_blank'],
        'lib/core/ai/tool_groups_sheet.dart': <String>[
          'Icons.check_box',
          'Icons.check_box_outline_blank',
        ],
        'lib/features/templates/presentation/widgets/silence_labels_sheet.dart':
            <String>['Icons.check_box', 'Icons.check_box_outline_blank'],
        'lib/features/labels/presentation/widgets/label_picker.dart': <String>[
          'Icons.check,',
        ],
        'lib/features/media/presentation/widgets/media_thumbnail.dart':
            <String>['Icons.check_circle'],
      };

      for (final MapEntry(key: path, value: patterns) in forbidden.entries) {
        final source = _source(path);
        for (final pattern in patterns) {
          expect(source, isNot(contains(pattern)), reason: '$path: $pattern');
        }
      }
    });

    test('las features no montan controles Material paralelos al kit', () {
      final files = Directory('lib/features')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));
      final rawControl = RegExp(
        r'\b(?:ListTile|CheckboxListTile|RadioListTile|TextButton|FilledButton|InputChip)\s*(?:<[^>]+>)?\s*\(',
      );

      for (final file in files) {
        expect(
          rawControl.hasMatch(file.readAsStringSync()),
          isFalse,
          reason: file.path,
        );
      }
    });

    test('la microtipografía no baja de la caption canónica', () {
      final files = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));
      final tooSmall = RegExp(r'fontSize:\s*(?:9|11),');

      for (final file in files) {
        expect(
          tooSmall.hasMatch(file.readAsStringSync()),
          isFalse,
          reason: file.path,
        );
      }
    });

    test('los headers de detalle delegan en AppDetailHeader', () {
      for (final path in <String>[
        'lib/features/templates/presentation/widgets/template_detail_header.dart',
        'lib/features/bots/presentation/widgets/bot_detail_header.dart',
      ]) {
        final source = _source(path);
        expect(source, contains('AppDetailHeader('), reason: path);
        expect(source, isNot(contains('ClipRRect(')), reason: path);
      }
    });

    test('los estados de página usan AppLoadingIndicator', () {
      const paths = <String>[
        'lib/features/wa_labels/presentation/pages/wa_labels_page.dart',
        'lib/features/wa_labels/presentation/pages/wa_label_mapping_page.dart',
        'lib/features/members/presentation/pages/members_page.dart',
        'lib/features/members/presentation/pages/bot_assignment_page.dart',
        'lib/features/ai_log/presentation/pages/ai_log_page.dart',
        'lib/features/templates/presentation/pages/template_flows_page.dart',
        'lib/features/templates/presentation/pages/template_detail_page.dart',
        'lib/features/invitations/presentation/pages/invitations_page.dart',
        'lib/features/ai_ledger/presentation/pages/ai_ledger_page.dart',
        'lib/features/trainer/presentation/pages/workspace_page.dart',
        'lib/features/bots/presentation/pages/bot_variables_page.dart',
        'lib/features/bots/presentation/pages/bot_maintenance_page.dart',
        'lib/features/bots/presentation/pages/bot_detail_page.dart',
        'lib/features/memberships/presentation/pages/select_org_page.dart',
        'lib/features/memberships/presentation/pages/memberships_page.dart',
        'lib/features/bots/presentation/pages/bot_connect_page.dart',
        'lib/features/profile/presentation/pages/profile_page.dart',
        'lib/features/splash/presentation/pages/splash_page.dart',
        'lib/features/splash/presentation/pages/reconnecting_view.dart',
        'lib/features/org_customization/presentation/pages/org_customization_page.dart',
        'lib/features/billing/presentation/pages/cuenta_page.dart',
        'lib/features/auth/presentation/pages/accept_invite_page.dart',
        'lib/features/notifications/presentation/pages/notification_preferences_page.dart',
      ];

      for (final path in paths) {
        final source = _source(path);
        expect(source, contains('AppLoadingIndicator'), reason: path);
        expect(
          source,
          isNot(contains('CircularProgressIndicator(')),
          reason: path,
        );
      }
    });

    test('radios de producto reutilizan tokens', () {
      const paths = <String>[
        'lib/features/stickers/presentation/pages/stickers_page.dart',
        'lib/features/stickers/presentation/pages/sticker_picker_page.dart',
        'lib/features/public_catalog/presentation/appearance/appearance_section.dart',
      ];
      for (final path in paths) {
        expect(
          _source(path),
          isNot(contains('BorderRadius.circular(12)')),
          reason: path,
        );
      }
    });
  });
}
