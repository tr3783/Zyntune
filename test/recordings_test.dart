import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyntune/recordings.dart';

void main() {
  late Directory base;

  setUp(() async => base = await Directory.systemTemp.createTemp('zyntune_rec_test'));
  tearDown(() async => base.delete(recursive: true));

  Future<Recording> addRecording(RecordingStore store, String id, {DateTime? at, String piece = ''}) async {
    await File(await store.newFilePath(id)).writeAsString('audio');
    final r = Recording(id: id, fileName: '$id.m4a', createdAt: at ?? DateTime(2026, 10, 16), durationMs: 60000, title: 'Take $id', piece: piece);
    await store.add(r);
    return r;
  }

  test('saves, loads newest first, and counts toward the free limit', () async {
    final store = RecordingStore('amy', baseDir: base);
    await addRecording(store, '1', at: DateTime(2026, 10, 1));
    await addRecording(store, '2', at: DateTime(2026, 10, 3));
    await addRecording(store, '3', at: DateTime(2026, 10, 2));
    final list = await store.load();
    expect(list.map((r) => r.id), ['2', '3', '1']);
    expect(await store.count(), RecordingStore.freeLimit);
  });

  test('each account only sees its own recordings', () async {
    await addRecording(RecordingStore('amy', baseDir: base), 'a');
    await addRecording(RecordingStore('joe', baseDir: base), 'j');
    expect((await RecordingStore('amy', baseDir: base).load()).map((r) => r.id), ['a']);
    expect((await RecordingStore('joe', baseDir: base).load()).map((r) => r.id), ['j']);
  });

  test('markers, favorites and edits are saved', () async {
    final store = RecordingStore('amy', baseDir: base);
    final r = await addRecording(store, '1', piece: 'Sonata');
    r.favorite = true;
    r.title = 'Best take';
    r.markers.add(RecordingMarker(positionMs: 760000, note: 'Relax the wrist'));
    await store.update(r);
    final loaded = (await store.load()).single;
    expect(loaded.favorite, true);
    expect(loaded.title, 'Best take');
    expect(loaded.markers.single.note, 'Relax the wrist');
    expect(loaded.markers.single.positionMs, 760000);
  });

  test('delete removes the file and the entry', () async {
    final store = RecordingStore('amy', baseDir: base);
    final r = await addRecording(store, '1');
    final path = await store.pathFor(r);
    await store.delete(r);
    expect(await File(path).exists(), false);
    expect(await store.load(), isEmpty);
  });

  test('several recordings can be deleted at once', () async {
    final store = RecordingStore('amy', baseDir: base);
    final a = await addRecording(store, 'a');
    final b = await addRecording(store, 'b');
    await addRecording(store, 'c');
    await store.deleteMany([a, b]);
    expect((await store.load()).map((r) => r.id), ['c']);
    expect(File(await store.pathFor(a)).existsSync(), isFalse);
    expect(File(await store.pathFor(b)).existsSync(), isFalse);
  });

  test('entries whose audio file is missing are skipped', () async {
    final store = RecordingStore('amy', baseDir: base);
    final r = await addRecording(store, '1');
    await File(await store.pathFor(r)).delete();
    expect(await store.load(), isEmpty);
  });

  test('deleting an account removes all its recordings', () async {
    final amy = RecordingStore('amy', baseDir: base);
    await addRecording(amy, '1');
    await addRecording(RecordingStore('joe', baseDir: base), 'j');
    await amy.deleteAll();
    expect(await amy.load(), isEmpty);
    expect(await RecordingStore('joe', baseDir: base).count(), 1);
  });

  test('videos are remembered as videos and don\'t count toward the free audio limit', () async {
    final store = RecordingStore('amy', baseDir: base);
    await addRecording(store, 'a1');
    await File(await store.newFilePath('v1', extension: 'mp4')).writeAsString('video');
    await store.add(Recording(id: 'v1', fileName: 'v1.mp4', createdAt: DateTime(2026, 10, 17), durationMs: 1000, title: 'Bowing', isVideo: true));
    final loaded = await store.load();
    expect(loaded.firstWhere((r) => r.id == 'v1').isVideo, true);
    expect(loaded.firstWhere((r) => r.id == 'a1').isVideo, false);
    expect(await store.count(), 2);
    expect(await store.audioCount(), 1);
    expect(await store.totalBytes(), greaterThan(0));
  });

  // A minimal finished .m4a: ftyp, mdat, then moov with an mvhd header.
  Uint8List finishedMp4({required int timescale, required int duration, bool version1 = false}) {
    Uint8List box(String type, List<int> body) {
      final b = ByteData(8 + body.length)..setUint32(0, 8 + body.length);
      final bytes = b.buffer.asUint8List()..setRange(4, 8, type.codeUnits);
      bytes.setRange(8, bytes.length, body);
      return bytes;
    }

    final mvhd = ByteData(version1 ? 32 : 20);
    if (version1) {
      mvhd.setUint8(0, 1);
      mvhd.setUint32(20, timescale);
      mvhd.setUint64(24, duration);
    } else {
      mvhd.setUint32(12, timescale);
      mvhd.setUint32(16, duration);
    }
    return Uint8List.fromList([
      ...box('ftyp', 'M4A '.codeUnits),
      ...box('mdat', List.filled(100, 7)),
      ...box('moov', box('mvhd', mvhd.buffer.asUint8List())),
    ]);
  }

  test('reads the length of a finished file, and rejects an unfinished one', () async {
    final done = File('${base.path}/done.m4a')..writeAsBytesSync(finishedMp4(timescale: 44100, duration: 44100 * 90));
    final long = File('${base.path}/long.mov')..writeAsBytesSync(finishedMp4(timescale: 600, duration: 600 * 5, version1: true));
    final cut = File('${base.path}/cut.m4a')..writeAsBytesSync(finishedMp4(timescale: 44100, duration: 1).sublist(0, 116));
    expect(await Mp4Duration.read(done.path), 90000);
    expect(await Mp4Duration.read(long.path), 5000);
    expect(await Mp4Duration.read(cut.path), isNull);
    // iPhone puts the header first, so a file cut off in the audio data
    // still has one; it must be rejected too.
    final bytes = finishedMp4(timescale: 1000, duration: 5000);
    final moovFirst = File('${base.path}/first.m4a')
      // ftyp (12 bytes), moov (last 36), then mdat (108)
      ..writeAsBytesSync([...bytes.sublist(0, 12), ...bytes.sublist(120), ...bytes.sublist(12, 120)]);
    expect(await Mp4Duration.read(moovFirst.path), 5000);
    final truncated = File('${base.path}/truncated.m4a')..writeAsBytesSync(moovFirst.readAsBytesSync().sublist(0, 80));
    expect(await Mp4Duration.read(truncated.path), isNull);
  });

  test('recovers recordings that were never saved, and removes unplayable ones', () async {
    final store = RecordingStore('amy', baseDir: base);
    await addRecording(store, '1');
    final unsaved = await store.newFilePath('1760600000000');
    File(unsaved).writeAsBytesSync(finishedMp4(timescale: 1000, duration: 30000));
    final video = await store.newFilePath('1760600001000', extension: 'mov');
    File(video).writeAsBytesSync(finishedMp4(timescale: 600, duration: 6000));
    final broken = await store.newFilePath('1760600002000');
    File(broken).writeAsBytesSync([0, 0, 0, 16, ...'ftyp'.codeUnits, 0, 0, 0, 0, 0, 0, 0, 0]);
    final recording = await store.newFilePath('1760600003000');
    File(recording).writeAsBytesSync([1, 2, 3]);

    expect(await store.recoverUnsaved(inUse: {recording}), 2);
    final list = await store.load();
    expect(list.length, 3);
    final audio = list.firstWhere((r) => r.id == '1760600000000');
    expect(audio.durationMs, 30000);
    expect(audio.isVideo, isFalse);
    expect(audio.title, contains('recovered'));
    expect(audio.createdAt, DateTime.fromMillisecondsSinceEpoch(1760600000000));
    expect(list.firstWhere((r) => r.id == '1760600001000').isVideo, isTrue);
    expect(File(broken).existsSync(), isFalse);
    expect(File(recording).existsSync(), isTrue, reason: 'a file still being recorded is left alone');
    // Running again finds nothing new.
    expect(await store.recoverUnsaved(inUse: {recording}), 0);
  });
}
