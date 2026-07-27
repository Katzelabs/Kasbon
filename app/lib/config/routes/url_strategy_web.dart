import 'package:flutter_web_plugins/url_strategy.dart';

/// Switches the browser off go_router's default hash URLs.
///
/// Without this, a product detail page is `example.com/#/products/abc`. The
/// fragment is never sent to the server, which makes the URL useless for
/// anything but the running app - and RESP_07's whole premise is that a
/// master-detail URL can be copied, shared and reopened.
///
/// **Deployment requirement.** Real paths mean the server receives
/// `GET /products/abc` for a route only the client knows about. The host must
/// rewrite unknown paths to `index.html`, or a hard refresh on any route
/// except `/` returns a 404.
void configureUrlStrategy() {
  usePathUrlStrategy();
}
