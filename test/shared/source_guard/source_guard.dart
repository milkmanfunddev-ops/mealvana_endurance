// The matcher behind `report_source_guard_test.dart`. Pure functions over
// source text so the test file can prove the rules on inline snippets.
//
// Matching rules, in plain words (spec: `.scratch/sentry/spec.md`
// § Enforcement; ticket 04):
//
// What is scanned. Every `lib/**.dart` file except generated code
// (`*.g.dart`, `*.freezed.dart`) and `lib/features/_archived/`, which the
// analyzer excludes too. Comments and string literals are blanked to spaces
// before matching (line numbers survive), so a `catch (` in a doc comment or a
// `print(` inside a string never counts, and braces inside strings never
// confuse the brace matching. `${...}` interpolations are walked as code.
//
// What a catch block is. A clause that follows a closing brace: `} catch (`,
// `} on X catch (`, or a bare `} on X {`. The brace is what tells a catch
// clause from a mixin's `on` clause (`mixin A on B {`). The block is the text
// from the clause's opening `{` to its matching `}`.
//
// What counts as reported. The block's text (nested blocks included, so an
// inner catch's report counts for the outer) contains at least one of:
//   - an escape: `rethrow`, `throw `, `throw(`, or `Error.throwWithStackTrace(`;
//     the error leaves the block, so the caller owns it;
//   - a `Report` call: `.fault(`, `.degraded(`, `.note(`, `report.`,
//     `_report.`, `Report.`;
//   - a domain decoder's `onIssue(` callback (`DecodeIssue`), which the data
//     layer binds to `report.decodeIssue(area)`.
// `info` / `debug` are not reports: they write a structured log and no
// event, which is the silent path rule D9 bans.
//
// Prints. `print(` or `debugPrint(` anywhere inside a catch block is a
// finding of its own, whether or not the block also reports.
//
// Imports. Any `import 'package:sentry...'` outside
// `lib/shared/services/report/` and `lib/shared/core/bootstrap/` is a finding.
//
// Signatures. A catch finding is keyed by file path plus the trimmed text of
// the line holding the `catch` (or bare `on`) keyword, so line numbers can
// drift without touching the allow-list. Identical signatures in one file are
// counted: the allow-list needs one entry per occurrence.

/// What kind of rule a finding breaks.
enum FindingKind { unreportedCatch, printInCatch, sentryImport }

/// One rule violation at one site.
class Finding {
  const Finding({
    required this.kind,
    required this.path,
    required this.line,
    required this.signature,
  });

  final FindingKind kind;
  final String path;

  /// 1-based line of the catch keyword (or the import).
  final int line;

  /// Trimmed source line; stable across line-number drift.
  final String signature;

  /// The allow-list key: kind, path and signature, line dropped.
  String get key => '${kind.name} $path :: $signature';

  @override
  String toString() => '$path:$line  ${kind.name}  `$signature`';
}

/// A catch block located in scrubbed source.
class CatchBlock {
  const CatchBlock({
    required this.line,
    required this.signature,
    required this.body,
  });

  final int line;
  final String signature;

  /// Scrubbed text between the block's braces.
  final String body;
}

const List<String> _escapes = [
  'rethrow',
  'throw ',
  'throw(',
  'Error.throwWithStackTrace(',
];

const List<String> reportCalls = [
  '.fault(',
  '.degraded(',
  '.note(',
  'report.',
  '_report.',
  'Report.',
  // `Report.faultUnlessWeather` (ticket 41): a fault, or a breadcrumb plus an
  // `expected_failure` count for network weather; either way the catch is
  // written down, so the call is the report.
  '.faultUnlessWeather(',
  // `Report.count` (ticket 54) is reached as `report.count(` /
  // `_report.count(`, already covered by the two entries above; a bare
  // `.count(` is not listed because a Drift query's `.count()` would then
  // excuse an unreported catch.
  // A pure domain decoder hands its issue to the data layer's `DecodeIssue`
  // callback (`lib/shared/domain/decode_issue.dart`), which is bound to
  // `report.decodeIssue(area)`; the call is the report.
  'onIssue(',
];

const List<String> _prints = ['print(', 'debugPrint('];

const List<String> sentryImportPermittedDirs = [
  'lib/shared/services/report/',
  'lib/shared/core/bootstrap/',
];

/// True when a scrubbed catch body escapes or reports by the rules above.
bool bodyIsReported(String body) {
  for (final p in _escapes) {
    if (body.contains(p)) return true;
  }
  for (final p in reportCalls) {
    if (body.contains(p)) return true;
  }
  return false;
}

bool bodyPrints(String body) => _prints.any(body.contains);

