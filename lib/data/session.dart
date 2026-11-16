import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../core/dsp.dart';

/// One accelerometer reading with gravity removed, in m/s2.
class Sample {
  const Sample(this.tMs, this.x, this.y, this.z);

  /// Milliseconds since the start of the recording.
  final double tMs;
  final double x;
  final double y;
  final double z;

  double get mag => magnitude(x, y, z);
}

/// Summary of a saved recording, stored next to its CSV.
class SessionMeta {
  const SessionMeta({
    required this.id,
    required this.name,
    required this.startedAt,
    required this.durationMs,
    required this.sampleRate,
    required this.count,
    required this.peak,
    required this.rms,
    required this.dominantHz,
  });

  /// Epoch milliseconds when the recording started; also the file name.
  final int id;
  final String name;
  final DateTime startedAt;
  final double durationMs;
  final double sampleRate;
  final int count;
  final double peak;
  final double rms;
  final double? dominantHz;

  Intensity get intensity => intensityOf(rms);

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'durationMs': durationMs,
        'sampleRate': sampleRate,
        'count': count,
        'peak': peak,
        'rms': rms,
        'dominantHz': dominantHz,
      };

  factory SessionMeta.fromJson(Map<String, dynamic> j) => SessionMeta(
        id: (j['id'] as num).toInt(),
        name: j['name'] as String? ?? 'Session',
        startedAt: DateTime.fromMillisecondsSinceEpoch((j['id'] as num).toInt()),
        durationMs: (j['durationMs'] as num).toDouble(),
        sampleRate: (j['sampleRate'] as num).toDouble(),
        count: (j['count'] as num).toInt(),
        peak: (j['peak'] as num).toDouble(),
        rms: (j['rms'] as num).toDouble(),
        dominantHz: (j['dominantHz'] as num?)?.toDouble(),
      );

  SessionMeta copyWith({String? name}) => SessionMeta(
        id: id,
        name: name ?? this.name,
        startedAt: startedAt,
        durationMs: durationMs,
        sampleRate: sampleRate,
        count: count,
        peak: peak,
        rms: rms,
        dominantHz: dominantHz,
      );
}

const csvHeader = 't_ms,x,y,z,magnitude';

String samplesToCsv(List<Sample> samples) {
  final b = StringBuffer(csvHeader)..write('\n');
  for (final s in samples) {
    b
      ..write(s.tMs.toStringAsFixed(2))
      ..write(',')
      ..write(s.x.toStringAsFixed(5))
      ..write(',')
      ..write(s.y.toStringAsFixed(5))
      ..write(',')
      ..write(s.z.toStringAsFixed(5))
      ..write(',')
      ..write(s.mag.toStringAsFixed(5))
      ..write('\n');
  }
  return b.toString();
}

List<Sample> samplesFromCsv(String csv) {
  final out = <Sample>[];
  for (final line in const LineSplitter().convert(csv)) {
    final p = line.split(',');
    if (p.length < 4) continue;
    final t = double.tryParse(p[0]);
    final x = double.tryParse(p[1]);
    final y = double.tryParse(p[2]);
    final z = double.tryParse(p[3]);
    if (t == null || x == null || y == null || z == null) continue;
    out.add(Sample(t, x, y, z));
  }
  return out;
}

/// Reduces [values] to at most [maxPoints] by keeping the largest absolute
/// value of each bucket, so spikes survive.
List<double> downsamplePeak(List<double> values, int maxPoints) {
  if (values.length <= maxPoints) return List<double>.of(values);
  final out = <double>[];
  final step = values.length / maxPoints;
  for (var i = 0; i < maxPoints; i++) {
    final from = (i * step).floor();
    final to = ((i + 1) * step).floor().clamp(from + 1, values.length);
    var best = values[from];
    for (var j = from; j < to; j++) {
      if (values[j].abs() > best.abs()) best = values[j];
    }
    out.add(best);
  }
  return out;
}

/// Saved sessions: `<id>.csv` (the trace) and `<id>.json` (the summary).
class SessionStore {
  SessionStore([this._dirOverride]);

  final Directory? _dirOverride;

  Future<Directory> _dir() async {
    final base = _dirOverride ?? Directory('${(await getApplicationDocumentsDirectory()).path}/sessions');
    if (!await base.exists()) await base.create(recursive: true);
    return base;
  }

  Future<File> csvFile(int id) async => File('${(await _dir()).path}/$id.csv');

  Future<SessionMeta> save({
    required DateTime startedAt,
    required List<Sample> samples,
    required double sampleRate,
    String? name,
  }) async {
    final id = startedAt.millisecondsSinceEpoch;
    final mags = [for (final s in samples) s.mag];
    final window = samples.length > 1024 ? mags.sublist(mags.length - 1024) : mags;
    final dom = dominantFrequency(window, sampleRate);
    final meta = SessionMeta(
      id: id,
      name: name ?? 'Session ${_stamp(startedAt)}',
      startedAt: startedAt,
      durationMs: samples.isEmpty ? 0 : samples.last.tMs,
      sampleRate: sampleRate,
      count: samples.length,
      peak: peak(mags),
      rms: rms(mags),
      dominantHz: dom,
    );
    final dir = await _dir();
    await File('${dir.path}/$id.csv').writeAsString(samplesToCsv(samples));
    await File('${dir.path}/$id.json').writeAsString(jsonEncode(meta.toJson()));
    return meta;
  }

  Future<List<SessionMeta>> list() async {
    final dir = await _dir();
    final out = <SessionMeta>[];
    await for (final e in dir.list()) {
      if (e is File && e.path.endsWith('.json')) {
        try {
          out.add(SessionMeta.fromJson(jsonDecode(await e.readAsString()) as Map<String, dynamic>));
        } catch (_) {
          // Skip unreadable summaries.
        }
      }
    }
    out.sort((a, b) => b.id.compareTo(a.id));
    return out;
  }

  Future<List<Sample>> load(int id) async => samplesFromCsv(await (await csvFile(id)).readAsString());

  Future<void> rename(SessionMeta meta, String name) async {
    final dir = await _dir();
    await File('${dir.path}/${meta.id}.json').writeAsString(jsonEncode(meta.copyWith(name: name).toJson()));
  }

  Future<void> delete(int id) async {
    final dir = await _dir();
    for (final ext in ['csv', 'json']) {
      final f = File('${dir.path}/$id.$ext');
      if (await f.exists()) await f.delete();
    }
  }
}

String _two(int n) => n.toString().padLeft(2, '0');

String _stamp(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)} ${_two(d.hour)}:${_two(d.minute)}';
