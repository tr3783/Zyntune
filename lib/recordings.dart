import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'date_format.dart';

/// A moment in a recording with a note, e.g. "12:40 — relax the wrist".
class RecordingMarker {
  final int positionMs;
  String note;

  RecordingMarker({required this.positionMs, required this.note});

  Map<String, dynamic> toJson() => {'positionMs': positionMs, 'note': note};

  factory RecordingMarker.fromJson(Map<String, dynamic> json) =>
      RecordingMarker(positionMs: (json['positionMs'] as num?)?.toInt() ?? 0, note: json['note'] as String? ?? '');
}

class Recording {
  final String id;
  final String fileName;
  final DateTime createdAt;
  final int durationMs;
  /// Video recordings are Pro-only, stored on the device but not in iCloud Backup.
  final bool isVideo;
  String title;
  String piece;
  String movement;
  String notes;
  bool favorite;
  List<RecordingMarker> markers;

  Recording({
    required this.id,
    required this.fileName,
    required this.createdAt,
    required this.durationMs,
    required this.title,
    this.isVideo = false,
    this.piece = '',
    this.movement = '',
    this.notes = '',
    this.favorite = false,
    List<RecordingMarker>? markers,
  }) : markers = markers ?? [];

  /// "Piece · Movement", or just the piece.
  String get pieceLabel => movement.isEmpty ? piece : '$piece · $movement';

  Map<String, dynamic> toJson() => {
        'id': id,
        'fileName': fileName,
        'createdAt': createdAt.toIso8601String(),
        'durationMs': durationMs,
        if (isVideo) 'isVideo': true,
        'title': title,
        'piece': piece,
        'movement': movement,
        'notes': notes,
        'favorite': favorite,
        'markers': markers.map((m) => m.toJson()).toList(),
      };

  factory Recording.fromJson(Map<String, dynamic> json) => Recording(
        id: json['id'] as String,
        fileName: json['fileName'] as String,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
        title: json['title'] as String? ?? 'Recording',
        isVideo: json['isVideo'] as bool? ?? false,
        piece: json['piece'] as String? ?? '',
        movement: json['movement'] as String? ?? '',
        notes: json['notes'] as String? ?? '',
        favorite: json['favorite'] as bool? ?? false,
        markers: ((json['markers'] as List?) ?? [])
            .whereType<Map>()
            .map((m) => RecordingMarker.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
      );
}

/// A recording in Recently Deleted, kept for [RecordingStore.trashDays] days.
class TrashedRecording {
  final Recording recording;
  final DateTime deletedAt;

  TrashedRecording(this.recording, this.deletedAt);

  /// Whole days left before it's deleted for good (at least 0).
  int daysLeft(DateTime now) {
    final left = deletedAt.add(const Duration(days: RecordingStore.trashDays)).difference(now);
    return left.isNegative ? 0 : (left.inHours / 24).ceil();
  }

  Map<String, dynamic> toJson() => {...recording.toJson(), 'deletedAt': deletedAt.toIso8601String()};

  factory TrashedRecording.fromJson(Map<String, dynamic> json) =>
      TrashedRecording(Recording.fromJson(json), DateTime.tryParse(json['deletedAt'] as String? ?? '') ?? DateTime.now());
}

/// Recordings live only on this device, in a folder per account:
/// Documents/recordings/<uid>/ with the audio files and an index.json.
/// Keeping them per account keeps them separate on shared devices; the
/// Documents folder is included in the iPhone's iCloud Backup.
class RecordingStore {
  RecordingStore(this.uid, {Directory? baseDir}) : _baseDir = baseDir;

  final String uid;
  final Directory? _baseDir;

  static const freeLimit = 3;

  /// Days a deleted recording stays in Recently Deleted.
  static const trashDays = 7;

  /// Bumped whenever recordings are added, changed or deleted, so screens
  /// showing them can refresh.
  static final changes = ValueNotifier<int>(0);

  Future<Directory> folder() async {
    final base = _baseDir ?? await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/recordings/$uid');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _indexFile() async => File('${(await folder()).path}/index.json');

  /// Newest first. Entries whose audio file is missing are skipped.
  Future<List<Recording>> load() async {
    final file = await _indexFile();
    if (!await file.exists()) return [];
    try {
      final list = (jsonDecode(await file.readAsString()) as List)
          .whereType<Map>()
          .map((m) => Recording.fromJson(Map<String, dynamic>.from(m)))
          .toList();
      final dir = await folder();
      final present = <Recording>[];
      for (final r in list) {
        if (await File('${dir.path}/${r.fileName}').exists()) present.add(r);
      }
      present.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return present;
    } catch (_) {
      return [];
    }
  }

  Future<void> _save(List<Recording> recordings) async {
    final file = await _indexFile();
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(recordings.map((r) => r.toJson()).toList()));
    await tmp.rename(file.path);
  }