/// Replaces comments and string contents with spaces, keeping every newline
/// so line numbers are unchanged. `${...}` inside a string is kept as code.
String scrub(String source) {
  final out = StringBuffer();
  var i = 0;
  final n = source.length;

  void blank(int from, int to) {
    for (var k = from; k < to; k++) {
      out.write(source[k] == '\n' ? '\n' : ' ');
    }
  }

  // Returns the index just past the string that starts at [start]; writes
  // spaces for its contents and code for interpolations.
  int skipString(int start) {
    var j = start;
    var raw = false;
    if (source[j] == 'r') {
      raw = true;
      j++;
    }
    final quote = source[j];
    final triple = j + 2 < n && source[j + 1] == quote && source[j + 2] == quote;
    final delim = triple ? quote * 3 : quote;
    blank(start, j + delim.length);
    j += delim.length;
    while (j < n) {
      if (source.startsWith(delim, j)) {
        blank(j, j + delim.length);
        return j + delim.length;
      }
      final c = source[j];
      if (!raw && c == r'\' && j + 1 < n) {
        blank(j, j + 2);
        j += 2;
        continue;
      }
      if (!raw && c == r'$' && j + 1 < n && source[j + 1] == '{') {
        // Interpolation: walk as code until the matching brace.
        out.write(r'${');
        j += 2;
        var depth = 1;
        while (j < n && depth > 0) {
          final d = source[j];
          if (d == "'" || d == '"' || (d == 'r' && j + 1 < n && (source[j + 1] == "'" || source[j + 1] == '"'))) {
            j = skipString(j);
            continue;
          }
          if (d == '{') depth++;
          if (d == '}') depth--;
          out.write(d);
          j++;
        }
        continue;
      }
      out.write(c == '\n' ? '\n' : ' ');
      j++;
    }
    return j;
  }

  while (i < n) {
    final c = source[i];
    if (c == '/' && i + 1 < n && source[i + 1] == '/') {
      final end = source.indexOf('\n', i);
      final stop = end == -1 ? n : end;
      blank(i, stop);
      i = stop;
      continue;
    }
    if (c == '/' && i + 1 < n && source[i + 1] == '*') {
      final end = source.indexOf('*/', i + 2);
      final stop = end == -1 ? n : end + 2;
      blank(i, stop);
      i = stop;
      continue;
    }
    if (c == "'" || c == '"') {
      i = skipString(i);
      continue;
    }
    if (c == 'r' && i + 1 < n && (source[i + 1] == "'" || source[i + 1] == '"')) {
      // A raw string, but only when `r` is not the tail of an identifier.
      final prev = i > 0 ? source[i - 1] : ' ';
      if (!RegExp(r'[A-Za-z0-9_$]').hasMatch(prev)) {
        i = skipString(i);
        continue;
      }
    }
    out.write(c);
    i++;
  }
  return out.toString();
}

final RegExp _catchClause = RegExp(
  r'\}\s*(?:on\s+[A-Za-z_$][\w$<>,.?\s]*?\s*)?(catch)\s*\(|\}\s*(on)\s+[A-Za-z_$][\w$<>,.?\s]*?\s*\{',
);

/// Finds every catch block in [source]. Signatures come from the original
/// (unscrubbed) lines.
List<CatchBlock> findCatchBlocks(String source) {
  final scrubbed = scrub(source);
  final originalLines = source.split('\n');
  final blocks = <CatchBlock>[];

  for (final m in _catchClause.allMatches(scrubbed)) {
    // Position of the keyword (`catch` or `on`) for the signature line.
    final text = m[0]!;
    final keywordStart = m.group(1) != null
        ? m.start + text.lastIndexOf('catch')
        : m.start + text.indexOf(RegExp(r'\bon\s'));
    // Opening brace of the block.
    int open;
    if (m.group(1) != null) {
      final closeParen = scrubbed.indexOf(')', m.end);
      if (closeParen == -1) continue;
      open = scrubbed.indexOf('{', closeParen);
    } else {
      open = m.end - 1;
    }
    if (open == -1) continue;

    var depth = 0;
    var close = -1;
    for (var k = open; k < scrubbed.length; k++) {
      final ch = scrubbed[k];
      if (ch == '{') depth++;
      if (ch == '}') {
        depth--;
        if (depth == 0) {
          close = k;
          break;
        }
      }
    }
    if (close == -1) continue;

    final line = _lineOf(scrubbed, keywordStart);
    blocks.add(
      CatchBlock(
        line: line,
        signature: originalLines[line - 1].trim(),
        body: scrubbed.substring(open + 1, close),
      ),
    );
  }
  return blocks;
}

int _lineOf(String text, int offset) {
  var line = 1;
  for (var k = 0; k < offset; k++) {
    if (text.codeUnitAt(k) == 10) line++;
  }
  return line;
}

