import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:sylvakru/base/data/artist_album.dart';
import 'package:sylvakru/base/data/playlist.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/base/services/logger.dart';
import 'package:sylvakru/base/services/stream_client.dart';

class FeiniuClient extends StreamClient {
  String? _token;
  Future<bool>? _loginFuture;
  final Map<String, String> _coverIds = {};
  late final String _deviceId;

  FeiniuClient({
    required super.baseUrl,
    required super.username,
    required super.password,
  }) {
    final random = Random.secure();
    _deviceId = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    var url = baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    if (!url.endsWith('/music/api/v1')) {
      url += url.endsWith('/music') ? '/api/v1' : '/music/api/v1';
    }
    dio = Dio(
      BaseOptions(
        baseUrl: url,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
      ),
    );
  }

  @override
  Map<String, String> get headers => {
    if (_token != null) 'Cookie': 'music-token=$_token',
  };

  Future<bool> login() async {
    if (_token != null) return true;
    final pending = _loginFuture;
    if (pending != null) return pending;
    final future = _login();
    _loginFuture = future;
    try {
      return await future;
    } finally {
      _loginFuture = null;
    }
  }

  Future<bool> _login() async {
    try {
      final response = await dio.post(
        '/user/password-login',
        data: {
          'username': username.trim(),
          'password': sha256.convert(utf8.encode(password)).toString(),
          'deviceId': _deviceId,
        },
      );
      final body = response.data;
      if (body is! Map || body['code'] != 0) {
        logger.output(
          '[$runtimeType] Login rejected: ${body is Map ? body['code'] : 'invalid response'}',
        );
        return false;
      }
      final data = body['data'];
      _token = data is Map ? data['userToken'] as String? : null;
      if (_token?.isEmpty == true) _token = null;
      return _token?.isNotEmpty == true;
    } on DioException catch (e) {
      logger.output(
        '[$runtimeType] Login failed: ${e.type.name} (${e.response?.statusCode})',
      );
      return false;
    } catch (e) {
      logger.output('[$runtimeType] Login failed: ${e.runtimeType}');
      return false;
    }
  }

