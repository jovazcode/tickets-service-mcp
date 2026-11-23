import 'dart:io';

/// Ejecuta [action] con un bloqueo exclusivo entre procesos sobre el fichero
/// [lockPath], que se crea si no existe y nunca se borra.
///
/// Si otro proceso tiene el bloqueo, espera sin bloquear el isolate a que lo
/// suelte. El bloqueo es consultivo (`fcntl` en POSIX): solo protege frente a
/// procesos que también lo pidan. Dentro de un mismo proceso no excluye nada,
/// así que las llamadas concurrentes de un proceso deben ir en cola aparte.
///
/// Lanza [FileSystemException] si no se puede abrir o bloquear el fichero.
Future<T> withFileLock<T>(String lockPath, Future<T> Function() action) async {
  final file = File(lockPath);
  await file.parent.create(recursive: true);
  final handle = await file.open(mode: FileMode.append);
  try {
    await handle.lock(FileLock.blockingExclusive);
    return await action();
  } finally {
    // Cerrar el fichero suelta el bloqueo.
    await handle.close();
  }
}
