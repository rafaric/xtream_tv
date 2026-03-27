import 'package:dio/dio.dart';
import '../models/channel.dart';

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
      if (categoryId != null) {
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
  String getStreamUrl(int streamId) {
    return '$_baseUrl/live/$_username/$_password/$streamId.m3u8';
  }

  // Categorías VOD
  Future<List<XtreamCategory>> getVodCategories() async {
    try {
      final response = await _dio.get('$_apiBase&action=get_vod_categories');
      final List data = response.data;
      return data.map((e) => XtreamCategory.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  // Streams VOD
  Future<List<VodStream>> getVodStreams({String? categoryId}) async {
    try {
      String url = '$_apiBase&action=get_vod_streams';
      if (categoryId != null) url += '&category_id=$categoryId';
      final response = await _dio.get(url);
      final List data = response.data;
      return data.map((e) => VodStream.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  // Categorías Series
  Future<List<XtreamCategory>> getSeriesCategories() async {
    try {
      final response = await _dio.get('$_apiBase&action=get_series_categories');
      final List data = response.data;
      return data.map((e) => XtreamCategory.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  // Series
  Future<List<Series>> getSeries({String? categoryId}) async {
    try {
      String url = '$_apiBase&action=get_series';
      if (categoryId != null) url += '&category_id=$categoryId';
      final response = await _dio.get(url);
      final List data = response.data;
      return data.map((e) => Series.fromJson(e)).toList();
    } catch (e) {
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