  Future<Map<String, dynamic>?> _request(
    String path, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? data,
    bool retry = true,
  }) async {
    if (!await login()) return null;
    final requestToken = _token;
    var expired = false;
    try {
      final response = await dio.request(
        path,
        queryParameters: query,
        data: data,
        options: Options(
          method: data == null ? 'GET' : 'POST',
          headers: headers,
        ),
      );
      final body = response.data;
      if (body is Map && body['code'] == 0) {
        return Map<String, dynamic>.from(body);
      }
      expired = body is Map && body['code'] == 99999;
      if (!expired) {
        logger.output(
          '[$runtimeType] Request rejected: $path (${body is Map ? body['code'] : 'invalid response'})',
        );
      }
    } on DioException catch (e) {
      expired = e.response?.statusCode == 401;
      if (!expired) {
        logger.output(
          '[$runtimeType] Request failed: $path (${e.type.name}, ${e.response?.statusCode})',
        );
      }
    } catch (e) {
      logger.output('[$runtimeType] Request failed: $path (${e.runtimeType})');
    }
    if (expired) {
      if (_token == requestToken) _token = null;
      if (retry) return _request(path, query: query, data: data, retry: false);
    }
    return null;
  }

  @override
  Future<bool> ping() async => await _request('/user/me') != null;

  Future<List<Map<String, dynamic>>?> _list(
    String path, {
    Map<String, dynamic>? query,
    int offset = 0,
    int? size,
  }) async {
    if (offset < 0 || (size != null && size <= 0)) return [];
    final pageSize = size == null ? 500 : min(size, 500);
    var page = offset ~/ pageSize + 1;
    var skip = offset % pageSize;
    final result = <Map<String, dynamic>>[];
    while (true) {
      final response = await _request(
        path,
        query: {...?query, 'page': page, 'size': pageSize},
      );
      final data = response?['data'];
      if (data is! Map || data['list'] is! List) return null;
      final rows = normalize(data['list'])!;
      result.addAll(
        rows.skip(skip).take(size == null ? rows.length : size - result.length),
      );
      if ((size != null && result.length >= size) ||
          rows.isEmpty ||
          data['hasMore'] == false ||
          (data['total'] is num && page * pageSize >= (data['total'] as num)) ||
          (data['hasMore'] != true && rows.length < pageSize)) {
        return result;
      }
      page++;
      skip = 0;
    }
  }

  void _rememberCover(Map<String, dynamic> item) {
    final guid = item['guid'] as String?;
    final coverId = item['coverId'] as String?;
    if (guid != null && item.containsKey('coverId')) {
      _coverIds[guid] = coverId ?? '';
    }
  }

  List<MyAudioMetadata> _songs(
    List<Map<String, dynamic>> rows, {
    bool cache = true,
  }) => rows.map((song) {
    _rememberCover(song);
    final album = song['album'];
    if (album is Map<String, dynamic>) {
      _rememberCover(album);
      final songGuid = song['guid'] as String?;
      final songCoverId = song['coverId'] as String?;
      final albumCoverId = album['coverId'] as String?;
      if (songGuid != null &&
          _coverIds[songGuid]?.isNotEmpty != true &&
          (songCoverId == null || songCoverId.isEmpty) &&
          albumCoverId?.isNotEmpty == true) {
        _coverIds[songGuid] = albumCoverId!;
      }
    }
    for (final artist in normalize(song['artists']) ?? []) {
      _rememberCover(artist);
    }
    return MyAudioMetadata.fromMap(song, .feiniu, cache: cache);
  }).toList();

  Album _album(Map<String, dynamic> item) {
    _rememberCover(item);
    final id = item['guid'] as String;
    final releaseDate = item['releaseDate'] as String?;
    return artistAlbumManager.albumMap.putIfAbsent(
      id,
      () => Album(
        item['name'] as String,
        id: id,
        coverArtId: id,
        year: releaseDate == null ? null : DateTime.tryParse(releaseDate)?.year,
      ),
    );
  }

  @override
  Future<List<MyAudioMetadata>?> getSongs(int size, int offset) async {
    final rows = await _list(
      '/track/list',
      query: {'sort': 'title,asc'},
      size: size,
      offset: offset,
    );
    return rows == null ? null : _songs(rows);
  }

  Future<List<MyAudioMetadata>?> getAllSongs() async {
    final rows = await _list('/track/list', query: {'sort': 'title,asc'});
    return rows == null ? null : _songs(rows, cache: false);
  }

  @override
  Future<List<MyAudioMetadata>?> searchSongs(
    String query,
    int size,
    int offset,
  ) async {
    if (offset < 0 || size <= 0) return [];
    // 搜索接口返回全部匹配项，不按 page/size 分页。
    final response = await _request('/search/track', query: {'q': query});
    final rows = normalize(response?['data']?['list']);
    return rows == null ? null : _songs(rows.skip(offset).take(size).toList());
  }

  Future<MyAudioMetadata?> getSong(String id) async {
    final response = await _request('/track/metadata', query: {'guid': id});
    final data = response?['data'];
    final song = data?['track'];
    return song is Map<String, dynamic>
        ? _songs([
            {...song, 'audioSpec': data['audioSpec'] ?? song['audioSpec']},
          ]).first
        : null;
  }

  @override
  Future<List<Artist>?> getArtistList() async {
    final rows = await _list('/artist/list', query: {'sort': 'name,asc'});
    return rows?.map((item) {
      _rememberCover(item);
      return Artist(
        item['name'] as String,
        id: item['guid'] as String,
        coverArtId: item['guid'] as String,
      );
    }).toList();
  }

  @override
  Future<List<Album>?> getArtistAlbumList(String id) async {
    final rows = await _list(
      '/album/artist-detail/list',
      query: {'artistGUID': id, 'sort': 'name,asc'},
    );
    return rows?.map(_album).toList();
  }

  @override
  Future<List<MyAudioMetadata>?> getArtistSongs(String id) async {
    final rows = await _list(
      '/track/artist-detail/list',
      query: {'artistGUID': id, 'sort': 'title,asc'},
    );
    return rows == null ? null : _songs(rows);
  }

  @override
  Future<List<Album>?> getAlbumList(
    int offset, {
    String type = 'alphabeticalByName',
  }) async {
    final rows = await _list(
      '/album/list',
      query: {'sort': 'name,asc'},
      offset: offset,
      size: 500,
    );
    return rows?.map(_album).toList();
  }

  @override
  Future<Album?> getAlbum(String id) async {
    final response = await _request('/album/detail', query: {'guid': id});
    final data = response?['data'];
    return data is Map<String, dynamic> ? _album(data) : null;
  }

  @override
  Future<List<MyAudioMetadata>?> getAlbumSongs(String id) async {
    final rows = await _list(
      '/track/album-detail/list',
      query: {'albumGUID': id, 'sort': 'trackNo,asc'},
    );
    return rows == null ? null : _songs(rows);
  }

  @override
  Future<List<MyAudioMetadata>?> getStarredSongs() async {
    final rows = await _list('/favorite-track/list');
    return rows == null ? null : _songs(rows);
  }

  @override
  Future<bool> updateStarredSongs(List<String> songIds) async {
    final oldSongs = await getStarredSongs();
    if (oldSongs == null) return false;
    final oldIds = oldSongs.map((song) => song.id).toSet();
    final newIds = songIds.toSet();
    for (final id in oldIds.difference(newIds)) {
      if (await _request('/favorite-track/delete', data: {'trackGUID': id}) ==
          null) {
        return false;
      }
    }
    for (final id in newIds.difference(oldIds)) {
      if (await _request('/favorite-track/create', data: {'trackGUID': id}) ==
          null) {
        return false;
      }
    }
    return true;
  }

  @override
  Future<List<Playlist>?> getPlaylists() async {
    final response = await _request('/playlist/list');
    final rows = normalize(response?['data']?['list']);
    return rows
        ?.map(
          (item) => Playlist(
            name: item['name'] as String,
            id: item['guid'] as String,
          ),
        )
        .toList();
  }

  @override
  Future<String?> createPlaylist(String name) async {
    final response = await _request('/playlist/create', data: {'name': name});
    return response?['data']?['guid'] as String?;
  }

  @override
  Future<bool> deletePlaylist(String playlistId) async =>
      await _request('/playlist/delete', data: {'guid': playlistId}) != null;

  @override
  Future<List<MyAudioMetadata>?> getPlaylistSongs(String playlistId) async {
    final rows = await _list(
      '/track/playlist-detail/list',
      query: {'playlistGUID': playlistId, 'sort': 'trackAddedAt,asc'},
    );
    return rows == null ? null : _songs(rows);
  }

  @override
  Future<bool> updatePlaylistSongs(
    String playlistId,
    List<String> songIds,
  ) async {
    final oldSongs = await getPlaylistSongs(playlistId);
    if (oldSongs == null) return false;
    final oldIds = oldSongs.map((song) => song.id).toSet();
    final newIds = songIds.toSet();
    final removed = oldIds.difference(newIds).toList();
    final added = newIds.difference(oldIds).toList();
    if (removed.isNotEmpty &&
        await _request(
              '/playlist/remove-track',
              data: {'guid': playlistId, 'trackGUIDs': removed},
            ) ==
            null) {
      return false;
    }
    if (added.isNotEmpty &&
        await _request(
              '/playlist/add-track',
              data: {'guid': playlistId, 'trackGUIDs': added},
            ) ==
            null) {
      return false;
    }
    return true;
  }

  @override
  Future<bool> scrobble(String songId) async =>
      await _request(
        '/event/report',
        data: {
          'events': [
            {
              'eventType': 'track_play',
              'occurredAt': DateTime.now().millisecondsSinceEpoch,
              'payload': {'trackGUID': songId},
            },
          ],
        },
      ) !=
      null;

  @override
  Future<Uint8List?> getPictureBytes(String id) async {
    try {
      if (!_coverIds.containsKey(id)) await getSong(id);
      final coverId = _coverIds[id];
      if (coverId == null || coverId.isEmpty) return null;
      final response = await _openResource(
        '/static/cover',
        query: {'coverId': coverId},
      );
      if (response == null) return null;
      final bytes = <int>[];
      await for (final chunk in response.data!.stream) {
        bytes.addAll(chunk);
      }
      return bytes.isEmpty ? null : Uint8List.fromList(bytes);
    } on DioException catch (e) {
      logger.output(
        '[$runtimeType] Cover failed: ${e.type.name} (${e.response?.statusCode})',
      );
      return null;
    } catch (e) {
      logger.output('[$runtimeType] Cover failed: ${e.runtimeType}');
      return null;
    }
  }

  @override
  Future<String> getLyricsById(String songId) async {
    final response = await _request(
      '/lyric/list',
      query: {'trackGUID': songId},
    );
    final data = response?['data'];
    if (data is! Map) return '';
    final lyrics = normalize(data['list']) ?? [];
    lyrics.removeWhere(
      (lyric) =>
          lyric['content'] is! String ||
          (lyric['content'] as String).trim().isEmpty,
    );
    if (lyrics.isEmpty) return '';
    int sourcePriority(dynamic source) => switch (source) {
      1 => 0,
      2 => 1,
      4 => 2,
      _ => 3,
    };
    lyrics.sort((a, b) {
      if (a['guid'] == data['preferred']) return -1;
      if (b['guid'] == data['preferred']) return 1;
      final source = sourcePriority(
        a['source'],
      ).compareTo(sourcePriority(b['source']));
      if (source != 0) return source;
      return (b['updatedAt'] as num? ?? b['createdAt'] as num? ?? 0).compareTo(
        a['updatedAt'] as num? ?? a['createdAt'] as num? ?? 0,
      );
    });
    final timePattern = RegExp(
      r'([\[<])(\d+):(\d{2})(?:[.:](\d{1,3}))?([\]>])',
    );
    final selected = lyrics.first['guid'] == data['preferred']
        ? lyrics.first
        : lyrics.firstWhere(
            (lyric) => timePattern.hasMatch(lyric['content'] as String),
            orElse: () => lyrics.first,
          );
    final offset = (selected['offset'] as num? ?? 0).round();
    // 飞牛的正偏移使歌词提前；规范化时间标签以复用现有 LRC 解析器。
    return (selected['content'] as String).replaceAllMapped(timePattern, (
      match,
    ) {
      final milliseconds = int.parse((match.group(4) ?? '').padRight(3, '0'));
      final start = max(
        0,
        (int.parse(match.group(2)!) * 60 + int.parse(match.group(3)!)) * 1000 +
            milliseconds -
            offset,
      );
      final minute = (start ~/ 60000).toString().padLeft(2, '0');
      final second = (start % 60000 ~/ 1000).toString().padLeft(2, '0');
      final milli = (start % 1000).toString().padLeft(3, '0');
      return '${match.group(1)}$minute:$second.$milli${match.group(5)}';
    });
  }

  @override
  String getStreamUrl(String id) => Uri.parse(
    '${dio.options.baseUrl}/track/stream',
  ).replace(queryParameters: {'guid': id}).toString();

  Future<Response<ResponseBody>?> _openResource(
    String path, {
    required Map<String, dynamic> query,
    bool retry = true,
  }) async {
    if (!await login()) return null;
    final requestToken = _token;
    final response = await dio.get<ResponseBody>(
      path,
      queryParameters: query,
      options: Options(
        responseType: ResponseType.stream,
        headers: headers,
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    final body = response.data;
    if (body == null) return null;
    final contentType =
        response.headers.value('content-type')?.toLowerCase() ?? '';
    var expired = response.statusCode == 401;
    if (contentType.contains('json')) {
      final text = await utf8.decoder.bind(body.stream).join();
      final json = jsonDecode(text);
      expired = expired || (json is Map && json['code'] == 99999);
    } else if (!expired &&
        response.statusCode == 200 &&
        (contentType.startsWith(
              path == '/static/cover' ? 'image/' : 'audio/',
            ) ||
            contentType.startsWith('application/octet-stream'))) {
      return response;
    } else {
      await body.stream.listen(null).cancel();
    }
    if (expired) {
      if (_token == requestToken) _token = null;
      if (retry) {
        return _openResource(path, query: query, retry: false);
      }
    }
    logger.output(
      '[$runtimeType] Resource rejected: $path (${response.statusCode})',
    );
    return null;
  }

  @override
  Future<bool> downloadSong(String songId, String savePath) async {
    try {
      final response = await _openResource(
        '/track/stream',
        query: {'guid': songId},
      );
      if (response == null) return false;
      final file = File(savePath);
      await file.parent.create(recursive: true);
      final output = file.openWrite();
      var received = 0;
      try {
        var checkedContent = false;
        await output.addStream(
          response.data!.stream.map((chunk) {
            received += chunk.length;
            if (!checkedContent && chunk.isNotEmpty) {
              final prefix = utf8
                  .decode(chunk.take(32).toList(), allowMalformed: true)
                  .trimLeft();
              if (prefix.startsWith('{') ||
                  prefix.startsWith('[') ||
                  prefix.startsWith('<')) {
                throw const FormatException('Unexpected text response');
              }
              checkedContent = true;
            }
            return chunk;
          }),
        );
        await output.flush();
      } finally {
        await output.close();
      }
      final expectedLength = int.tryParse(
        response.headers.value('content-length') ?? '',
      );
      return received > 0 &&
          (expectedLength == null || received == expectedLength);
    } on DioException catch (e) {
      logger.output(
        '[$runtimeType] Download failed: ${e.type.name} (${e.response?.statusCode})',
      );
      return false;
    } catch (e) {
      logger.output('[$runtimeType] Download failed: ${e.runtimeType}');
      return false;
    }
  }
}
