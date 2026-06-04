import 'dart:convert';
import 'dart:io';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

class MensaPrices {
  const MensaPrices({
    required this.student,
    required this.staff,
    required this.guest,
  });

  final double student;
  final double staff;
  final double guest;
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
}

class MensaCategory {
  const MensaCategory({required this.name, required this.meals});

  final String name;
  final List<MensaMeal> meals;
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
      'Mozilla/5.0 (compatible; htw-center/0.1; '
      '+https://github.com/endermen9932/htw_center)';

  Future<MensaDay> fetchDay(DateTime date) async {
    final dateStr = _fmtDate(date);
    final postBody = 'resources_id=$_resourcesId&date=$dateStr&week=';

    final client = HttpClient()..userAgent = _userAgent;
    try {
      final request = await client.postUrl(Uri.parse(_endpoint));
      request.headers.contentType = ContentType(
        'application',
        'x-www-form-urlencoded',
        charset: 'utf-8',
      );
      request.write(postBody);

      final response = await request.close();
      if (response.statusCode != 200) {
        throw MensaFetchException(
            'Server antwortete mit ${response.statusCode}');
      }

      final html = await _readBody(response);
      return _parse(html, dateStr);
    } on SocketException catch (e) {
      throw MensaFetchException('Netzwerkfehler', cause: e);
    } on HttpException catch (e) {
      throw MensaFetchException('HTTP-Fehler', cause: e);
    } finally {
      client.close();
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<String> _readBody(HttpClientResponse response) async {
    final bytes = <int>[];
    await for (final chunk in response) {
      bytes.addAll(chunk);
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

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

  MensaMeal _parseMeal(Element el) {
    final name = el.querySelector('.bold')?.text.trim() ?? '';

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
