import 'package:ataulfo/features/bots/domain/entities/bot.dart';
import 'package:ataulfo/features/bots/domain/repositories/bots_repository.dart';
import 'package:ataulfo/features/takeover/data/repo_silence_labels_resolver.dart';
import 'package:ataulfo/features/templates/domain/entities/template.dart';
import 'package:ataulfo/features/templates/domain/repositories/templates_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBots extends Mock implements BotsRepository {}

class _MockTemplates extends Mock implements TemplatesRepository {}

class _MockBot extends Mock implements Bot {}

class _MockTemplate extends Mock implements Template {}

class _MockAi extends Mock implements AIConfig {}

void main() {
  test('forBot resuelve bot→plantilla→silenceLabelIds', () async {
    final bots = _MockBots();
    final templates = _MockTemplates();
    final bot = _MockBot();
    final tpl = _MockTemplate();
    final ai = _MockAi();

    when(() => bot.templateId).thenReturn('t1');
    when(() => ai.silenceLabelIds).thenReturn(<String>['s1', 's2']);
    when(() => tpl.ai).thenReturn(ai);
    when(() => bots.byId('b1')).thenAnswer((_) async => bot);
    when(() => templates.byId('t1')).thenAnswer((_) async => tpl);

    final resolver = RepoSilenceLabelsResolver(
      bots: bots,
      templates: templates,
    );
    expect(await resolver.forBot('b1'), <String>['s1', 's2']);
    verify(() => templates.byId('t1')).called(1);
  });
}
