// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'http_backend.dart';

// **************************************************************************
// ShelfRouterGenerator
// **************************************************************************

Router _$BackendServiceRouter(BackendService service) {
  final router = Router();
  router.add('GET', r'/api', service._apiGet);
  router.add('POST', r'/api', service._apiPost);
  return router;
}
