/// Crash reporting for KASBON.
///
/// A crash on a warung's phone in Surabaya is otherwise invisible: nobody files
/// a bug report, they just stop using the till. This is the only channel that
/// makes such a failure visible at all.
///
/// Two things about the design are load-bearing:
///
/// **An absent DSN is a supported configuration, not an error.** `flutter test`,
/// CI and every local `flutter run` have no DSN and must neither report nor
/// fail. That is the opposite of the Supabase keys, where an empty value throws
/// at startup — a build with no database is broken, a build with no crash
/// reporting merely has none.
///
/// **Everything is scrubbed on the way out, by name.** See `PiiScrubber`. The
/// hooks are set here in one place rather than at call sites, so a future
/// `Sentry.captureException` cannot bypass them.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../config/app_config.dart';
import 'pii_scrubber.dart';

/// Runs [appRunner] with crash reporting installed, if it is configured.
///
/// Replaces a bare `runApp`. Sentry needs to own the zone that `runApp` runs
/// in — that is how an uncaught async error is attributed to the right frame —
/// so the app has to start *inside* this rather than alongside it.
Future<void> runWithCrashReporting(AppRunner appRunner) async {
  if (!AppConfig.isCrashReportingEnabled) {
    _installFallbackErrorHandlers();
    await appRunner();
    return;
  }

  await SentryFlutter.init(
    configureCrashReportingOptions,
    appRunner: appRunner,
  );
}

/// Applies KASBON's Sentry configuration.
///
/// Split out from [runWithCrashReporting] so a test can assert what the options
/// end up as without standing up the SDK.
@visibleForTesting
void configureCrashReportingOptions(SentryFlutterOptions options) {
  options.dsn = AppConfig.sentryDsn;
  options.environment = AppConfig.sentryEnvironment;

  // Sentry's own logging. On in debug only, or a misconfigured DSN fails
  // silently in exactly the build where nobody is watching the console.
  options.debug = kDebugMode;

  // Never attach the data Sentry classifies as PII (IP address, username,
  // cookies). The default is already false; it is set explicitly because
  // turning it on looks harmless and is not.
  options.sendDefaultPii = false;

  // A POS screenshot is the cart: what this customer bought, what it cost, and
  // frequently their name on the debt sheet. The view hierarchy is nearly as
  // bad — it carries widget text. Both default to false and both must stay
  // that way; this is the note for whoever finds the option and thinks it
  // would help.
  options.attachScreenshot = false;
  options.attachViewHierarchy = false;

  // Performance monitoring off. It is a separate quota, it samples every
  // navigation rather than the rare crash, and nothing here needs it yet.
  options.tracesSampleRate = 0.0;

  options.beforeSend = scrubEvent;
  options.beforeBreadcrumb = scrubBreadcrumb;
}

/// Removes customer and money data from an event before it is sent.
///
/// Every field that can carry a value is covered: the exception message (a
/// PostgREST error quotes the row it choked on), the request URL and query
/// string, breadcrumbs, extra, and the user.
///
/// **Throwing here would leak.** `SentryClient._runBeforeSend` seeds its result
/// with the *original* event and, on an exception, only logs — leaving the
/// unscrubbed event to be sent. So the redactor fails open unless it is made
/// not to, which is what the catch-all is for: a dropped crash report costs a
/// bug that takes longer to find, a leaked one costs a customer's name.
@visibleForTesting
SentryEvent? scrubEvent(SentryEvent event, Hint hint) {
  try {
    return event.copyWith(
      message: _scrubMessage(event.message),
      exceptions: event.exceptions?.map(_scrubException).toList(),
      breadcrumbs: event.breadcrumbs
          ?.map((crumb) => scrubBreadcrumb(crumb, hint))
          .whereType<Breadcrumb>()
          .toList(),
      request: _scrubRequest(event.request),
      user: _scrubUser(event.user),
      // ignore: deprecated_member_use
      extra: event.extra == null ? null : PiiScrubber.scrubMap(event.extra!),
    );
  } catch (_) {
    return null;
  }
}

