// Manuelles Validierungs-Tool: loggt sich beim echten HTW-LSF ein und gibt die
// Termine der (aktuellen oder angegebenen) Woche aus. Damit lässt sich die
// Datenschicht gegen den echten Server prüfen, sobald Netzwerkzugriff besteht.
//
// Nutzung:
//   LSF_USER=dein-login LSF_PASS=dein-passwort \
//     dart run example/fetch_timetable.dart [KW_JAHR]
//
// Beispiel: dart run example/fetch_timetable.dart 23_2026

import 'dart:io';

import 'package:lsf_client/lsf_client.dart';

Future<void> main(List<String> args) async {
  final username = Platform.environment['LSF_USER'];
  final password = Platform.environment['LSF_PASS'];

  if (username == null || password == null) {
    stderr.writeln(
      'Bitte LSF_USER und LSF_PASS als Umgebungsvariablen setzen.\n'
      'Beispiel: LSF_USER=s0500001 LSF_PASS=geheim '
      'dart run example/fetch_timetable.dart [KW_JAHR]',
    );
    exitCode = 64; // EX_USAGE
    return;
  }

  final week = args.isNotEmpty ? CalendarWeek.parse(args.first) : null;
  final client = LsfClient();

  try {
    stdout.writeln('Login als $username ...');
    await client.login(username, password);
    stdout.writeln('Login OK. Token (asi): ${client.asi ?? "—"}');

    final label = week?.param ?? 'aktuelle Woche';
    stdout.writeln('Hole iCal-Termine ($label) ...');
    final events = await client.fetchICalEvents(week: week);

    if (events.isEmpty) {
      stdout.writeln('Keine Termine gefunden.');
    } else {
      for (final e in events) {
        final start = e.start?.value;
        stdout.writeln('• ${start ?? "?"}  ${e.summary ?? "?"}'
            '  [${e.location ?? "-"}]');
      }
      stdout.writeln('\n${events.length} Termine.');
    }
  } on LoginFailedException catch (e) {
    stderr.writeln('Login fehlgeschlagen: ${e.message}');
    exitCode = 1;
  } on LsfException catch (e) {
    stderr.writeln('Fehler: ${e.message}');
    exitCode = 1;
  } finally {
    client.close();
  }
}
