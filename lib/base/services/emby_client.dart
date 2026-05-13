import 'dart:typed_data';

import 'package:dio/dio.dart';

EmbyClient? embyClient;

class EmbyClient {
  final String baseUrl;
  final String username;
  final String password;

  late final Dio dio;

  String? accessToken;
  String? userId;

  EmbyClient({
    required this.baseUrl,
    required this.username,
    required this.password,
  }) {
    dio = Dio(
      BaseOptions(
        baseUrl: _normalizeBaseUrl(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'X-Emby-Authorization':
              'MediaBrowser Client="ParticleMusic", Device="Flutter", DeviceId="particle_music", Version="1.0.0"',
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

  /// Login
  Future<void> login() async {
    final response = await dio.post(
      '/Users/AuthenticateByName',
      data: {'Username': username, 'Pw': password},
    );

    accessToken = response.data['AccessToken'];
    userId = response.data['User']['Id'];
  }

  Future<bool> ping() async {
    try {
      final response = await dio.get('/System/Info/Public');

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Get all libraries
  Future<List<dynamic>> getLibraries() async {
    final response = await dio.get('/Users/$userId/Views');

    return response.data['Items'];
  }

  /// Get music libraries only
  Future<List<dynamic>> getMusicLibraries() async {
    final libraries = await getLibraries();

    return libraries.where((e) {
      return e['CollectionType'] == 'music';
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getAllSongs() async {
    final libraries = await getMusicLibraries();
    if (libraries.isEmpty) return [];

    final libraryId = libraries.first['Id'];

    final response = await dio.get(
      '/Users/$userId/Items',
      queryParameters: {
        'ParentId': libraryId,
        'Recursive': true,
        'IncludeItemTypes': 'Audio',

        'Fields':
            'Id,Name,Album,Artists,AlbumArtist,RunTimeTicks,Genres,ProductionYear,IndexNumber,ParentIndexNumber,MediaSources,UserData',
      },
    );

    return (response.data['Items'] as List).cast<Map<String, dynamic>>();
  }

  /// Audio stream URL
  String audioUrl(String songId) {
    return '${dio.options.baseUrl}/Audio/$songId/stream'
        '?UserId=$userId&api_key=$accessToken&static=true';
  }

  Future<Uint8List> getPictureBytes(String itemId) async {
    final response = await dio.get<List<int>>(
      '/Items/$itemId/Images/Primary',
      options: Options(responseType: ResponseType.bytes),
    );

    return Uint8List.fromList(response.data!);
  }

  /// Search
  Future<List<dynamic>> search(String query) async {
    final response = await dio.get(
      '/Users/$userId/Items',
      queryParameters: {
        'SearchTerm': query,
        'Recursive': true,
        'IncludeItemTypes': 'MusicAlbum,Audio,MusicArtist',
      },
    );

    return response.data['Items'];
  }

  Future<void> downloadSong({
    required String itemId,
    required String savePath,
  }) async {
    await dio.download(
      '/Items/$itemId/Download',
      savePath,
      queryParameters: {'api_key': accessToken},
    );
  }
}
