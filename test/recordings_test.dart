import 'dart:io';
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
}
