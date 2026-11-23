import 'package:mcp_dart/mcp_dart.dart';

/// {@template confirmation}
/// Resultado de pedir una confirmación al usuario con [askUser].
/// {@endtemplate}
sealed class Confirmation {
  /// {@macro confirmation}
  const new();
}

/// MCP 2026-07-28: hay que devolver [result] para que el cliente pregunte al
/// usuario y repita la llamada con su respuesta en `inputResponses`.
final class ConfirmationPending extends Confirmation {
  /// Pregunta pendiente, lista para devolverla como resultado.
  const new(this.result);

  /// Resultado `input_required` con la pregunta embebida.
  final InputRequiredResult result;
}

/// El usuario ha respondido con [answer] (aceptar, rechazar o cancelar).
final class ConfirmationAnswered extends Confirmation {
  /// Respuesta del usuario.
  const new(this.answer);

  /// Respuesta del usuario.
  final ElicitResult answer;
}

/// El cliente no admite formularios de elicitación: no se puede preguntar.
final class ConfirmationUnsupported extends Confirmation {
  /// No se puede preguntar al usuario.
  const new();
}

/// Pregunta [request] al usuario a través del cliente, con el mecanismo de
/// elicitación de cada versión del protocolo:
///
/// * MCP 2026-07-28 (sin estado): la primera vez devuelve
///   [ConfirmationPending]; cuando el cliente reintenta con la respuesta en
///   `inputResponses[key]`, devuelve [ConfirmationAnswered].
/// * MCP 2025-11-25 (sesión): envía `elicitation/create` al cliente, espera
///   su respuesta y devuelve [ConfirmationAnswered].
///
/// Si el cliente no ha declarado la capacidad `elicitation` con modo
/// formulario, devuelve [ConfirmationUnsupported]: la especificación prohíbe
/// enviarle la pregunta.
Future<Confirmation> askUser(
  McpServer server,
  RequestHandlerExtra extra, {
  required String key,
  required ElicitRequest request,
}) async {
  final protocolVersion = extra.protocolVersion;
  if (protocolVersion != null && isStatelessProtocolVersion(protocolVersion)) {
    if (!(extra.clientCapabilities?.elicitation?.supportsForm ?? false)) {
      return const ConfirmationUnsupported();
    }
    final response = extra.inputResponses?[key];
    if (response == null) {
      return ConfirmationPending(
        InputRequiredResult(inputRequests: {key: InputRequest.elicit(request)}),
      );
    }
    return ConfirmationAnswered(ElicitResult.fromJson(response.value));
  }
  final capabilities = server.server.getClientCapabilities();
  if (!(capabilities?.elicitation?.supportsForm ?? false)) {
    return const ConfirmationUnsupported();
  }
  return ConfirmationAnswered(await server.server.elicitInput(request));
}
