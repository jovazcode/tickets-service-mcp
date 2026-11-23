import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:tickets_service_mcp/src/store/file_lock.dart';

/// Programa que intenta tomar el bloqueo sin esperar e imprime si estaba
/// libre u ocupado.
const _probe = '''
import 'dart:io';

void main(List<String> args) {
  final handle = File(args.single).openSync(mode: FileMode.append);
  try {
    handle.lockSync(FileLock.exclusive);
    stdout.write('libre');
  } on FileSystemException {
    stdout.write('ocupado');
  }
}
''';

void main() {
  late Directory tempDir;
  late String lockPath;
  late String probePath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('file_lock_test');
    lockPath = p.join(tempDir.path, 'sub', 'store.lock');
    probePath = p.join(tempDir.path, 'probe.dart');
    await File(probePath).writeAsString(_probe);
  });

  tearDown(() => tempDir.delete(recursive: true));

  /// Pregunta a otro proceso si el bloqueo está libre.
  Future<String> probe() async {
    final result = await Process.run(Platform.resolvedExecutable, [
      'run',
      probePath,
      lockPath,
    ]);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    return result.stdout as String;
  }

  test('excluye a otros procesos mientras dura la acción', () async {
    final during = await withFileLock(lockPath, probe);
    expect(during, 'ocupado');
    expect(await probe(), 'libre');
    expect(File(lockPath).existsSync(), isTrue);
  });

  test('suelta el bloqueo aunque la acción falle', () async {
    await expectLater(
      withFileLock<void>(lockPath, () async => throw StateError('fallo')),
      throwsStateError,
    );
    expect(await probe(), 'libre');
  });

  test('falla si no se puede crear el fichero de bloqueo', () async {
    final blocker = File(p.join(tempDir.path, 'bloqueo'));
    await blocker.writeAsString('');
    expect(
      withFileLock(p.join(blocker.path, 'store.lock'), () async {}),
      throwsA(isA<FileSystemException>()),
    );
  });
}
