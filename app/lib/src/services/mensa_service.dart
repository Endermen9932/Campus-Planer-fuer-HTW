import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import 'mensa_fetch.dart'
    if (dart.library.html) 'mensa_fetch_web.dart' as fetch;
import 'proxy_config.dart';

class MensaPrices {
  const MensaPrices({
    required this.student,
    required this.staff,
    required this.guest,
  });

  final double student;
  final double staff;
  final double guest;

  Map<String, dynamic> toJson() =>
      {'student': student, 'staff': staff, 'guest': guest};

  factory MensaPrices.fromJson(Map<String, dynamic> j) => MensaPrices(
        student: (j['student'] as num).toDouble(),
        staff: (j['staff'] as num).toDouble(),
        guest: (j['guest'] as num).toDouble(),
      );
}

class MensaLabels {
  const MensaLabels({
    this.vegetarian = false,
    this.vegan = false,
    this.sustainability,
    this.co2Rating,
    this.h2oRating,
  });

  final bool vegetarian;
  final bool vegan;

  /// 'green', 'yellow', or 'red'
  final String? sustainability;

  /// 'A', 'B', 'C', …
  final String? co2Rating;

  /// 'A', 'B', 'C', …
  final String? h2oRating;

  Map<String, dynamic> toJson() => {
        'vegetarian': vegetarian,
        'vegan': vegan,
        if (sustainability != null) 'sustainability': sustainability,
        if (co2Rating != null) 'co2Rating': co2Rating,
        if (h2oRating != null) 'h2oRating': h2oRating,
      };

  factory MensaLabels.fromJson(Map<String, dynamic> j) => MensaLabels(
        vegetarian: (j['vegetarian'] as bool?) ?? false,
        vegan: (j['vegan'] as bool?) ?? false,
        sustainability: j['sustainability'] as String?,
        co2Rating: j['co2Rating'] as String?,
        h2oRating: j['h2oRating'] as String?,
      );
}

class MensaMeal {
  const MensaMeal({
    required this.name,
    this.prices,
    required this.additives,
    required this.labels,
  });

  final String name;
  final MensaPrices? prices;
  final List<String> additives;
  final MensaLabels labels;

  Map<String, dynamic> toJson() => {
        'name': name,
        if (prices != null) 'prices': prices!.toJson(),
        'additives': additives,
        'labels': labels.toJson(),
      };

  factory MensaMeal.fromJson(Map<String, dynamic> j) => MensaMeal(
        name: j['name'] as String,
        prices: j['prices'] != null
            ? MensaPrices.fromJson(j['prices'] as Map<String, dynamic>)
            : null,
        additives: (j['additives'] as List<dynamic>).cast<String>(),
        labels: MensaLabels.fromJson(j['labels'] as Map<String, dynamic>),
      );
}

class MensaCategory {
  const MensaCategory({required this.name, required this.meals});

  final String name;
  final List<MensaMeal> meals;

  Map<String, dynamic> toJson() => {
        'name': name,
        'meals': meals.map((m) => m.toJson()).toList(),
      };

  factory MensaCategory.fromJson(Map<String, dynamic> j) => MensaCategory(
        name: j['name'] as String,
        meals: (j['meals'] as List<dynamic>)
            .map((m) => MensaMeal.fromJson(m as Map<String, dynamic>))
            .toList(),
      );
}

class MensaDay {
  const MensaDay({
    required this.date,
    required this.weekday,
    required this.mensa,
    required this.categories,
  });

  static const mensaName = 'HTW Wilhelminenhof';

  /// ISO date string, e.g. '2026-06-04'
  final String date;

  /// German weekday name, e.g. 'Donnerstag'
  final String weekday;

  final String mensa;
  final List<MensaCategory> categories;

  bool get isEmpty => categories.isEmpty;

  Map<String, dynamic> toJson() => {
        'date': date,
        'weekday': weekday,
        'mensa': mensa,
        'categories': categories.map((c) => c.toJson()).toList(),
      };

  factory MensaDay.fromJson(Map<String, dynamic> j) => MensaDay(
        date: j['date'] as String,
        weekday: j['weekday'] as String,
        mensa: j['mensa'] as String,
        categories: (j['categories'] as List<dynamic>)
            .map((c) => MensaCategory.fromJson(c as Map<String, dynamic>))
            .toList(),
      );
}

class MensaFetchException implements Exception {
  const MensaFetchException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => cause != null ? '$message: $cause' : message;
}

