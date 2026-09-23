import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/services/logger.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';
import 'package:webview_flutter/webview_flutter.dart';

class FeiniuLoginWidget extends StatefulWidget {
  final Uri loginUrl;
  final String state;

  const FeiniuLoginWidget({
    super.key,
    required this.loginUrl,
    required this.state,
  });

  @override
  State<FeiniuLoginWidget> createState() => _FeiniuLoginWidgetState();
}

class _FeiniuLoginWidgetState extends State<FeiniuLoginWidget> {
  late final WebViewController controller;
  bool loading = true;
  bool failed = false;
  bool completed = false;

  @override
  void initState() {
    super.initState();
    controller = WebViewController();
    initialize();
  }

  Future<void> initialize() async {
    try {
      final redirectUri = Uri.parse(
        widget.loginUrl.queryParameters['redirect_uri']!,
      );
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (request.isMainFrame &&
                uri?.scheme == redirectUri.scheme &&
                uri?.host == redirectUri.host &&
                uri?.port == redirectUri.port &&
                uri?.path == redirectUri.path) {
              if (!completed && mounted) {
                completed = true;
                Navigator.pop(
                  context,
                  uri?.queryParameters['state'] == widget.state
                      ? uri?.queryParameters['code']
                      : null,
                );
              }
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageFinished: (_) {
            if (mounted && !completed) setState(() => loading = false);
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true && mounted && !completed) {
              setState(() => failed = true);
            }
          },
        ),
      );
      if (widget.loginUrl.host.endsWith('.fnos.net')) {
        await WebViewCookieManager().setCookie(
          WebViewCookie(
            name: 'mode',
            value: 'relay',
            domain: widget.loginUrl.host,
          ),
        );
      }
      if (mounted && !completed) await controller.loadRequest(widget.loginUrl);
    } catch (e) {
      logger.output(
        '[FeiniuClient] Authorization view failed: ${e.runtimeType}',
      );
      if (mounted && !completed) setState(() => failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopScope<String>(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) completed = true;
      },
      child: Dialog(
        child: SizedBox(
          width: 700,
          height: 600,
          child: Column(
            children: [
              Row(
                children: [
                  const SizedBox(width: 20),
                  Expanded(child: Text(l10n.feiniuNasLogin)),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: iconColor.value),
                  ),
                ],
              ),
              Expanded(
                child: failed
                    ? Center(child: Text(l10n.feiniuNasLoginFailed))
                    : Stack(
                        children: [
                          WebViewWidget(controller: controller),
                          if (loading)
                            Center(
                              child: CircularProgressIndicator(
                                color: iconColor.value,
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
