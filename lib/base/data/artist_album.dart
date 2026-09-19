import 'package:lpinyin/lpinyin.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/data/library.dart';
import 'package:sylvakru/base/data/setting.dart';
import 'package:sylvakru/base/services/picture_service.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/base/utils/metadata_utils.dart';
import 'package:sylvakru/layer/layers_manager.dart';

final artistAlbumManager = ArtistAlbumManager();

class ArtistAlbumManager {
  List<Artist> artistList = [];
  Map<String, Artist> artistMap = {};

  List<Album> albumList = [];
  // streamSoure will has duplicate name album
  Map<String, Album> albumMap = {};
  final updateNotifier = ValueNotifier(0);

  bool done = false;

  ArtistAlbumManager() {
    artistsIsAscendingNotifier.addListener(() {
      sortArtists();
      updateNotifier.value++;
    });
    albumsIsAscendingNotifier.addListener(() {
      sortAlbums();
      updateNotifier.value++;
    });
  }

  List<ArtistAlbumBase> getArtistAlbumList(bool isArtist) {
    return isArtist ? artistList : albumList;
  }

  ValueNotifier<bool> getRandomizeNotifier(bool isArtist) {
    return isArtist ? artistsRandomizeNotifier : albumsRandomizeNotifier;
  }

  ValueNotifier<bool> getIsAscendingNotifier(bool isArtist) {
    return isArtist ? artistsIsAscendingNotifier : albumsIsAscendingNotifier;
  }

  ValueNotifier<bool> getUseLargePictureNotifier(bool isArtist) {
    return isArtist
        ? artistsUseLargePictureNotifier
        : albumsUseLargePictureNotifier;
  }

  void classify() async {
    for (final song in library.songList) {
      _processSong(song);
    }

    sortArtists();
    sortAlbums();

    for (final album in albumList) {
      album.sort();
    }

    for (final artist in artistList) {
      artist.combineAlbums();
    }

    done = true;
    updateNotifier.value++;
  }

  void _processSong(MyAudioMetadata song) {
    final albumName = getAlbum(song);

    Album? album = albumMap[albumName];
    if (album == null) {
      album = Album(name: albumName);
      albumList.add(album);
      albumMap[albumName] = album;
    }

    if (song.year != null && album.year == null) {
      album.year = song.year;
    }

    album.songList.add(song);

    for (String artistName in getArtists(getArtist(song))) {
      Artist? artist = artistMap[artistName];
      if (artist == null) {
        artist = Artist(name: artistName);
        artistList.add(artist);
        artistMap[artistName] = artist;
      }
      artist.albumSet.add(album);
    }
  }

  void sortArtists() {
    artistList.sort((a, b) {
      if (artistsIsAscendingNotifier.value) {
        return a.compareName.compareTo(b.compareName);
      } else {
        return b.compareName.compareTo(a.compareName);
      }
    });
  }

  void sortAlbums() {
    albumList.sort((a, b) {
      if (albumsIsAscendingNotifier.value) {
        return a.compareName.compareTo(b.compareName);
      } else {
        return b.compareName.compareTo(a.compareName);
      }
    });
  }

  void updateArtistAlbum() {
    layersManager.clearArtistAlbum();
    clear();
    classify();
  }

  void clear() {
    artistList.clear();
    albumList.clear();
    artistMap.clear();
    albumMap.clear();
    done = false;
  }
}

abstract class ArtistAlbumBase {
  final String name;
  late final String compareName;

  final List<MyAudioMetadata> songList = [];

  final bool isArtist;

  MyPicture get picture => songList.first.picture;

  ArtistAlbumBase({required this.name, required this.isArtist}) {
    compareName = PinyinHelper.getPinyinE(name);
  }

  bool get isEmpty => songList.isEmpty;

  int get totalCount => songList.length;
}

class Artist extends ArtistAlbumBase {
  Artist({required super.name}) : super(isArtist: true);

  Set<Album> albumSet = {};

  List<Album> albumList = [];

  final changeNotifier = ValueNotifier(0);

  void combineAlbums() {
    albumSet.removeWhere((album) => album.isEmpty);
    albumList = albumSet.toList();
    albumList.sort((a, b) {
      int aYear = a.year ?? 9999;
      int bYear = b.year ?? 9999;
      final yearCompre = aYear.compareTo(bYear);
      if (yearCompre != 0) {
        return yearCompre;
      }
      return a.compareName.compareTo(b.compareName);
    });

    for (final album in albumList) {
      for (final song in album.songList) {
        if (getArtist(song).contains(name)) {
          songList.add(song);
        }
      }
    }
  }
}

class Album extends ArtistAlbumBase {
  Album({required super.name}) : super(isArtist: false);

  int? year;

  int _sort(MyAudioMetadata a, MyAudioMetadata b) {
    final discA = a.disc ?? 9999;
    final discB = b.disc ?? 9999;

    final discCompare = discA.compareTo(discB);
    if (discCompare != 0) return discCompare;

    final trackA = a.track ?? 9999;
    final trackB = b.track ?? 9999;

    return trackA.compareTo(trackB);
  }

  void sort() {
    songList.sort((a, b) => _sort(a, b));
  }
}