/// Runs all three rules over one file's source.
List<Finding> scanSource(String path, String source) {
  final findings = <Finding>[];

  for (final block in findCatchBlocks(source)) {
    if (!bodyIsReported(block.body)) {
      findings.add(
        Finding(
          kind: FindingKind.unreportedCatch,
          path: path,
          line: block.line,
          signature: block.signature,
        ),
      );
    }
    if (bodyPrints(block.body)) {
      findings.add(
        Finding(
          kind: FindingKind.printInCatch,
          path: path,
          line: block.line,
          signature: block.signature,
        ),
      );
    }
  }

  final permitted = sentryImportPermittedDirs.any(path.startsWith);
  if (!permitted) {
    final lines = source.split('\n');
    for (var k = 0; k < lines.length; k++) {
      final l = lines[k].trim();
      if (l.startsWith('import ') && l.contains("'package:sentry")) {
        findings.add(
          Finding(
            kind: FindingKind.sentryImport,
            path: path,
            line: k + 1,
            signature: l,
          ),
        );
      }
    }
  }
  return findings;
}

/// The allow-list, parsed from `allow_list.md`. Format, one entry per line
/// under a `## baseline` or `## reasoned` heading:
///
///     <kind> <path> :: <signature>              (baseline)
///     <kind> <path> :: <signature> :: <reason>  (reasoned)
///
/// where `<kind>` is `unreportedCatch`, `printInCatch` or `sentryImport`.
/// Everything before the first `## ` heading is documentation. Blank lines
/// and lines starting with `#` (outside headings) or `>` are ignored. Keys
/// are counted, one entry per occurrence.
class AllowList {
  AllowList({required this.baseline, required this.reasoned, this.errors = const []});

  /// key -> count
  final Map<String, int> baseline;
  final Map<String, int> reasoned;

  /// Malformed lines, with line numbers.
  final List<String> errors;

  static AllowList parse(String text) {
    final baseline = <String, int>{};
    final reasoned = <String, int>{};
    final errors = <String>[];
    String? section;
    final lines = text.split('\n');
    for (var k = 0; k < lines.length; k++) {
      final raw = lines[k];
      final l = raw.trim();
      if (l.isEmpty || l.startsWith('>')) continue;
      if (l.startsWith('## ')) {
        section = l.substring(3).trim();
        continue;
      }
      if (l.startsWith('#')) continue;
      // Prose before the first heading is the file's own documentation.
      if (section == null) continue;
      if (section != 'baseline' && section != 'reasoned') {
        errors.add('line ${k + 1}: entry outside a baseline/reasoned section');
        continue;
      }
      final parts = l.split(' :: ');
      final head = parts[0].split(RegExp(r'\s+'));
      if (head.length != 2 || parts.length < 2) {
        errors.add('line ${k + 1}: expected `<kind> <path> :: <signature>`');
        continue;
      }
      final kind = head[0];
      if (!FindingKind.values.any((v) => v.name == kind)) {
        errors.add('line ${k + 1}: unknown kind `$kind`');
        continue;
      }
      final key = '$kind ${head[1]} :: ${parts[1].trim()}';
      if (section == 'baseline') {
        if (parts.length != 2) {
          errors.add('line ${k + 1}: baseline entries carry no reason');
          continue;
        }
        baseline[key] = (baseline[key] ?? 0) + 1;
      } else {
        if (parts.length != 3 || parts[2].trim().isEmpty) {
          errors.add('line ${k + 1}: reasoned entries need ` :: <reason>`');
          continue;
        }
        reasoned[key] = (reasoned[key] ?? 0) + 1;
      }
    }
    return AllowList(baseline: baseline, reasoned: reasoned, errors: errors);
  }

  /// Both sections merged, key -> count.
  Map<String, int> get all {
    final m = Map<String, int>.from(baseline);
    reasoned.forEach((k, v) => m[k] = (m[k] ?? 0) + v);
    return m;
  }
}

/// Outcome of reconciling findings against the allow-list.
class Reconciliation {
  const Reconciliation({required this.unlisted, required this.stale});

  /// Findings with no (remaining) allow-list entry: new violations.
  final List<Finding> unlisted;

  /// Allow-list keys (with surplus count) that match nothing: must be deleted.
  final Map<String, int> stale;

  bool get clean => unlisted.isEmpty && stale.isEmpty;
}

Reconciliation reconcile(List<Finding> findings, AllowList allowList) {
  final remaining = allowList.all;
  final unlisted = <Finding>[];
  for (final f in findings) {
    final left = remaining[f.key] ?? 0;
    if (left > 0) {
      remaining[f.key] = left - 1;
    } else {
      unlisted.add(f);
    }
  }
  final stale = <String, int>{
    for (final e in remaining.entries)
      if (e.value > 0) e.key: e.value,
  };
  return Reconciliation(unlisted: unlisted, stale: stale);
}
