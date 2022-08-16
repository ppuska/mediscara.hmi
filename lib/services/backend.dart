import 'dart:async';
import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../errors.dart';

part 'backend.g.dart';

class BackendService {
  static final BackendService _instance = BackendService._init();

  Completer _completer = Completer();

  BackendService._init();

  factory BackendService() => _instance;

  List<Error> errors = [];
  final List<void Function(Error error)> _errorCallbacks = [];

  void registerErrorCallback(void Function(Error error) callback) {
    _errorCallbacks.add(callback);
  }

  void unregisterErrorCallback(void Function(Error error) callback) {
    _errorCallbacks.remove(callback);
  }

  Future<dynamic> get incomingRequest {
    // reinitialize the completer if it is completed
    if (_completer.isCompleted) _completer = Completer();
    return _completer.future;
  }

  @Route.get('/api')
  Future<Response> _apiGet(Request request) async {
    return Response.ok("OK");
  }

  @Route.post('/error')
  Future<Response> _apiError(Request request) async {
    final requestBody = jsonDecode(await request.readAsString());

    /// Response syntax:
    /// {
    ///   subscriptionId: ...,
    ///   data: [
    ///     {
    ///       id: ...,
    ///       ...
    ///       error: ...
    ///     }
    ///   ]
    /// }

    String? errorMessage = requestBody['data'][0]['error'];
    String? id = requestBody['data'][0]['id'];

    var error = Error(
      id: 'internal',
      message: 'Invalid error subscription payload',
    );

    if (!(errorMessage == null || id == null)) {
      error = Error(id: id, message: errorMessage);
    }

    // add the new error to the error list
    errors.add(error);

    // call the error callbacks
    for (var element in _errorCallbacks) {
      element(error);
    }

    return Response.ok("OK");
  }

  @Route.post('/api')
  Future<Response> _apiPost(Request request) async {
    final requestBody = jsonDecode(await request.readAsString());

    final error = requestBody['data'][0]['error'];

    if (error != '') {
      // log("New error: $error");
    }

    if (!_completer.isCompleted) _completer.complete(requestBody);

    return Response.ok("OK");
  }

  Router get router => _$BackendServiceRouter(this);
}
