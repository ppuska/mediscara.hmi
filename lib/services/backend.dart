import 'dart:async';
import 'dart:convert';
import 'dart:developer';

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
  final List<void Function(Map<String, dynamic> requestBody)>
      _robotStateCallbacks = [];

  /// Registers a callback that fires when a POST request
  /// lands at the /error endpoint
  void registerErrorCallback(void Function(Error error) callback) {
    _errorCallbacks.add(callback);
  }

  /// Unregisters a registered error callback
  void unregisterErrorCallback(void Function(Error error) callback) {
    _errorCallbacks.remove(callback);
  }

  /// Registers a callback that fires when a POST request
  /// lands at the /robotState endpoint
  void registerRSCallback(
    void Function(Map<String, dynamic> requestBody) callback,
  ) {
    _robotStateCallbacks.add(callback);
  }

  /// Unregisters a registered robotState callback
  void unregisterRSCallback(
    void Function(Map<String, dynamic> requestBody) callback,
  ) {
    _robotStateCallbacks.add(callback);
  }

  /// returns the next request incoming to the /api endpoint
  Future<dynamic> get incomingRequest {
    // reinitialize the completer if it is completed
    if (_completer.isCompleted) _completer = Completer();
    return _completer.future;
  }

  @Route.get('/api')
  Future<Response> _apiGet(Request request) async {
    return Response.ok("OK");
  }

  @Route.post('/robotState')
  Future<Response> _apiRobotState(Request request) async {
    final requestBody = jsonDecode(await request.readAsString());

    /// Response syntax (keyValues):
    /// {
    ///   subscriptionId: ...,
    ///   data: [
    ///     {
    ///       id: ...,
    ///       ...
    ///       robotRunning: ...
    ///     }
    ///   ]
    /// }

    final state = requestBody['data'][0];

    for (var callback in _robotStateCallbacks) {
      callback(state);
    }

    return Response.ok("OK");
  }

  @Route.post('/error')
  Future<Response> _apiError(Request request) async {
    final requestBody = jsonDecode(await request.readAsString());

    /// Response syntax (keyValues):
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

    log("New api post ${requestBody.toString()}");

    for (var callback in _robotStateCallbacks) {
      callback(requestBody);
    }

    if (!_completer.isCompleted) _completer.complete(requestBody);

    return Response.ok("OK");
  }

  Router get router => _$BackendServiceRouter(this);
}
