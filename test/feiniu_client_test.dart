import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sylvakru/base/app.dart' as app;
import 'package:sylvakru/base/services/feiniu_client.dart';
import 'package:sylvakru/base/services/logger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  late Directory directory;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('feiniu_login_test');
    app.appSupportDir = directory;
    await logger.init();
  });
  tearDownAll(() => directory.delete(recursive: true));

  test('NAS 授权码换取音乐令牌并沿用 FN ID 中继请求头', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final baseUrl = 'http://127.0.0.1:${server.port}';
    server.listen((request) async {
      var data = <String, dynamic>{};
      switch (request.uri.path) {
        case '/music/api/v1/sys/config':
          data = {
            'nasOAuth': {'clientId': 'music-client'},
          };
        case '/music/api/v1/user/auth-login':
          final body = jsonDecode(await utf8.decoder.bind(request).join());
          expect(body['code'], 'authorization-code');
          expect(body['deviceId'], matches(RegExp(r'^[a-f0-9]{32}$')));
          expect(body.containsKey('password'), isFalse);
          data = {'userToken': 'music-token-value'};
        case '/music/api/v1/user/me':
          expect(
            request.headers.value('cookie'),
            'music-token=music-token-value',
          );
        default:
          fail('Unexpected request: ${request.uri.path}');
      }
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'code': 0, 'data': data}));
      await request.response.close();
    });
    final client = FeiniuClient(baseUrl: baseUrl, username: '', password: '');
    final callback = Uri.parse('$baseUrl/music/oauth/result');
    final url = await client.getNasLoginUrl(state: 'login-state');
    expect(url?.path, '/signin');
    expect(url?.queryParameters['client_id'], 'music-client');
    expect(url?.queryParameters['redirect_uri'], callback.toString());
    expect(url?.queryParameters['state'], 'login-state');
    expect(await client.loginWithCode('authorization-code'), isTrue);
    expect(await client.ping(), isTrue);

    final restored = FeiniuClient(
      baseUrl: 'sample-nas',
      username: '',
      password: '',
      token: client.token,
    );
    expect(
      restored.getStreamUrl('song'),
      'https://sample-nas.fnos.net/music/api/v1/track/stream?guid=song',
    );
    expect(
      restored.headers['Cookie'],
      'mode=relay; music-token=music-token-value',
    );
  });

  test('NAS 令牌过期后不使用音乐密码重复登录', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    var requests = 0;
    server.listen((request) async {
      requests++;
      expect(request.uri.path, '/music/api/v1/user/me');
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'code': 120001}));
      await request.response.close();
    });
    final client = FeiniuClient(
      baseUrl: 'http://127.0.0.1:${server.port}',
      username: '',
      password: '',
      token: 'expired-token',
    );
    expect(await client.ping(), isFalse);
    expect(await client.ping(), isFalse);
    expect(client.token, isNull);
    expect(requests, 1);
  });
}
