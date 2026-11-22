import 'dart:io';

import 'package:test/test.dart';

import '../../helpers/harness.dart';

void main() {
  setUpAll(silenceMcpLogs);

  late Harness harness;

  setUp(() async => harness = await Harness.start());
  tearDown(() => harness.stop());

  test('se anuncia con su argumento opcional', () async {
    final prompt = (await harness.client.listPrompts()).prompts.single;
    expect(prompt.name, 'abrir_incidencia');
    expect(prompt.arguments?.single.name, 'problema');
    expect(prompt.arguments?.single.required, isNot(true));
  });

  test('incrusta el proceso de apertura e incluye el problema', () async {
    final result = await harness.client.getPrompt(
      const GetPromptRequest(
        name: 'abrir_incidencia',
        arguments: {'problema': 'No funciona la impresora'},
      ),
    );
    final embedded = result.messages.first.content as EmbeddedResource;
    final document = embedded.resource as TextResourceContents;
    expect(document.uri, 'docs://proceso_apertura');
    expect(document.text, File('docs/proceso_apertura.md').readAsStringSync());

    final text = (result.messages.last.content as TextContent).text;
    expect(text, contains('Problema: No funciona la impresora'));
    expect(text, contains('buscar_duplicadas'));
    expect(text, contains('crear_incidencia'));
  });

  test('sin problema pide que se le pregunte', () async {
    final result = await harness.client.getPrompt(
      const GetPromptRequest(name: 'abrir_incidencia'),
    );
    final text = (result.messages.last.content as TextContent).text;
    expect(text, contains('Pregúntame primero'));
  });
}
