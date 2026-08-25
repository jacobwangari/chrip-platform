import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/constants/app_constants.dart';
import '../domain/notification_model.dart';

/// Wraps the raw WebSocketChannel so the rest of the app deals in
/// NotificationModel objects and a simple connect/disconnect API,
/// never in raw JSON or channel plumbing.
class NotificationSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

  bool get isConnected => _channel != null;

  /// Builds ws://<host>/ws/notifications/?token=<access> from the same
  /// API_BASE_URL used for REST calls — http(s) -> ws(s), and the
  /// /api path suffix is replaced with the WebSocket route.
  String _buildSocketUrl(String accessToken) {
    final apiBaseUrl =
        dotenv.env[AppConstants.apiBaseUrlEnvKey] ?? AppConstants.defaultApiBaseUrl;

    final httpUri = Uri.parse(apiBaseUrl);
    final wsScheme = httpUri.scheme == 'https' ? 'wss' : 'ws';

    final wsUri = Uri(
      scheme: wsScheme,
      host: httpUri.host,
      port: httpUri.port,
      path: '/ws/notifications/',
      queryParameters: {'token': accessToken},
    );

    return wsUri.toString();
  }

  /// Connects and starts listening. [onNotification] is called once
  /// per pushed notification; [onError]/[onDone] let the caller react
  /// to a dropped connection (e.g. to attempt a reconnect).
  void connect({
    required String accessToken,
    required void Function(NotificationModel) onNotification,
    void Function()? onError,
    void Function()? onDone,
  }) {
    disconnect(); // ensure no duplicate connection if called twice

    final url = _buildSocketUrl(accessToken);
    _channel = WebSocketChannel.connect(Uri.parse(url));

    _subscription = _channel!.stream.listen(
      (raw) {
        try {
          final json = jsonDecode(raw as String) as Map<String, dynamic>;
          onNotification(NotificationModel.fromJson(json));
        } catch (_) {
          // Malformed payload — ignore rather than crash the socket
          // listener over one bad message.
        }
      },
      onError: (_) {
        _channel = null;
        onError?.call();
      },
      onDone: () {
        _channel = null;
        onDone?.call();
      },
    );
  }

  void disconnect() {
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    _subscription = null;
  }
}