/// Removes customer and money data from a breadcrumb.
///
/// Breadcrumbs leak more than exceptions do, and more quietly: there is one per
/// navigation and per HTTP call, each carrying the URL that produced it, and
/// they ride along on *every* subsequent event rather than only the one that
/// failed.
@visibleForTesting
Breadcrumb? scrubBreadcrumb(Breadcrumb? breadcrumb, Hint hint) {
  if (breadcrumb == null) {
    return null;
  }
  return breadcrumb.copyWith(
    message: breadcrumb.message == null
        ? null
        : PiiScrubber.scrubText(breadcrumb.message!),
    data: breadcrumb.data == null
        ? null
        : PiiScrubber.scrubMap(breadcrumb.data!),
  );
}

/// Identifies the signed-in shop by its Supabase uid, and nothing else.
///
/// A uid is a random UUID: it groups a shop's crashes together without saying
/// who they are. Pass `null` on sign-out, or the next account's reports inherit
/// the previous one's identity.
///
/// [scrubEvent] strips any user down to its id regardless, so forgetting to
/// call this loses grouping but never leaks — which is the right way round.
Future<void> setCrashReportingUser(String? userId) async {
  if (!AppConfig.isCrashReportingEnabled) {
    return;
  }
  await Sentry.configureScope(
    (scope) => scope.setUser(userId == null ? null : SentryUser(id: userId)),
  );
}

SentryMessage? _scrubMessage(SentryMessage? message) {
  if (message == null) {
    return null;
  }
  return SentryMessage(
    PiiScrubber.scrubText(message.formatted),
    template: message.template,
    // Params are the values interpolated into the template — exactly the
    // things worth hiding.
    params: message.params?.map(PiiScrubber.scrubValue).toList(),
  );
}

SentryException _scrubException(SentryException exception) {
  return exception.copyWith(
    value:
        exception.value == null ? null : PiiScrubber.scrubText(exception.value!),
  );
}

SentryRequest? _scrubRequest(SentryRequest? request) {
  if (request == null) {
    return null;
  }
  return request.copyWith(
    url: request.url == null ? null : PiiScrubber.scrubUrl(request.url!),
    // These three have no salvageable half the way a URL's path does: a query
    // string is entirely filters, and cookies and a fragment are entirely
    // opaque. Replaced rather than dropped so the report still says they were
    // present.
    queryString: request.queryString == null ? null : PiiScrubber.redacted,
    cookies: request.cookies == null ? null : PiiScrubber.redacted,
    fragment: request.fragment == null ? null : PiiScrubber.redacted,
    headers: request.headers.isEmpty
        ? null
        : PiiScrubber.scrubMap(request.headers)
            .map((key, value) => MapEntry(key, value.toString())),
    data: request.data == null ? null : PiiScrubber.scrubValue(request.data),
  );
}

SentryUser? _scrubUser(SentryUser? user) {
  if (user == null) {
    return null;
  }
  // Two traps here, both of which fail toward sending the real user.
  //
  // This must always hand back a *replacement*, never null to mean "remove":
  // `copyWith` reads null as "unchanged", so returning null would keep the
  // original — email, username, IP and all.
  //
  // And it cannot pass a null id through, because `SentryUser` asserts that at
  // least one of id/username/email/ip/segment is set. That assertion would
  // throw, and a throw inside `beforeSend` sends the event unscrubbed. A user
  // with no id gets the marker instead: still says a user was present, says
  // nothing about who.
  return SentryUser(id: user.id ?? PiiScrubber.redacted);
}

/// Keeps framework errors visible when there is no DSN.
///
/// Without a DSN nothing installs these, and a Flutter error would go nowhere
/// at all. Only used on the disabled path — when Sentry is on, its own
/// integrations own these hooks and overwriting them would silently stop
/// reporting.
void _installFallbackErrorHandlers() {
  FlutterError.onError = FlutterError.presentError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FlutterError.reportError(
      FlutterErrorDetails(exception: error, stack: stack),
    );
    return true;
  };
}
