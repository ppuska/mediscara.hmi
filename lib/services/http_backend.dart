import 'dart:developer';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

part 'http_backend.g.dart';

class BackendService {
  @Route.get('/api')
  Future<Response> _apiGet(Request request) async {
    return Response.ok("OK");
  }

  @Route.post('/api')
  Future<Response> _apiPost(Request request) async {
    log("Got incoming http post ${request.read()}");
    return Response.ok("OK");
  }

  Router get router => _$BackendServiceRouter(this);
}