  Future<String> pathFor(Recording r) async => '${(await folder()).path}/${r.fileName}';

  /// A new file path to record into.
  Future<String> newFilePath(String id, {String extension = 'm4a'}) async => '${(await folder()).path}/$id.$extension';

  Future<int> count() async => (await load()).length;

  /// Audio recordings count toward the free limit; video is Pro-only.
  Future<int> audioCount() async => (await load()).where((r) => !r.isVideo).length;

  /// Total size of this account's recordings on the device, in bytes.
  Future<int> totalBytes() async {
    var total = 0;
    final dir = await folder();
    await for (final entity in dir.list()) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }

  Future<void> add(Recording recording) async {
    final all = await load();
    all.add(recording);
    await _save(all);
    changes.value++;
  }

  Future<void> update(Recording recording) async {
    final all = await load();
    final i = all.indexWhere((r) => r.id == recording.id);
    if (i == -1) return;
    all[i] = recording;
    await _save(all);
    changes.value++;
  }

  Future<void> delete(Recording recording) => deleteMany([recording]);

  /// Deletes several recordings at once (one list update).
  Future<void> deleteMany(Iterable<Recording> recordings) async {
    final ids = recordings.map((r) => r.id).toSet();
    if (ids.isEmpty) return;
    for (final r in recordings) {
      final file = File(await pathFor(r));
      if (await file.exists()) await file.delete();
    }
    final all = await load();
    all.removeWhere((r) => ids.contains(r.id));
    await _save(all);
    changes.value++;
  }

  /// Finds recording files that never made it into the list (the app was
  /// closed before Save was tapped) and adds them with a default name.
  /// Files that can't be played (the app was closed mid-recording, so iOS
  /// never finished writing them) are deleted to free the space.
  /// [inUse]: files being recorded or waiting in a Save dialog right now.
  /// Returns how many recordings were recovered.
  Future<int> recoverUnsaved({Set<String> inUse = const {}}) async {
    final dir = await folder();
    final all = await load();
    final known = all.map((r) => r.fileName).toSet();
    final recovered = <Recording>[];
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final name = entity.path.split('/').last;
      final dot = name.lastIndexOf('.');
      if (dot <= 0) continue;
      final ext = name.substring(dot + 1).toLowerCase();
      if (!const {'m4a', 'mov', 'mp4'}.contains(ext)) continue;
      if (known.contains(name) || inUse.contains(entity.path)) continue;
      final durationMs = await Mp4Duration.read(entity.path);
      if (durationMs == null || durationMs <= 0) {
        try {
          await entity.delete();
        } catch (_) {}
        continue;
      }
      final id = name.substring(0, dot);
      final ms = int.tryParse(id);
      final createdAt = ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : await entity.lastModified();
      final isVideo = ext != 'm4a';
      recovered.add(Recording(
        id: id,
        fileName: name,
        createdAt: createdAt,
        durationMs: durationMs,
        isVideo: isVideo,
        title: '${isVideo ? 'Video' : 'Recording'} — ${formatFullDate(createdAt)} (recovered)',
      ));
    }
    if (recovered.isEmpty) return 0;
    await _save([...all, ...recovered]);
    changes.value++;
    return recovered.length;
  }

  // ---- Recently Deleted ----
  // Deleted recordings move to a "trash" folder inside the account's folder
  // (so recovery, which only looks at the top folder, never brings them back)
  // and are removed for good after [trashDays] days.

