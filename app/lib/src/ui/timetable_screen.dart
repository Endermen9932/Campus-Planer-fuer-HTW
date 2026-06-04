// Die Stundenplan-UI lebt jetzt in home_shell.dart (_TimetableTab).
// Diese Datei wird nicht mehr direkt importiert; sie bleibt leer, um
// eventuelle externe Verweise nicht zu brechen.
//
// Exportiert weiterhin [LoadState] aus dem Controller, damit ältere Tests
// oder Tool-Importe nicht brechen.

export '../state/timetable_controller.dart' show LoadState;
