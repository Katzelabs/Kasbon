// Removes the cold-start splash in index.html once Flutter has painted.
//
// This lives in its own file rather than inline in index.html so that the
// Content-Security-Policy can say `script-src 'self'` without also saying
// 'unsafe-inline'. An inline block would need either 'unsafe-inline' - which
// gives up most of what a CSP is for - or a sha256 hash in the policy, which
// works right up until someone edits one character here and the splash silently
// stops being removed.
//
// The matching <style> block stays inline on purpose: it has to paint on the
// first frame, before any extra request could return, and style injection is a
// far smaller problem than script injection. Hence 'unsafe-inline' on
// style-src only.
//
// Load order is not a concern. `flutter-first-frame` fires once the Flutter
// engine has booted and rendered, which is long after a same-origin script tag
// in <head> has run.
window.addEventListener('flutter-first-frame', function () {
  var loading = document.getElementById('loading');
  if (loading) loading.remove();
});
