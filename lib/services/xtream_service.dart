import 'package:dio/dio.dart';
import '../models/channel.dart';
import '../utils/logger.dart';

class XtreamService {
  final Dio _dio = Dio();

  String _baseUrl = '';
  String _username = '';
  String _password = '';

  void setCredentials({
    required String url,
    required String username,
    required String password,
  }) {
    _baseUrl = url;
    _username = username;
    _password = password;
  }

  String get _apiBase =>
      '$_baseUrl/player_api.php?username=$_username&password=$_password';

  // Verificar credenciales
  Future<bool> login() async {
    try {
      final response = await _dio.get('$_apiBase&action=get_live_categories');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Obtener categorías
  Future<List<XtreamCategory>> getCategories() async {
    try {
      final response = await _dio.get('$_apiBase&action=get_live_categories');
      final List data = response.data;
      return data.map((e) => XtreamCategory.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  // Obtener canales (todos o por categoría)
  Future<List<XtreamChannel>> getChannels({String? categoryId}) async {
    try {
      String url = '$_apiBase&action=get_live_streams';
      // '__all__' significa "todos", no agregar category_id al URL
      if (categoryId != null && categoryId != '__all__') {
        url += '&category_id=$categoryId';
      }
      final response = await _dio.get(url);
      final List data = response.data;
      return data.map((e) => XtreamChannel.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  // Construir URL del stream
  // Formato .ts (MPEG-TS) - más directo para IPTV
  String getStreamUrl(int streamId) {
    return '$_baseUrl/live/$_username/$_password/$streamId.ts';
  }

  // Categorías VOD
  Future<List<XtreamCategory>> getVodCategories() async {
    try {
      String url = '$_apiBase&action=get_vod_categories';
      logger.d('VOD CATEGORIES REQUEST: $url');
      final response = await _dio.get(url);
      final List data = response.data;
      logger.d('VOD CATEGORIES RESPONSE: ${data.length} categories');
      for (var cat in data) {
        logger.d('   - ${cat['category_name']} (ID: ${cat['category_id']})');
      }
      return data.map((e) => XtreamCategory.fromJson(e)).toList();
    } catch (e) {
      logger.e('VOD CATEGORIES ERROR: $e');
      return [];
    }
  }

  // Streams VOD
  Future<List<VodStream>> getVodStreams({String? categoryId}) async {
    try {
      String url = '$_apiBase&action=get_vod_streams';
      // '__all__' significa "todas", no agregar category_id al URL
      if (categoryId != null && categoryId != '__all__') {
        url += '&category_id=$categoryId';
      }
      logger.d('VOD REQUEST [$categoryId]: $url');
      final response = await _dio.get(url);
      final List data = response.data;
      logger.d(
        'VOD RESPONSE [$categoryId]: ${data.length} items received from API',
      );

      if (data.isEmpty) {
        logger.d('VOD EMPTY [$categoryId]');
        return [];
      }

      // Parsear y contar cuántos son válidos
      final List<VodStream> streams = [];
      int parseErrors = 0;
      for (var item in data) {
        try {
          streams.add(VodStream.fromJson(item));
        } catch (e) {
          parseErrors++;
        }
      }

      logger.d(
        'VOD PARSED [$categoryId]: ${streams.length} items ($parseErrors errors)',
      );
      return streams;
    } catch (e) {
      logger.e('VOD ERROR: $e');
      return [];
    }
  }

  // Categorías Series
  Future<List<XtreamCategory>> getSeriesCategories() async {
    try {
      String url = '$_apiBase&action=get_series_categories';
      logger.d('SERIES CATEGORIES REQUEST: $url');
      final response = await _dio.get(url);
      final List data = response.data;
      logger.d('SERIES CATEGORIES RESPONSE: ${data.length} categories');
      for (var cat in data) {
        logger.d('   - ${cat['category_name']} (ID: ${cat['category_id']})');
      }
      return data.map((e) => XtreamCategory.fromJson(e)).toList();
    } catch (e) {
      logger.e('SERIES CATEGORIES ERROR: $e');
      return [];
    }
  }

  // Series
  Future<List<Series>> getSeries({String? categoryId}) async {
    try {
      String url = '$_apiBase&action=get_series';
      // '__all__' significa "todas", no agregar category_id al URL
      if (categoryId != null && categoryId != '__all__') {
        url += '&category_id=$categoryId';
      }
      logger.d('SERIES REQUEST: $url');
      logger.d('SERIES categoryId: $categoryId');
      final response = await _dio.get(url);
      final List data = response.data;
      logger.d('SERIES RESPONSE: ${data.length} items');
      if (data.isEmpty) {
        logger.d('SERIES EMPTY for categoryId: $categoryId');
      }
      return data.map((e) => Series.fromJson(e)).toList();
    } catch (e) {
      logger.e('SERIES ERROR: $e');
      return [];
    }
  }

  // Episodios de una serie
  Future<Map<String, List<SeriesEpisode>>> getSeriesEpisodes(
    int seriesId,
  ) async {
    try {
      final response = await _dio.get(
        '$_apiBase&action=get_series_info&series_id=$seriesId',
      );
      final episodes = response.data['episodes'] as Map<String, dynamic>? ?? {};
      return episodes.map((season, list) {
        final epList = (list as List)
            .map((e) => SeriesEpisode.fromJson(e))
            .toList();
        return MapEntry(season, epList);
      });
    } catch (e) {
      return {};
    }
  }

  // URL de VOD
  String getVodUrl(int streamId, String extension) {
    return '$_baseUrl/movie/$_username/$_password/$streamId.$extension';
  }

  // URL de episodio
  String getEpisodeUrl(int episodeId, String extension) {
    return '$_baseUrl/series/$_username/$_password/$episodeId.$extension';
  }
}
