import 'dart:async';
import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

part 'backend.g.dart';

class BackendService {
  static final BackendService _instance = BackendService._init();

  Completer _completer = Completer();

  BackendService._init();

  factory BackendService() => _instance;

  Future<dynamic> get incomingRequest {
    // reinitialize the completer if it is completed
    if (_completer.isCompleted) _completer = Completer();
    return _completer.future;
  }

  @Route.get('/api')
  Future<Response> _apiGet(Request request) async {
    return Response.ok("OK");
  }

  @Route.post('/api')
  Future<Response> _apiPost(Request request) async {
    final requestBody = jsonDecode(await request.readAsString());

    if (!_completer.isCompleted) _completer.complete(requestBody);

    return Response.ok("OK");
  }

  Router get router => _$BackendServiceRouter(this);
}
