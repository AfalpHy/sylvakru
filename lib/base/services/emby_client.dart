import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/data/playlist.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/base/services/interaction.dart';
import 'package:sylvakru/base/services/logger.dart';
import 'package:sylvakru/base/services/stream_client.dart';

class EmbyClient extends StreamClient {
  String? accessToken;
  String? userId;

  EmbyClient({
    required super.baseUrl,
    required super.username,
    required super.password,
  }) {
    dio = Dio(
      BaseOptions(
        baseUrl: _normalizeBaseUrl(baseUrl),
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'X-Emby-Authorization':
              'MediaBrowser Client="Sylvakru", Device="Flutter", DeviceId="sylvakru", Version="$versionNumber"',
        },
      ),
    );

    _applyInterceptor();
  }

  static String _normalizeBaseUrl(String url) {
    if (url.endsWith('/')) {
      return url.substring(0, url.length - 1);
    }
    return url;
  }

  void _applyInterceptor() {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (accessToken != null) {
            options.headers['X-Emby-Token'] = accessToken;
          }
          handler.next(options);
        },
      ),
    );
  }

  @protected
  Future<T?> safeRequest<T>(
    Future<Response> Function() request, {
    T? Function(Response response)? parser,
    String errorMessage = '',
    bool showRealError = false,
  }) async {
    try {
      if (accessToken == null && userId == null) {
        final loggedIn = await login();
        if (!loggedIn) {
          return null;
        }
      }

      final response = await request();

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        if (parser != null) {
          return parser(response);
        }
        return response.data as T?;
      }

      return null;
    } on DioException catch (e) {
      logger.output(
        '\n[$runtimeType]\n[error]Dio: ${e.message} (${e.response?.statusCode}\n[data]${e.response?.data.toString()})',
      );

      if (errorMessage.isNotEmpty) {
        showCenterMessage(errorMessage, duration: 3000);
      }

      return null;
    } catch (e) {
      logger.output('\n[$runtimeType]\n[error]$e');

      if (errorMessage.isNotEmpty) {
        showCenterMessage(errorMessage, duration: 3000);
      }

      return null;
    }
  }

  /// Perform login and save user info and default music library
  Future<bool> login() async {
    try {
      final response = await dio.post(
        '/Users/AuthenticateByName',
        data: {'Username': username, 'Pw': password},
      );

      accessToken = response.data['AccessToken'];
      userId = response.data['User']['Id'];

      return true;
    } catch (e) {
      showCenterMessage('[$runtimeType] Login failed');
      logger.output('[$runtimeType] Login failed: $e');
      return false;
    }
  }

  @override
  Future<bool> ping() async {
    final result = await safeRequest<dynamic>(
      () => dio.get('/System/Info/Public'),
      showRealError: true,
    );
    return result != null;
  }

  @override
  Future<int> getSongCount() async {
    final response = await safeRequest<Map<String, dynamic>>(
      () => dio.get('/Items/Counts'),
      parser: (res) => res.data as Map<String, dynamic>?,
    );

    if (response == null) {
      return 0;
    }

    return response['SongCount'] as int? ?? 0;
  }

  @override
  Future<List<MyAudioMetadata>?> getSongs(int size, int offset) async {
    final response = await safeRequest<Map<String, dynamic>>(
      () => dio.get(
        '/Users/$userId/Items',
        queryParameters: {
          'SearchTerm': '',
          'IncludeItemTypes': 'Audio',
          'Recursive': true,
          'StartIndex': offset,
          'Limit': size,
          'Fields':
              'Id,Name,Album,Artists,ArtistItems,AlbumArtist,RunTimeTicks,Genres,ProductionYear,IndexNumber,ParentIndexNumber,MediaSources,UserData',
        },
      ),
      parser: (res) => res.data as Map<String, dynamic>?,
    );

    if (response == null) {
      return null;
    }

    final songs = (normalize(response['Items']) ?? [])
        .map((e) => MyAudioMetadata.fromMap(e, .emby))
        .toList();

    if (songs.isNotEmpty) {
      logger.output('[Emby] Fetched ${offset + songs.length} songs...');
    }

    return songs;
  }

  @override
  Future<List<MyAudioMetadata>?> getStarredSongs() async {
    final response = await safeRequest<Map<String, dynamic>>(
      () => dio.get(
        '/Users/$userId/Items',
        queryParameters: {
          'IncludeItemTypes': 'Audio',
          'Recursive': true,
          'Filters': 'IsFavorite',
        },
      ),
      parser: (res) => res.data as Map<String, dynamic>?,
    );

    if (response == null) {
      return null;
    }

    return (normalize(response['Items']) ?? [])
        .map((e) => MyAudioMetadata.fromMap(e, .emby))
        .toList();
  }

  @override
  Future<bool> updateStarredSongs(List<String> songIds) async {
    final response = await safeRequest<Map<String, dynamic>>(
      () => dio.get(
        '/Users/$userId/Items',
        queryParameters: {
          'IncludeItemTypes': 'Audio',
          'Recursive': true,
          'Filters': 'IsFavorite',
        },
      ),
      parser: (res) => res.data as Map<String, dynamic>?,
    );

    if (response == null) {
      return false;
    }

    final oldSongIds = (normalize(response['Items']) ?? [])
        .map((e) => e['Id'].toString())
        .toList();

    for (final id in oldSongIds) {
      final res = await safeRequest<dynamic>(
        () => dio.delete('/Users/$userId/FavoriteItems/$id'),
      );
      if (res == null) {
        return false;
      }
    }

    for (final id in songIds) {
      final res = await safeRequest<dynamic>(
        () => dio.post('/Users/$userId/FavoriteItems/$id'),
      );
      if (res == null) {
        return false;
      }
    }

    return true;
  }

  @override
  Future<List<MyAudioMetadata>?> getPlaylistSongs(String playlistId) async {
    final response = await safeRequest<Map<String, dynamic>>(
      () => dio.get('/Playlists/$playlistId/Items'),
      parser: (res) => res.data as Map<String, dynamic>?,
    );

    if (response == null) {
      return null;
    }

    return (normalize(response['Items']) ?? [])
        .map((e) => MyAudioMetadata.fromMap(e, .emby))
        .toList();
  }

  @override
  Future<String?> createPlaylist(String name) async {
    final response = await safeRequest<Map<String, dynamic>>(
      () => dio.post(
        '/Playlists',
        queryParameters: {'Name': name, 'Ids': '', 'MediaType': 'Audio'},
      ),
      parser: (res) => res.data as Map<String, dynamic>?,
    );

    return response?['Id']?.toString();
  }

  @override
  Future<bool> deletePlaylist(String playlistId) async {
    return await safeRequest<dynamic>(() => dio.delete('/Items/$playlistId')) !=
        null;
  }

  @override
  Future<List<Playlist>?> getPlaylists() async {
    final response = await safeRequest<Map<String, dynamic>>(
      () => dio.get(
        '/Users/$userId/Items',
        queryParameters: {'IncludeItemTypes': 'Playlist', 'Recursive': true},
      ),
      parser: (res) => res.data as Map<String, dynamic>?,
    );

    return (normalize(
      response?['Items'],
    ))?.map((e) => Playlist(name: e['Name'], id: e['Id'].toString())).toList();
  }

  @override
  Future<bool> updatePlaylistSongs(
    String playlistId,
    List<String> songIds,
  ) async {
    final oldSongs = await getPlaylistSongs(playlistId);
    if (oldSongs == null) {
      return false;
    }

    final response = await safeRequest<Map<String, dynamic>>(
      () => dio.get('/Playlists/$playlistId/Items'),
      parser: (res) => res.data as Map<String, dynamic>?,
    );

    if (response != null) {
      final rawItems = normalize(response['Items']) ?? [];
      final oldEntryIds = rawItems
          .map((e) => e['PlaylistItemId']?.toString() ?? e['Id']?.toString())
          .whereType<String>()
          .toList();

      if (oldEntryIds.isNotEmpty) {
        final res = await safeRequest<dynamic>(
          () => dio.delete(
            '/Playlists/$playlistId/Items',
            queryParameters: {'EntryIds': oldEntryIds.join(',')},
          ),
        );
        if (res == null) {
          return false;
        }
      }
    }

    if (songIds.isNotEmpty) {
      final res = await safeRequest<dynamic>(
        () => dio.post(
          '/Playlists/$playlistId/Items',
          queryParameters: {'Ids': songIds.join(',')},
        ),
      );
      if (res == null) {
        return false;
      }
    }

    return true;
  }

  @override
  String getStreamUrl(String id) {
    return '${dio.options.baseUrl}/Audio/$id/stream'
        '?UserId=$userId&api_key=$accessToken&static=true';
  }

  @override
  Future<Uint8List?> getPictureBytes(String id) async {
    return safeRequest<Uint8List>(
      () => dio.get<List<int>>(
        '/Items/$id/Images/Primary',
        options: Options(responseType: ResponseType.bytes),
      ),
      parser: (res) => Uint8List.fromList(res.data as List<int>),
    );
  }

  @override
  Future<String> getLyricsById(String songId) async {
    final response = await safeRequest<Map<String, dynamic>>(
      () => dio.get('/Audio/$songId/RemoteSearch/Lyrics'),
      parser: (res) => res.data as Map<String, dynamic>?,
    );

    if (response == null) {
      return '';
    }

    final lyricsData = response['Lyrics'];

    if (lyricsData is List) {
      final buffer = StringBuffer();
      for (final line in lyricsData) {
        final startTicks = line['Start'] ?? 0;
        final value = line['Text'] ?? '';

        final totalMs = (startTicks / 10000).round();

        final minute = (totalMs ~/ 60000).toString().padLeft(2, '0');
        final second = ((totalMs % 60000) ~/ 1000).toString().padLeft(2, '0');
        final milli = (totalMs % 1000).toString().padLeft(3, '0');

        buffer.writeln('[$minute:$second.$milli]$value');
      }
      return buffer.toString();
    }

    return '';
  }

  @override
  Future<bool> downloadSong(String songId, String savePath) async {
    try {
      final response = await dio.download(
        '/Items/$songId/Download',
        savePath,
        queryParameters: {'api_key': accessToken},
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      logger.output('[$runtimeType] Download failed: ${e.message}');
      return false;
    } catch (e) {
      logger.output('[$runtimeType] Download failed: $e');
      return false;
    }
  }

  @override
  Future<bool> scrobble(String songId) async {
    final response = await safeRequest<dynamic>(
      () => dio.post('/Users/$userId/PlayedItems/$songId'),
      errorMessage: 'Failed to scrobble',
    );

    return response != null;
  }
}
