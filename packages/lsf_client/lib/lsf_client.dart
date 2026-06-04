/// Plattformunabhängige Client-Bibliothek für das HTW-Berlin-LSF (HIS/QIS).
///
/// Öffentliche API für Login, Stundenplan-Abruf und iCal-Export.
library;

export 'src/endpoints.dart';
export 'src/exceptions.dart';
export 'src/harvest.dart';
export 'src/ical.dart' show ICalParser, parseICalDate, unescapeText;
export 'src/login.dart' show LoginForm, looksLoggedIn;
export 'src/lsf_client_base.dart' show LsfClient;
export 'src/models.dart';
export 'src/timetable_html.dart' show TimetableHtmlParser;
export 'src/transport.dart' show LsfResponse, LsfTransport, createDefaultTransport;
