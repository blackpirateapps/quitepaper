# Replay sources

These sources are audit instrumentation, not application fixes or regression tests to adopt unchanged. The harness source was retrieved from the running audit app’s own VM service, so it matches the installed APK, including the diagnostic field names. It uses real production clipper widgets, services and WebView, a memory database, synthetic encryption keys and an anonymous auth provider. No private account is loaded and no sync engine is started.

The temporary entrypoint was lib/android_clipper_live_audit.dart. For the phone run, the applicationId was temporarily com.blackpiratex.quietpaper.audit and the application label Quiet Paper Audit. Android build settings temporarily used a 2048 MB Java heap, 768 MB metaspace, one Gradle worker, no parallel Gradle tasks, no persistent daemon and in-process Kotlin compilation. All tracked build/manifest changes were restored before completing the audit. Do not run an emulator or parallel builds for this replay; the earlier attempt was stopped after the user reported a host crash.

The build command was:

```sh
flutter build apk --debug --flavor github --target-platform android-arm64 --no-pub -t lib/android_clipper_live_audit.dart
```

The separate package was verified from the APK manifest before installation. The app’s loopback audit endpoint was forwarded over the authorized USB connection; it was removed along with the audit app at cleanup.

## Executed harness

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html/parser.dart' as html;
import 'package:shared_preferences/shared_preferences.dart';
import 'app/theme/app_theme.dart';
import 'core/crypto/key_manager.dart';
import 'core/auth/auth_service.dart';
import 'core/database/app_database.dart';
import 'core/sync/sync_provider.dart';
import 'core/web_clipper/web_clipper_models.dart';
import 'core/web_clipper/web_clipper_provider.dart';
import 'features/notes/application/notes_provider.dart';
import 'features/notes/data/notes_repository.dart';
import 'features/settings/application/settings_provider.dart';
import 'features/web_clipper/presentation/web_clip_dialog.dart';
import 'features/web_clipper/presentation/web_clip_preview_sheet.dart';
import 'features/web_clipper/presentation/browser/web_clip_browser_controller.dart';
import 'features/web_clipper/presentation/browser/web_clip_browser_screen.dart';

