class XtreamCategory {
  final String categoryId;
  final String categoryName;

  XtreamCategory({required this.categoryId, required this.categoryName});

  factory XtreamCategory.fromJson(Map<String, dynamic> json) {
    return XtreamCategory(
      categoryId: json['category_id'].toString(),
      categoryName: json['category_name'] ?? 'Sin nombre',
    );
  }
}

class XtreamChannel {
  final int streamId;
  final String name;
  final String streamIcon;
  final String categoryId;
  final String streamType;

  XtreamChannel({
    required this.streamId,
    required this.name,
    required this.streamIcon,
    required this.categoryId,
    required this.streamType,
  });

  factory XtreamChannel.fromJson(Map<String, dynamic> json) {
    return XtreamChannel(
      streamId: json['stream_id'] ?? 0,
      name: json['name'] ?? 'Sin nombre',
      streamIcon: json['stream_icon'] ?? '',
      categoryId: json['category_id'].toString(),
      streamType: json['stream_type'] ?? 'live',
    );
  }
}

class VodStream {
  final int streamId;
  final String name;
  final String streamIcon;
  final String categoryId;
  final String containerExtension;
  final String plot;
  final String cast;
  final String director;
  final String genre;
  final String releaseDate;
  final double rating;

  VodStream({
    required this.streamId,
    required this.name,
    required this.streamIcon,
    required this.categoryId,
    required this.containerExtension,
    required this.plot,
    required this.cast,
    required this.director,
    required this.genre,
    required this.releaseDate,
    required this.rating,
  });

  factory VodStream.fromJson(Map<String, dynamic> json) {
    final info = json['movie_data'] ?? json;
    return VodStream(
      streamId: json['stream_id'] ?? 0,
      name: json['name'] ?? 'Sin título',
      streamIcon: json['stream_icon'] ?? '',
      categoryId: json['category_id']?.toString() ?? '',
      containerExtension: json['container_extension'] ?? 'mp4',
      plot: info['plot'] ?? '',
      cast: info['cast'] ?? '',
      director: info['director'] ?? '',
      genre: info['genre'] ?? '',
      releaseDate: info['releasedate'] ?? '',
      rating: double.tryParse(info['rating']?.toString() ?? '0') ?? 0,
    );
  }
}

class Series {
  final int seriesId;
  final String name;
  final String cover;
  final String categoryId;
  final String plot;
  final String cast;
  final String director;
  final String genre;
  final String releaseDate;
  final double rating;

  Series({
    required this.seriesId,
    required this.name,
    required this.cover,
    required this.categoryId,
    required this.plot,
    required this.cast,
    required this.director,
    required this.genre,
    required this.releaseDate,
    required this.rating,
  });

  factory Series.fromJson(Map<String, dynamic> json) {
    return Series(
      seriesId: json['series_id'] ?? 0,
      name: json['name'] ?? 'Sin título',
      cover: json['cover'] ?? '',
      categoryId: json['category_id']?.toString() ?? '',
      plot: json['plot'] ?? '',
      cast: json['cast'] ?? '',
      director: json['director'] ?? '',
      genre: json['genre'] ?? '',
      releaseDate: json['releaseDate'] ?? '',
      rating: double.tryParse(json['rating']?.toString() ?? '0') ?? 0,
    );
  }
}

class SeriesEpisode {
  final int id;
  final String title;
  final int episodeNum;
  final int season;
  final String containerExtension;
  final String plot;
  final double rating;
  final String directSource;

  SeriesEpisode({
    required this.id,
    required this.title,
    required this.episodeNum,
    required this.season,
    required this.containerExtension,
    required this.plot,
    required this.rating,
    this.directSource = '',
  });

  factory SeriesEpisode.fromJson(Map<String, dynamic> json) {
    final info = json['info'] as Map<String, dynamic>? ?? {};
    return SeriesEpisode(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      title: json['title'] ?? 'Episodio',
      episodeNum: int.tryParse(json['episode_num']?.toString() ?? '0') ?? 0,
      season: int.tryParse(json['season']?.toString() ?? '1') ?? 1,
      containerExtension: json['container_extension'] ?? 'mp4',
      plot: info['plot'] ?? '',
      rating: double.tryParse(info['rating']?.toString() ?? '0') ?? 0,
      directSource: json['direct_source'] ?? '',
    );
  }
}

/// Grupo personalizado de canales creado por el usuario
class CustomGroup {
  final String id;
  final String name;
  final int colorValue; // Color en formato entero para persistencia
  final List<int> channelIds; // IDs de los canales que pertenecen al grupo
  final DateTime createdAt;

  CustomGroup({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.channelIds,
    required this.createdAt,
  });

  CustomGroup copyWith({
    String? id,
    String? name,
    int? colorValue,
    List<int>? channelIds,
    DateTime? createdAt,
  }) {
    return CustomGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      channelIds: channelIds ?? this.channelIds,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'colorValue': colorValue,
      'channelIds': channelIds,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CustomGroup.fromJson(Map<String, dynamic> json) {
    return CustomGroup(
      id: json['id'] as String,
      name: json['name'] as String,
      colorValue: json['colorValue'] as int,
      channelIds: (json['channelIds'] as List).cast<int>(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class EpgProgram {
  final String channelId;
  final String channelName;
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime stopTime; // renombrado de endTime a stopTime
  final String? category;
  final String? image;

  EpgProgram({
    required this.channelId,
    required this.channelName,
    required this.title,
    required this.description,
    required this.startTime,
    required this.stopTime,
    this.category,
    this.image,
  });

  int get durationMinutes => stopTime.difference(startTime).inMinutes;

  bool get isNow {
    final now = DateTime.now().toUtc();
    return now.isAfter(startTime) && now.isBefore(stopTime);
  }

  bool get isPast => DateTime.now().toUtc().isAfter(stopTime);
  bool get isUpcoming => DateTime.now().toUtc().isBefore(startTime);

  // Progreso del programa actual (0.0 a 1.0)
  double get progress {
    if (!isNow) return 0;
    final elapsed = DateTime.now().toUtc().difference(startTime).inSeconds;
    final total = durationMinutes * 60;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  String get timeRange {
    String fmt(DateTime dt) {
      final local = dt.toLocal();
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }

    return '${fmt(startTime)} — ${fmt(stopTime)}';
  }
}