  Future<Directory> _trashFolder() async {
    final dir = Directory('${(await folder()).path}/trash');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _trashIndex() async => File('${(await _trashFolder()).path}/trash.json');

  Future<List<TrashedRecording>> _readTrash() async {
    final file = await _trashIndex();
    if (!await file.exists()) return [];
    try {
      return (jsonDecode(await file.readAsString()) as List)
          .whereType<Map>()
          .map((m) => TrashedRecording.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeTrash(List<TrashedRecording> items) async {
    final file = await _trashIndex();
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(items.map((t) => t.toJson()).toList()));
    await tmp.rename(file.path);
  }

  Future<String> _trashPathFor(Recording r) async => '${(await _trashFolder()).path}/${r.fileName}';

  /// Moves recordings to Recently Deleted. [now] is for tests.
  Future<void> moveToTrash(Iterable<Recording> recordings, {DateTime? now}) async {
    final moving = recordings.toList();
    if (moving.isEmpty) return;
    final at = now ?? DateTime.now();
    final trash = await _readTrash();
    for (final r in moving) {
      final file = File(await pathFor(r));
      if (await file.exists()) await file.rename(await _trashPathFor(r));
      trash.removeWhere((t) => t.recording.id == r.id);
      trash.add(TrashedRecording(r, at));
    }
    await _writeTrash(trash);
    final ids = moving.map((r) => r.id).toSet();
    final all = await load();
    all.removeWhere((r) => ids.contains(r.id));
    await _save(all);
    changes.value++;
  }

  /// What's in Recently Deleted, most recently deleted first. Anything older
  /// than [trashDays] days is deleted for good first. [now] is for tests.
  Future<List<TrashedRecording>> loadTrash({DateTime? now}) async {
    final at = now ?? DateTime.now();
    final trash = await _readTrash();
    final keep = <TrashedRecording>[];
    var changed = false;
    for (final t in trash) {
      final file = File(await _trashPathFor(t.recording));
      if (t.daysLeft(at) == 0 || !await file.exists()) {
        if (await file.exists()) await file.delete();
        changed = true;
      } else {
        keep.add(t);
      }
    }
    if (changed) await _writeTrash(keep);
    keep.sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
    return keep;
  }

  /// Puts recordings back in the list.
  Future<void> restore(Iterable<TrashedRecording> items) async {
    final restoring = items.toList();
    if (restoring.isEmpty) return;
    final all = await load();
    for (final t in restoring) {
      final file = File(await _trashPathFor(t.recording));
      if (!await file.exists()) continue;
      await file.rename(await pathFor(t.recording));
      all.removeWhere((r) => r.id == t.recording.id);
      all.add(t.recording);
    }
    await _save(all);
    final ids = restoring.map((t) => t.recording.id).toSet();
    await _writeTrash((await _readTrash()).where((t) => !ids.contains(t.recording.id)).toList());
    changes.value++;
  }

  /// Deletes recordings from Recently Deleted for good.
  Future<void> deleteForever(Iterable<TrashedRecording> items) async {
    final ids = items.map((t) => t.recording.id).toSet();
    if (ids.isEmpty) return;
    final trash = await _readTrash();
    for (final t in trash.where((t) => ids.contains(t.recording.id))) {
      final file = File(await _trashPathFor(t.recording));
      if (await file.exists()) await file.delete();
    }
    await _writeTrash(trash.where((t) => !ids.contains(t.recording.id)).toList());
    changes.value++;
  }

  Future<void> emptyTrash() async => deleteForever(await _readTrash());

  /// Space used by Recently Deleted, in bytes.
  Future<int> trashBytes() async {
    var total = 0;
    await for (final entity in (await _trashFolder()).list()) {
      if (entity is File && !entity.path.endsWith('.json')) total += await entity.length();
    }
    return total;
  }

  /// Account deletion: remove every recording for this account.
  Future<void> deleteAll() async {
    final dir = await folder();
    if (await dir.exists()) await dir.delete(recursive: true);
    changes.value++;
  }
}

/// Reads the length of an .m4a/.mov/.mp4 file from its header. Returns null
/// if the file isn't finished (no 'moov' box), e.g. the app was closed while
/// recording.
class Mp4Duration {
  static Future<int?> read(String path) async {
    RandomAccessFile? raf;
    try {
      raf = await File(path).open();
      final length = await raf.length();
      var offset = 0;
      (int, int)? moov;
      while (offset + 8 <= length) {
        final header = await _readAt(raf, offset, 16);
        if (header.length < 8) return null;
        final data = ByteData.sublistView(header);
        var size = data.getUint32(0);
        final type = String.fromCharCodes(header.sublist(4, 8));
        var headerSize = 8;
        if (size == 1) {
          if (header.length < 16) return null;
          size = data.getUint64(8);
          headerSize = 16;
        } else if (size == 0) {
          size = length - offset;
        }
        // A box running past the end of the file: the file was cut short.
        if (size < headerSize || offset + size > length) return null;
        if (type == 'moov') moov = (offset + headerSize, offset + size);
        offset += size;
      }
      if (moov == null) return null;
      return await _durationInMoov(raf, moov.$1, moov.$2);
    } catch (_) {
      return null;
    } finally {
      await raf?.close();
    }
  }

  static Future<int?> _durationInMoov(RandomAccessFile raf, int start, int end) async {
    var offset = start;
    while (offset + 8 <= end) {
      final header = await _readAt(raf, offset, 8);
      if (header.length < 8) return null;
      final size = ByteData.sublistView(header).getUint32(0);
      if (size < 8) return null;
      if (String.fromCharCodes(header.sublist(4, 8)) == 'mvhd') {
        final body = await _readAt(raf, offset + 8, 32);
        final data = ByteData.sublistView(body);
        final version = body[0];
        final int timescale;
        final int duration;
        if (version == 1) {
          timescale = data.getUint32(20);
          duration = data.getUint64(24);
        } else {
          timescale = data.getUint32(12);
          duration = data.getUint32(16);
        }
        if (timescale == 0) return null;
        return duration * 1000 ~/ timescale;
      }
      offset += size;
    }
    return null;
  }

  static Future<Uint8List> _readAt(RandomAccessFile raf, int offset, int count) async {
    await raf.setPosition(offset);
    return raf.read(count);
  }
}