/// Fetches and parses the daily Speiseplan from stw.berlin for
/// Mensa HTW Wilhelminenhof (resources_id 319).
class MensaService {
  static const _endpoint =
      'https://www.stw.berlin/xhr/speiseplan-wochentag.html';
  static const _resourcesId = '319';
  static const _userAgent =
      'Mozilla/5.0 (compatible; HTW Center/0.1; '
      '+https://github.com/endermen9932/htw_center)';

  Future<MensaDay> fetchDay(DateTime date) async {
    final dateStr = _fmtDate(date);
    final postBody = 'resources_id=$_resourcesId&date=$dateStr&week=';
    final html = await fetch.postMensaHtml(
      _endpoint,
      postBody,
      userAgent: _userAgent,
      proxyBase: kProxyBase,
    );
    return _parse(html, dateStr);
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  MensaDay _parse(String htmlBody, String dateStr) {
    final doc = html_parser.parse(htmlBody);

    final boldSpan = doc.querySelector('span.bold');
    final weekday = boldSpan != null
        ? boldSpan.text.split(',').first.trim()
        : '';

    final wrappers =
        doc.querySelectorAll('div.container-fluid.splGroupWrapper');
    if (wrappers.isEmpty) {
      return MensaDay(
        date: dateStr,
        weekday: weekday,
        mensa: MensaDay.mensaName,
        categories: const [],
      );
    }

    final categories = <MensaCategory>[];
    for (final wrapper in wrappers) {
      final name = _parseCategoryName(wrapper);
      final meals =
          wrapper.querySelectorAll('div.row.splMeal').map(_parseMeal).toList();
      if (meals.isNotEmpty) {
        categories.add(MensaCategory(name: name, meals: meals));
      }
    }

    return MensaDay(
      date: dateStr,
      weekday: weekday,
      mensa: MensaDay.mensaName,
      categories: categories,
    );
  }

  String _parseCategoryName(Element wrapper) {
    final row = wrapper.querySelector('.row:not(.splMeal)');
    if (row == null) return '';
    return row.text
        .split('\n')
        .map((l) => l.trim())
        .firstWhere((l) => l.isNotEmpty, orElse: () => '');
  }

  // Additivcodes (z.B. "1, 2, A") am Namensanfang entfernen.
  static final _additivPrefix =
      RegExp(r'^(?:[0-9][a-z]?|[A-Z]{1,2})(?:,\s*(?:[0-9][a-z]?|[A-Z]{1,2}))*\s+');

  MensaMeal _parseMeal(Element el) {
    final rawName = el.querySelector('.bold')?.text.trim() ?? '';
    final name    = rawName.replaceFirst(_additivPrefix, '');

    MensaPrices? prices;
    final priceEl = el.querySelector('.col-xs-12.col-md-3');
    if (priceEl != null) {
      final m =
          RegExp(r'€\s*([\d,]+)/([\d,]+)/([\d,]+)').firstMatch(priceEl.text);
      if (m != null) {
        prices = MensaPrices(
          student: _price(m.group(1)!),
          staff: _price(m.group(2)!),
          guest: _price(m.group(3)!),
        );
      }
    }

    final kennz = el.attributes['data-kennz'] ?? '';
    final additives = kennz.isEmpty
        ? const <String>[]
        : kennz
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();

    bool vegetarian = false, vegan = false;
    String? sustainability, co2Rating, h2oRating;

    for (final img in el.querySelectorAll('img.splIcon')) {
      final src = img.attributes['src'] ?? '';
      if (src.contains('icons/1.png')) vegetarian = true;
      if (src.contains('icons/15.png')) vegan = true;
      if (src.contains('ampel_gruen')) sustainability = 'green';
      if (src.contains('ampel_gelb')) sustainability = 'yellow';
      if (src.contains('ampel_rot')) sustainability = 'red';
      final co2 = RegExp(r'CO2_bewertung_([A-Z])').firstMatch(src);
      if (co2 != null) co2Rating = co2.group(1);
      final h2o = RegExp(r'H2O_bewertung_([A-Z])').firstMatch(src);
      if (h2o != null) h2oRating = h2o.group(1);
    }

    return MensaMeal(
      name: name,
      prices: prices,
      additives: additives,
      labels: MensaLabels(
        vegetarian: vegetarian,
        vegan: vegan,
        sustainability: sustainability,
        co2Rating: co2Rating,
        h2oRating: h2oRating,
      ),
    );
  }

  double _price(String s) => double.tryParse(s.replaceAll(',', '.')) ?? 0.0;
}
