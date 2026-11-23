import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meterread/features/auth/presentation/sign_in_screen.dart';
import 'package:meterread/features/round/presentation/meter_screen.dart';
import 'package:meterread/features/round/presentation/round_screen.dart';

part 'routes.g.dart';

/// While the app checks the stored session: /.
@TypedGoRoute<SplashRoute>(path: '/')
class SplashRoute extends GoRouteData with $SplashRoute {
  /// Creates the route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

/// /sign-in.
@TypedGoRoute<SignInRoute>(path: '/sign-in')
class SignInRoute extends GoRouteData with $SignInRoute {
  /// Creates the route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const SignInScreen();
}

/// Today's round: /round.
@TypedGoRoute<RoundRoute>(
  path: '/round',
  routes: [TypedGoRoute<MeterRoute>(path: 'meters/:meterId')],
)
class RoundRoute extends GoRouteData with $RoundRoute {
  /// Creates the route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const RoundScreen();
}

/// One meter: /round/meters/:meterId.
class MeterRoute extends GoRouteData with $MeterRoute {
  /// Creates the route for [meterId].
  const new({required this.meterId});

  /// `M-1001`.
  final String meterId;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      MeterScreen(meterId: meterId);
}