class AuditAuth implements AuthService {
  @override
  AuthUser? get currentUser => null;
  @override
  Stream<AuthUser?> get authStateChanges => Stream.value(null);
  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class AuditKeys implements KeyManager {
  @override
  bool get isUnlocked => true;
  @override
  bool get hasKeyData => true;
  @override
  Uint8List getMasterKey() =>
      Uint8List.fromList(List.generate(32, (i) => i + 1));
  @override
  Uint8List get cachedMasterKey => getMasterKey();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final navKey = GlobalKey<NavigatorState>();
final errors = <String>[];
final routes = <String>[];
WebClipBrowserController? browser;
WebClipScanResult? lastScan;
late ProviderContainer container;
late AppDatabase db;
late DriftNotesRepository repository;

class RouteLog extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      routes.add('push:${route.settings.name ?? route.runtimeType}');
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      routes.add('pop:${route.settings.name ?? route.runtimeType}');
}

List<double>? rect(Element e) {
  final r = e.findRenderObject();
  if (r is! RenderBox || !r.attached || !r.hasSize) return null;
  final p = r.localToGlobal(Offset.zero);
  return [p.dx, p.dy, r.size.width, r.size.height];
}

Map<String, dynamic> state() {
  final labels = <Object?>[], fields = <Object?>[];
  void visit(Element e) {
    final w = e.widget;
    if (w is Text && w.data != null)
      labels.add({'text': w.data, 'rect': rect(e)});
    if (w is Tooltip) labels.add({'tooltip': w.message, 'rect': rect(e)});
    if (w is EditableText)
      fields.add({
        'text': w.controller.text,
        'focus': w.focusNode.hasFocus,
        'rect': rect(e),
      });
    e.visitChildren(visit);
  }

  WidgetsBinding.instance.rootElement?.visitChildren(visit);
  final s = browser?.state;
  return {
    'labels': labels,
    'fields': fields,
    'errors': errors,
    'routes': routes,
    'browser': s == null
        ? null
        : {
            'url': s.currentUrl,
            'title': s.pageTitle,
            'loading': s.loadingState.name,
            'progress': s.progress,
            'error': s.errorMessage,
            'canClip': s.canClip,
          },
  };
}

Map<String, dynamic> summarize(WebClipScanResult scan) {
  final raw = html.parse(scan.rawHtml),
      clean = html.parse(scan.cleanedArticleHtml);
  final body = raw.body?.text ?? '';
  final text = clean.body?.text ?? '';
  final sourcePs = raw.querySelectorAll('article p, main p');
  final retained = sourcePs
      .where((p) => p.text.trim().isNotEmpty && text.contains(p.text.trim()))
      .length;
  return {
    'url': scan.metadata.sourceUrl,
    'title': scan.metadata.title,
    'rootTag': clean.body?.children.firstOrNull?.localName,
    'rootId': clean.body?.children.firstOrNull?.id,
    'rawHeadingCount': raw.querySelectorAll('h1,h2,h3').length,
    'cleanHeadingCount': clean.querySelectorAll('h1,h2,h3').length,
    'rawLength': scan.rawHtml.length,
    'cleanLength': scan.cleanedArticleHtml.length,
    'bodyTextLength': body.length,
    'cleanTextLength': text.length,
    'sourceArticleParagraphs': sourcePs.length,
    'retainedParagraphs': retained,
    'images': scan.images
        .map(
          (i) => {
            'url': i.resolvedUrl,
            'alt': i.altText,
            'selected': i.isSelected,
          },
        )
        .toList(),
    'fallback': scan.isPageContentFallback,
    'markdownLength': scan.markdownBody.length,
    'sizes': {
      'markdown': scan.markdownSizeEstimate,
      'snapshot': scan.htmlSnapshotSizeEstimate,
    },
  };
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!Platform.isAndroid)
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  final prefs = await SharedPreferences.getInstance();
  db = AppDatabase.memory();
  repository = DriftNotesRepository(db);
  container = ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(db),
      notesRepositoryProvider.overrideWithValue(repository),
      keyManagerProvider.overrideWithValue(AuditKeys()),
      authServiceProvider.overrideWithValue(AuditAuth()),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );
  FlutterError.onError = (d) {
    errors.add(d.exceptionAsString());
    FlutterError.presentError(d);
  };
  PlatformDispatcher.instance.onError = (e, s) {
    errors.add('$e');
    return true;
  };
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        navigatorKey: navKey,
        navigatorObservers: [RouteLog()],
        theme: AppTheme.light().copyWith(platform: TargetPlatform.android),
        title: 'Quiet Paper — Clipper Audit',
        home: Scaffold(
          appBar: AppBar(title: const Text('Isolated web clipper audit')),
          body: Builder(
            builder: (context) => Column(
              children: [
                const Text('Temporary test notebook — no personal data'),
                TextButton(
                  onPressed: () => WebClipDialog.show(context),
                  child: const Text('Clip a real URL'),
                ),
                TextButton(
                  onPressed: () => WebClipBrowserScreen.open(
                    context,
                    initialUrl: 'https://www.paulgraham.com/ds.html',
                  ),
                  child: const Text('Open acquisition browser'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 38925);
  stdout.writeln('CLIPPER_LIVE_AUDIT_READY');
  await for (final req in server) {
    try {
      final path = req.uri.path, q = req.uri.queryParameters;
      Object? out;
      if (path == '/open') {
        if (q['mode'] == 'browser') {
          browser = WebClipBrowserController(initialUrl: q['url']!);
          unawaited(
            navKey.currentState!.push(
              MaterialPageRoute<void>(
                builder: (_) => WebClipBrowserScreen(
                  initialUrl: q['url']!,
                  controller: browser,
                ),
              ),
            ),
          );
        } else {
          unawaited(
            WebClipDialog.show(navKey.currentContext!, initialUrl: q['url']),
          );
        }
      } else if (path == '/reset') {
        navKey.currentState!.popUntil((r) => r.isFirst);
      } else if (path == '/scan') {
        final sw = Stopwatch()..start();
        lastScan = await container
            .read(webClipperServiceProvider)
            .scanUrl(q['url']!);
        out = {...summarize(lastScan!), 'elapsedMs': sw.elapsedMilliseconds};
      } else if (path == '/diagnostics') {
        final scan = lastScan!;
        final raw = html.parse(scan.rawHtml),
            clean = html.parse(scan.cleanedArticleHtml);
        final cleanText = clean.body?.text ?? '';
        final markdown = scan.markdownBody;
        final figures = clean.querySelectorAll('figure').map((f) {
          final code = f.querySelector('pre')?.text.trim() ?? '';
          return {
            'codeLength': code.length,
            'hasImage': f.querySelector('img') != null,
            'codeRetained': code.isNotEmpty && markdown.contains(code),
            'textLength': f.text.length,
          };
        }).toList();
        final samples = <String>[];
        void collect(dynamic node) {
          if (node.nodeType == 3 &&
              node.text.trim().length > 100 &&
              samples.length < 5) {
            samples.add(node.text.trim().substring(0, 50));
          }
          for (final child in node.nodes) {
            collect(child);
          }
        }

        collect(clean);
        String norm(String value) => value.replaceAll(RegExp(r'\s+'), ' ');
        final paragraphs = samples
            .map(
              (value) => {
                'sampleLength': value.length,
                'rawOccurrences':
                    norm(raw.body?.text ?? '').split(norm(value)).length - 1,
                'cleanOccurrences':
                    norm(cleanText).split(norm(value)).length - 1,
                'markdownOccurrences':
                    norm(markdown).split(norm(value)).length - 1,
              },
            )
            .toList();
        final dropped = raw
            .querySelectorAll('img')
            .where(
              (i) => RegExp(
                r'star|arrow|logo',
                caseSensitive: false,
              ).hasMatch(i.attributes['alt'] ?? ''),
            )
            .map(
              (i) => {
                'alt': i.attributes['alt'],
                'src': i.attributes['src'],
                'retained': scan.cleanedArticleHtml.contains(
                  i.attributes['src'] ?? '___',
                ),
              },
            )
            .toList();
        out = {
          'url': scan.metadata.sourceUrl,
          'figures': figures,
          'paragraphs': paragraphs,
          'filteredImages': dropped,
          'tables': clean.querySelectorAll('table').length,
          'preCount': clean.querySelectorAll('pre').length,
          'rawPreCount': raw.querySelectorAll('pre').length,
        };
      } else if (path == '/preview') {
        unawaited(
          WebClipPreviewSheet.show(
            navKey.currentContext!,
            scanResult: lastScan!,
          ),
        );
      } else if (path == '/capture') {
        final capture = await browser!.captureCurrentPage();
        out = {'success': capture.isSuccess, 'error': '${capture.error}'};
        if (capture.isSuccess) {
          lastScan = await container
              .read(webClipperServiceProvider)
              .scanPayload(capture.payload!);
          out = summarize(lastScan!);
        }
        browser!.resetToReady();
      } else if (path == '/navigate') {
        await browser!.navigateTo(q['url']!);
      } else if (path == '/notes') {
        final notes = await db.select(db.notesTable).get();
        out = notes
            .map(
              (n) => {'id': n.id, 'title': n.title, 'length': n.content.length},
            )
            .toList();
      } else if (path == '/setText') {
        final fields = <EditableText>[];
        void visit(Element e) {
          if (e.widget is EditableText) fields.add(e.widget as EditableText);
          e.visitChildren(visit);
        }

        WidgetsBinding.instance.rootElement?.visitChildren(visit);
        fields.last.controller.text = q['text']!;
      } else if (path == '/clearErrors') {
        errors.clear();
      }
      req.response.headers.contentType = ContentType.json;
      req.response.write(jsonEncode(out ?? state()));
    } catch (e, s) {
      req.response.statusCode = 500;
      req.response.write(jsonEncode({'error': '$e', 'stack': '$s'}));
    }
    await req.response.close();
  }
}
```

## Native driver helpers

Replace the device serial and local cache directory to replay elsewhere. UI actions used adb touch input; /open and /navigate set up routes, /capture invokes the real controller/scan path, and /scan exercises direct HTTP on the phone. Route/scan setup through the loopback harness is distinguished from native taps in the reports. Screenshots were restricted to the focused audit app.

```python
import json, pathlib, subprocess, urllib.request, urllib.parse, time
ROOT=pathlib.Path('/home/dog/.cache/quiet-paper-clipper-usb-audit')
ADB='/home/dog/android-sdk/platform-tools/adb'
SERIAL='REPLACE_WITH_AUTHORIZED_DEVICE_SERIAL'
PACKAGE='com.blackpiratex.quietpaper.audit'
BASE='http://127.0.0.1:38925'
DPR=2.75
def adb(*args,**kwargs):return subprocess.run([ADB,'-s',SERIAL,*args],check=True,**kwargs)
def api(path='/state',**query):
 url=BASE+path+('?' + urllib.parse.urlencode(query) if query else '')
 try:
  with urllib.request.urlopen(url,timeout=100) as r:return json.load(r)
 except urllib.error.HTTPError as e:raise RuntimeError(e.read().decode())
def active():
 out=subprocess.check_output([ADB,'-s',SERIAL,'shell','dumpsys','window'],text=True)
 return any(PACKAGE in line and 'mCurrentFocus' in line for line in out.splitlines())
def screenshot(name):
 if not active():raise RuntimeError('Audit app is not focused; refusing to capture another app')
 path=ROOT/(name+'.png')
 with path.open('wb') as f:adb('exec-out','screencap','-p',stdout=f)
 return str(path)
def state(name):
 s=api();(ROOT/(name+'.json')).write_text(json.dumps(s,indent=2));return s
def tap(text,exact=True):
 s=api();labels=[l for l in s['labels'] if l.get('rect') and (l.get('text')==text if exact else text in l.get('text',''))]
 if not labels:raise RuntimeError('Missing label '+text)
 r=labels[-1]['rect'];adb('shell','input','tap',str(round((r[0]+r[2]/2)*DPR)),str(round((r[1]+r[3]/2)*DPR)))
 time.sleep(.35)
def wait_label(text,timeout=55):
 end=time.monotonic()+timeout
 while time.monotonic()<end:
  s=api()
  if any(l.get('text')==text for l in s['labels']):return s
  time.sleep(.5)
 raise TimeoutError(text)
def brief(s):return {'labels':[l['text'] for l in s['labels'] if 'text' in l], 'errors':s['errors'],'browser':s['browser'],'routes':s['routes'][-8:]}
```

## Focused component probes

WC-12 through WC-14 also have live device evidence. WC-15 is a minimal component reproduction only. WC-11 and WC-16 rely on actual phone behavior and screenshots.

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;
import 'package:quitepaper/core/web_clipper/article_extractor.dart';
import 'package:quitepaper/core/web_clipper/clipped_image_filter.dart';
import 'package:quitepaper/core/web_clipper/html_to_markdown_converter.dart';
import 'package:quitepaper/core/web_clipper/web_clipper_models.dart';

const meta = ExtractedArticleMetadata(
  sourceUrl: 'https://example.org/article',
  title: 'Article',
  domain: 'example.org',
);
void main() {
  test('WC-12 nested layout tables duplicate article text', () {
    final element = html
        .parseFragment(
          '<div><table><tr><td><table><tr><td><p>Unique article sentence with enough content to recognize.</p></td></tr></table></td></tr></table></div>',
        )
        .children
        .single;
    final markdown = const HtmlToMarkdownConverter().convert(
      cleanedElement: element,
      metadata: meta,
    );
    final count = 'Unique article sentence'.allMatches(markdown).length;
    print('WC-12 input occurrences=1, output occurrences=$count');
    expect(count, 3);
  });
  test(
    'WC-13 readable sibling sections are discarded after choosing one section',
    () {
      final body =
          '<body><section id="introduction"><p>${'Introduction text. ' * 20}</p></section><section id="largest"><p>${'Main text, with a comma. ' * 200}</p></section><section id="conclusion"><p>${'Conclusion text. ' * 20}</p></section></body>';
      final result = const ArticleExtractor().extract(
        htmlContent: body,
        sourceUrl: meta.sourceUrl,
      );
      expect(result.cleanedElement.id, 'largest');
      expect(result.cleanedElement.text, isNot(contains('Introduction text')));
      expect(result.cleanedElement.text, isNot(contains('Conclusion text')));
      expect(result.isArticleRootFound, isTrue);
      print(
        'WC-13 three sibling sections => only #largest retained and reported as article',
      );
    },
  );
  test('WC-14 figure containing protocol code loses its code', () {
    final element = html
        .parseFragment(
          '<article><p>Protocol example follows.</p><figure><pre>GET /index HTTP/1.1\nHost: example.org</pre><figcaption>Example request</figcaption></figure></article>',
        )
        .children
        .single;
    final markdown = const HtmlToMarkdownConverter().convert(
      cleanedElement: element,
      metadata: meta,
    );
    expect(markdown, contains('Example request'));
    expect(markdown, isNot(contains('GET /index')));
    print('WC-14 code present in input figure, absent from converted output');
  });
  test('WC-15 astronomy photo is removed solely because its alt mentions stars', () {
    final star = html
        .parseFragment(
          '<img src="https://example.org/nebula.jpg" width="1200" height="800" alt="A star cluster in a nebula">',
        )
        .children
        .single;
    final neutral = html
        .parseFragment(
          '<img src="https://example.org/nebula.jpg" width="1200" height="800" alt="A cluster in a nebula">',
        )
        .children
        .single;
    expect(ClippedImageFilter.isUsefulContentImage(star), isFalse);
    expect(ClippedImageFilter.isUsefulContentImage(neutral), isTrue);
    print(
      'WC-15 same 1200x800 photo: alt mentions star => rejected, neutral alt => accepted',
    );
  });
}
```
