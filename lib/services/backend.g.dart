// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'backend.dart';

// **************************************************************************
// ShelfRouterGenerator
// **************************************************************************

Router _$BackendServiceRouter(BackendService service) {
  final router = Router();
  router.add('GET', r'/api', service._apiGet);
  router.add('POST', r'/error', service._apiError);
  router.add('POST', r'/api', service._apiPost);
  router.add('POST', r'/robotState', service._apiRobotState);
  return router;
}
