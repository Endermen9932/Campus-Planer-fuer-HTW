import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import 'models.dart';

/// Parser für die HTML-Stundenplanansicht.
///
/// ZWEI Ebenen:
///  * [parseLessonBlock] – parst den Textblock EINER Veranstaltung (das im
///    LSF sichtbare Format) in ein [Lesson]. Gut getestet gegen reale Daten.
///  * [parseTimetable] – Best-Effort-DOM-Extraktion der Blöcke aus der ganzen
///    Seite. Die DOM-Struktur von LSF ist ohne Live-Zugriff nicht 100%
///    bestätigt → **gegen echtes HTML validieren**. Für verlässliche Daten ist
///    der iCal-Export (siehe `ICalParser`) der bevorzugte Weg.
class TimetableHtmlParser {
  static final _sws = RegExp(r'(\d+)\s*SWS\s+([^\n]+)');
  static final _dayTime = RegExp(
    r'(Montag|Dienstag|Mittwoch|Donnerstag|Freitag|Samstag|Sonntag)\s*,?\s*'
    r'(\d{1,2}:\d{2})\s*-\s*(\d{1,2}:\d{2})\s*,?\s*([0-9A-Za-zäöüÄÖÜ]+)?',
  );
  static final _room = RegExp(r'Raum:\s*([^\n]+)');
  static final _courseNo = RegExp(r'^([A-Z]{1,3}\d{1,3})\b');
  static final _trailingParen = RegExp(r'\(([^)]*)\)\s*$');
  static final _publishId = RegExp(r'publishid=(\d+)');

  /// Parst den Textblock einer einzelnen Veranstaltung. Zeilen sind durch `\n`
  /// getrennt (im DOM aus `<br>` rekonstruiert).
  static Lesson parseLessonBlock(String block, {String? publishId}) {
    final text = block.trim();

    final swsMatch = _sws.firstMatch(text);
    final titleEnd = swsMatch?.start ?? text.length;
    final title = text
        .substring(0, titleEnd)
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .replaceAll(RegExp(r',\s*$'), '');

    final dt = _dayTime.firstMatch(text);
    final room = _room.firstMatch(text)?.group(1)?.trim();
    final courseNo = _courseNo.firstMatch(title)?.group(1);
    final type = _trailingParen.firstMatch(title)?.group(1)?.trim();
    final language = swsMatch?.group(2)?.trim();
    final sws = swsMatch != null ? int.tryParse(swsMatch.group(1)!) : null;

    return Lesson(
      title: title,
      courseNumber: courseNo,
      type: type,
      sws: sws,
      day: dt?.group(1),
      startTime: dt?.group(2),
      endTime: dt?.group(3),
      rhythm: dt?.group(4),
      room: room,
      language: language,
      publishId: publishId,
    );
  }

  /// Best-Effort: extrahiert alle Veranstaltungen aus der kompletten HTML-Seite.
  ///
  /// **Achtung:** gegen echtes LSF-HTML zu validieren (siehe Klassendoku).
  static List<Lesson> parseTimetable(String htmlSource) {
    final doc = html_parser.parse(htmlSource);
    final lessons = <Lesson>[];
    final seen = <String>{};

    final containers = doc.querySelectorAll('td, div');
    for (final el in containers) {
      final text = _extractText(el).trim();
      if (text.isEmpty || !_looksLikeLesson(text)) continue;

      final href = el.querySelector('a[href*=publishid]')?.attributes['href'];
      final publishId =
          href != null ? _publishId.firstMatch(href)?.group(1) : null;

      final lesson = parseLessonBlock(text, publishId: publishId);
      final key = '${lesson.title}|${lesson.day}|${lesson.startTime}';
      if (seen.add(key)) lessons.add(lesson);
    }
    return lessons;
  }

  static bool _looksLikeLesson(String text) =>
      _sws.hasMatch(text) || _dayTime.hasMatch(text);

  /// Rekonstruiert Text inkl. Zeilenumbrüchen: `<br>` und Block-Elemente werden
  /// zu `\n`, damit [parseLessonBlock] die Zeilen wiederfindet.
  static String _extractText(Node node) {
    final buffer = StringBuffer();
    _walk(node, buffer);
    return buffer.toString();
  }

  static const _blockTags = {
    'br',
    'p',
    'div',
    'tr',
    'li',
    'table',
    'ul',
    'ol',
    'h1',
    'h2',
    'h3',
  };

  static void _walk(Node node, StringBuffer out) {
    for (final child in node.nodes) {
      if (child is Text) {
        out.write(child.text);
      } else if (child is Element) {
        final tag = child.localName;
        if (tag == 'br') {
          out.write('\n');
          continue;
        }
        _walk(child, out);
        if (_blockTags.contains(tag)) out.write('\n');
      }
    }
  }
}
