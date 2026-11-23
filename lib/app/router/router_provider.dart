import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:meterread/app/router/routes.dart';
import 'package:meterread/features/auth/domain/reader.dart';
import 'package:meterread/features/auth/presentation/auth_controller.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'router_provider.g.dart';

/// The app's one router. Signed out goes to sign-in, and back to the
/// address it came from once signed in.
@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  final auth = ValueNotifier<AuthState>(ref.read(authControllerProvider));
  ref
    ..listen(authControllerProvider, (_, next) => auth.value = next)
    ..onDispose(auth.dispose);

  final router = GoRouter(
    initialLocation: const RoundRoute().location,
    routes: $appRoutes,
    refreshListenable: auth,
    redirect: (context, state) {
      final here = state.uri;
      final from = here.queryParameters['from'];
      final atSplash = here.path == const SplashRoute().location;
      final atSignIn = here.path == const SignInRoute().location;
      String away(String path) => Uri(
        path: path,
        queryParameters: {'from': from ?? here.toString()},
      ).toString();

      return switch (auth.value) {
        Restoring() => atSplash ? null : away('/'),
        SignedOut() => atSignIn ? null : away('/sign-in'),
        SignedIn() when atSplash || atSignIn =>
          from ?? const RoundRoute().location,
        SignedIn() => null,
      };
    },
  );
  ref.onDispose(router.dispose);
  return router;
}
