import 'package:particle_music/base/app.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';

String getSourceTypeName(AppLocalizations l10n, SourceType sourceType) {
  switch (sourceType) {
    case .local:
      return l10n.local;
    case .webdav:
      return 'WebDAV';
    case .navidrome:
      return 'Navidrome';
    default:
      return 'Emby';
  }
}

int getSourceTypeBitMask(SourceType sourceType) {
  switch (sourceType) {
    case .local:
      return 1;
    case .webdav:
      return 2;
    case .navidrome:
      return 4;
    default:
      return 8;
  }
}
