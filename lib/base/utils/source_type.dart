import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/asset_images.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';

String getSourceTypeDisplayName(AppLocalizations l10n, SourceType sourceType) {
  switch (sourceType) {
    case .local:
      return l10n.local;
    case .webdav:
      return 'WebDAV';
    case .navidrome:
      return 'Navidrome';
    case .emby:
      return 'Emby';
    case .feiniu:
      return l10n.feiniuMusic;
  }
}

AssetImage getSourceTypeImage(SourceType sourceType) {
  switch (sourceType) {
    case .local:
      return localImage;
    case .webdav:
      return webdavImage;
    case .navidrome:
      return navidromeImage;
    case .emby:
      return embyImage;
    case .feiniu:
      return feiniuImage;
  }
}
