import 'package:xml/xml.dart';
import 'package:dio/dio.dart';
import '../models/channel.dart';

class EpgService {
  final Dio _dio = Dio();

  // Cache para no descargar el XML en cada llamada
  List<EpgProgram>? _cachedPrograms;
  Map<String, String>? _cachedChannelNames; // id → display-name
  DateTime? _cacheTime;

  bool get _isCacheValid =>
      _cachedPrograms != null &&
      _cacheTime != null &&
      DateTime.now().difference(_cacheTime!).inMinutes < 30;

  Future<List<EpgProgram>> getEpg({
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    if (_isCacheValid) return _cachedPrograms!;

    final epgUrl = '$baseUrl/xmltv.php?username=$username&password=$password';

    try {
      final response = await _dio.get(
        epgUrl,
        options: Options(
          responseType: ResponseType.plain,
          receiveTimeout: const Duration(seconds: 60),
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final result = _parseEpgXml(response.data as String);
        _cachedPrograms = result;
        _cacheTime = DateTime.now();
        return result;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Obtener mapa de channel id → display-name
  Future<Map<String, String>> getChannelNames({
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    if (_cachedChannelNames != null) return _cachedChannelNames!;

    // Asegurarse de que el EPG esté cargado
    await getEpg(baseUrl: baseUrl, username: username, password: password);
    return _cachedChannelNames ?? {};
  }

  // Buscar programas por nombre de canal (fuzzy match)
  Future<List<EpgProgram>> getEpgForChannelName({
    required String channelName,
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    final allPrograms = await getEpg(
      baseUrl: baseUrl,
      username: username,
      password: password,
    );
    final channelNames = await getChannelNames(
      baseUrl: baseUrl,
      username: username,
      password: password,
    );

    // Normalizar nombre para comparación
    final normalizedSearch = _normalize(channelName);

    // Encontrar el channel id que mejor coincide con el nombre
    String? bestMatchId;
    int bestScore = 0;

    for (final entry in channelNames.entries) {
      final score = _matchScore(normalizedSearch, _normalize(entry.value));
      if (score > bestScore) {
        bestScore = score;
        bestMatchId = entry.key;
      }
    }

    if (bestMatchId == null || bestScore < 3) return [];

    return allPrograms.where((p) => p.channelId == bestMatchId).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  // Obtener programa actual de un canal por nombre
  Future<EpgProgram?> getCurrentProgram({
    required String channelName,
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    final programs = await getEpgForChannelName(
      channelName: channelName,
      baseUrl: baseUrl,
      username: username,
      password: password,
    );
    final now = DateTime.now().toUtc();
    try {
      return programs.firstWhere(
        (p) => now.isAfter(p.startTime) && now.isBefore(p.stopTime),
      );
    } catch (_) {
      return null;
    }
  }

  // Normalizar nombre para comparación
  String _normalize(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '')
        .replaceAll(RegExp(r'(hd|fhd|uhd|4k|sd|\[.*?\])'), '');
  }

  // Score de coincidencia entre dos strings normalizados
  int _matchScore(String a, String b) {
    if (a == b) return 10;
    if (a.contains(b) || b.contains(a)) return 7;
    // Coincidencia parcial por palabras
    final wordsA = a.split(RegExp(r'\s+'));
    final wordsB = b.split(RegExp(r'\s+'));
    int common = wordsA.where((w) => w.length > 2 && wordsB.contains(w)).length;
    return common;
  }

  List<EpgProgram> _parseEpgXml(String xmlString) {
    final programs = <EpgProgram>[];
    final channelNames = <String, String>{};

    try {
      final document = XmlDocument.parse(xmlString);

      // Parsear canales primero
      for (final ch in document.findAllElements('channel')) {
        final id = ch.getAttribute('id') ?? '';
        final displayName =
            ch.findElements('display-name').firstOrNull?.innerText ?? '';
        final icon =
            ch.findElements('icon').firstOrNull?.getAttribute('src') ?? '';
        if (id.isNotEmpty && displayName.isNotEmpty) {
          channelNames[id] = displayName;
        }
        // Guardar también el icon por channel id
        if (id.isNotEmpty && icon.isNotEmpty) {
          // lo guardamos en el programa más adelante
        }
      }
      _cachedChannelNames = channelNames;

      // Parsear programas
      for (final el in document.findAllElements('programme')) {
        final channelId = el.getAttribute('channel') ?? '';
        final startStr = el.getAttribute('start') ?? '';
        final stopStr = el.getAttribute('stop') ?? '';

        final startTime = _parseXmlTime(startStr);
        final stopTime = _parseXmlTime(stopStr);

        if (startTime == null || stopTime == null) continue;

        final title =
            el.findElements('title').firstOrNull?.innerText ?? 'Sin título';
        final desc = el.findElements('desc').firstOrNull?.innerText ?? '';
        final category = el.findElements('category').firstOrNull?.innerText;
        final image = el.findElements('icon').firstOrNull?.getAttribute('src');

        programs.add(
          EpgProgram(
            channelId: channelId,
            channelName: channelNames[channelId] ?? '',
            title: title,
            description: desc,
            startTime: startTime,
            stopTime: stopTime,
            category: category,
            image: image,
          ),
        );
      }
    } catch (e) {
      // Si falla el parseo devolvemos lista vacía
    }

    return programs;
  }

  DateTime? _parseXmlTime(String timeStr) {
    if (timeStr.length < 14) return null;
    try {
      final year = int.parse(timeStr.substring(0, 4));
      final month = int.parse(timeStr.substring(4, 6));
      final day = int.parse(timeStr.substring(6, 8));
      final hour = int.parse(timeStr.substring(8, 10));
      final minute = int.parse(timeStr.substring(10, 12));
      final second = int.parse(timeStr.substring(12, 14));

      // Parsear offset de timezone si existe (ej: +0000, -0300)
      int offsetMinutes = 0;
      if (timeStr.length >= 20) {
        final sign = timeStr[15] == '-' ? -1 : 1;
        final offsetH = int.tryParse(timeStr.substring(16, 18)) ?? 0;
        final offsetM = int.tryParse(timeStr.substring(18, 20)) ?? 0;
        offsetMinutes = sign * (offsetH * 60 + offsetM);
      }

      return DateTime.utc(
        year,
        month,
        day,
        hour,
        minute,
        second,
      ).subtract(Duration(minutes: offsetMinutes));
    } catch (_) {
      return null;
    }
  }
}
