import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

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

/// Recordings live only on this device, in a folder per account:
/// Documents/recordings/<uid>/ with the audio files and an index.json.
/// Keeping them per account keeps them separate on shared devices; the
/// Documents folder is included in the iPhone's iCloud Backup.
class RecordingStore {
  RecordingStore(this.uid, {Directory? baseDir}) : _baseDir = baseDir;

  final String uid;
  final Directory? _baseDir;

  static const freeLimit = 3;

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

  Future<void> delete(Recording recording) async {
    final file = File(await pathFor(recording));
    if (await file.exists()) await file.delete();
    final all = await load();
    all.removeWhere((r) => r.id == recording.id);
    await _save(all);
    changes.value++;
  }

  /// Account deletion: remove every recording for this account.
  Future<void> deleteAll() async {
    final dir = await folder();
    if (await dir.exists()) await dir.delete(recursive: true);
    changes.value++;
  }
}
