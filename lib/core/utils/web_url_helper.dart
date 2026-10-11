// Helpers for recognizing a note body that is nothing but a single web link.
//
// Pure and dependency-free (dart:core only): used to decide whether a pasted
// or typed note consists of exactly one http(s) URL so it can be treated as a
// Bear-style web link rather than ordinary text.

/// Canonical anchored matcher for a lone http(s) URL.
///
/// `^https?://` requires the scheme at the very start, `\S+` forbids any
/// interior whitespace (space, tab, newline), and `$` anchors the end so there
/// is nothing after the URL. Scheme matching is case-insensitive (HTTP, Https).
/// This deliberately excludes `qp://`, `mailto:`, and every other non-http(s)
/// scheme.
final RegExp _singleWebUrlRegExp = RegExp(r'^https?://\S+$', caseSensitive: false);

/// True iff the entire trimmed [input] is exactly one http(s) URL
/// (no interior whitespace, no newline, nothing before/after). Excludes
/// qp://, mailto:, and all non-http(s) schemes.
bool isSingleWebUrl(String input) => _singleWebUrlRegExp.hasMatch(input.trim());

/// Trims [input] and returns the lone http(s) URL if [isSingleWebUrl],
/// else null. (v1: trimming only; no further rewriting.)
String? normalizeWebUrl(String input) {
  final trimmed = input.trim();
  return _singleWebUrlRegExp.hasMatch(trimmed) ? trimmed : null;
}
