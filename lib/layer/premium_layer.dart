import 'package:flutter/material.dart';
import 'package:smooth_corner/smooth_corner.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/asset_images.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/services/iap_service.dart';
import 'package:sylvakru/base/services/interaction.dart';
import 'package:sylvakru/base/utils/media_query.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';
import 'package:sylvakru/landscape_view/title_bar.dart';
import 'package:sylvakru/layer/layers_manager.dart';
import 'package:sylvakru/layer/settings_layer.dart';
import 'package:sylvakru/portrait_view/custom_appbar_leading.dart';

class PremiumLayer extends StatefulWidget {
  const PremiumLayer({super.key});

  @override
  State<StatefulWidget> createState() => _PremiumLayerState();
}

class _PremiumLayerState extends State<PremiumLayer> {
  final IAPService _iapService = IAPService();
  final Set<String> _productIds = {'com.afalphy.sylvakru.pro_lifetime'};
  bool isProcessing = false;

  @override
  void initState() {
    super.initState();
    _iapService.initialize();
    _iapService.loadProducts(_productIds);
    _iapService.onMessage = (msg) {
      showCenterMessage(context, msg);
    };

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _iapService.l10n = AppLocalizations.of(context);
    });
  }

  @override
  void dispose() {
    _iapService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isPortrait(context)) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: customAppBarLeading(context, label: 'settings'),

          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
        ),
        body: premiumContent(context),
      );
    }

    return ValueListenableBuilder<bool>(
      valueListenable: settingsVisibleNotifier,
      builder: (context, visible, child) {
        return Opacity(
          opacity: visible ? 0 : 1,
          child: Column(
            children: [
              TitleBar(backToRoot: () => layersManager.popDetail('settings')),
              Expanded(child: premiumContent(context)),
            ],
          ),
        );
      },
    );
  }

  Widget premiumContent(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 500),
      child: ValueListenableBuilder(
        valueListenable: buttonColor.valueNotifier,
        builder: (context, value, child) {
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              ImageIcon(premiumImage, size: 72),

              const SizedBox(height: 8),

              Text(
                l10n.premiumFeatures,
                textAlign: TextAlign.center,
                style: .new(fontSize: 24, fontWeight: .bold),
              ),

              const SizedBox(height: 8),

              Text(l10n.premiumDescription, textAlign: TextAlign.center),

              const SizedBox(height: 16),

              ValueListenableBuilder(
                valueListenable: isPremiumNotifier,
                builder: (context, isPremium, child) {
                  return Column(
                    children: [
                      GestureDetector(
                        onTap: () async {
                          if (isPremium | isProcessing) {
                            return;
                          }
                          isProcessing = true;
                          if (await _iapService.checkAvailability()) {
                            await _iapService.buyProduct();
                          }
                          await Future.delayed(Duration(milliseconds: 500));
                          isProcessing = false;
                        },
                        child: Card(
                          color: buttonColor.value,
                          shadowColor: mainPageThemeNotifier.value == .vivid
                              ? Colors.black.withAlpha(10)
                              : mainPageThemeNotifier.value == .dark
                              ? Colors.white
                              : null,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: SmoothRectangleBorder(
                            smoothness: 1,
                            borderRadius: .circular(10),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              mainAxisAlignment: .center,
                              children: [
                                if (isPremium) ...[
                                  const Icon(Icons.check_circle, size: 20),
                                  const SizedBox(width: 8),
                                ],
                                Text(
                                  isPremium
                                      ? l10n.alreadyPremium
                                      : l10n.unlockPremium,
                                  style: .new(fontSize: 16, fontWeight: .bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (!isPremium) ...[
                        const SizedBox(height: 8),

                        GestureDetector(
                          onTap: () async {
                            if (isProcessing) {
                              return;
                            }
                            isProcessing = true;
                            await _iapService.restorePurchases();
                            await Future.delayed(Duration(milliseconds: 500));
                            isProcessing = false;
                          },
                          child: Card(
                            color: buttonColor.value,
                            shadowColor: mainPageThemeNotifier.value == .vivid
                                ? Colors.black.withAlpha(10)
                                : mainPageThemeNotifier.value == .dark
                                ? Colors.white
                                : null,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: SmoothRectangleBorder(
                              smoothness: 1,
                              borderRadius: .circular(10),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Center(
                                child: Text(
                                  l10n.restorePurchase,
                                  style: .new(fontSize: 16, fontWeight: .bold),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),

              const SizedBox(height: 32),

              Text(
                l10n.whatPremiumContains,
                style: .new(fontWeight: .bold, fontSize: 16),
              ),

              const SizedBox(height: 12),

              FeatureCard(
                icon: ImageIcon(themeImage, size: 30),
                title: l10n.theme,
                description: l10n.themeDescription,
              ),

              FeatureCard(
                icon: ImageIcon(fontImage, size: 30),
                title: l10n.fonts,
                description: l10n.fontDescription,
              ),

              FeatureCard(
                icon: ImageIcon(equalizerImage, size: 30),
                title: l10n.equalizer,
                description: l10n.equalizerDescription,
              ),

              FeatureCard(
                icon: ImageIcon(futurePremiumImage, size: 30),
                title: l10n.futurePremium,
                description: l10n.futurePremiumDescription,
              ),
              const SizedBox(height: 90),
            ],
          );
        },
      ),
    );
  }
}

class FeatureCard extends StatelessWidget {
  final Widget icon;
  final String title;
  final String description;

  const FeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  final descriptionStyle = const TextStyle(height: 1.4);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: buttonColor.value,
      shadowColor: mainPageThemeNotifier.value == .vivid
          ? Colors.black.withAlpha(10)
          : mainPageThemeNotifier.value == .dark
          ? Colors.white
          : null,
      margin: const EdgeInsets.only(bottom: 12),
      shape: SmoothRectangleBorder(smoothness: 1, borderRadius: .circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            icon,

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: .new(fontWeight: .bold, fontSize: 16)),

                  const SizedBox(height: 4),

                  Text(description, style: descriptionStyle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
