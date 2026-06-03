/// Funktionen, um die für die App nötigen IDs/Tokens aus LSF-HTML zu „ernten".
///
/// Diese Operationen sind link-/attributbasiert und damit deutlich robuster als
/// das Parsen der HTML-Tabellen selbst.
library;

/// Extrahiert das `asi`-Session-Token (Anti-CSRF) aus beliebigem LSF-HTML.
/// Gibt `null` zurück, wenn keins gefunden wird.
String? extractAsi(String htmlSource) {
  // Klasse schließt Anführungszeichen, &, Whitespace und spitze Klammern aus.
  final match = RegExp("asi=([^\"&'\\s<>]+)").firstMatch(htmlSource);
  return match?.group(1);
}

/// Extrahiert die Termin-IDs aus iCal-Links (`...termine=649105,636662...`).
///
/// Bevorzugt Links mit `moduleCall=iCalendarPlan`; fällt sonst auf alle
/// `termine=`-Vorkommen zurück. Ergebnis ist dedupliziert und reihenfolge-
/// stabil.
List<String> extractTermineIds(String htmlSource) {
  final ids = <String>{};

  // 1) Bevorzugt: vollständige iCal-Links (beide Parameterreihenfolgen).
  final forward = RegExp("termine=([0-9,]+)[^\"']*moduleCall=iCalendarPlan");
  for (final m in forward.allMatches(htmlSource)) {
    _addCsv(ids, m.group(1)!);
  }
  final reverse = RegExp("moduleCall=iCalendarPlan[^\"']*termine=([0-9,]+)");
  for (final m in reverse.allMatches(htmlSource)) {
    _addCsv(ids, m.group(1)!);
  }

  // 2) Fallback: jedes termine=-Vorkommen.
  if (ids.isEmpty) {
    for (final m in RegExp(r'termine=([0-9,]+)').allMatches(htmlSource)) {
      _addCsv(ids, m.group(1)!);
    }
  }

  return ids.toList(growable: false);
}

/// Extrahiert alle `publishid`-Werte (Veranstaltungs-IDs) aus Detail-Links.
List<String> extractPublishIds(String htmlSource) {
  final ids = <String>{};
  for (final m in RegExp(r'publishid=(\d+)').allMatches(htmlSource)) {
    final id = m.group(1)!;
    if (id != '0') ids.add(id);
  }
  return ids.toList(growable: false);
}

void _addCsv(Set<String> into, String csv) {
  for (final part in csv.split(',')) {
    final trimmed = part.trim();
    if (trimmed.isNotEmpty) into.add(trimmed);
  }
}
