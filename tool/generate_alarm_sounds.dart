// Generates the bundled alarm tones used by the Alarm feature.
//
// The tones are original: this script synthesises PCM sine waves with an
// attack/release envelope and writes 16-bit mono WAV files. There are no
// third-party samples, so the assets are safe to ship and are fully
// reproducible. Run from the project root with:
//
//   dart run tool/generate_alarm_sounds.dart
//
// Output: assets/audio/alarm_*.wav
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const int _sampleRate = 44100;

void main() {
  final out = Directory('assets/audio');
  if (!out.existsSync()) out.createSync(recursive: true);

  File('${out.path}/alarm_classic.wav').writeAsBytesSync(
    _render(_classicPattern(), totalSeconds: 2.4),
  );
  File('${out.path}/alarm_gentle.wav').writeAsBytesSync(
    _render(_gentlePattern(), totalSeconds: 3.2),
  );
  File('${out.path}/alarm_urgent.wav').writeAsBytesSync(
    _render(_urgentPattern(), totalSeconds: 1.2),
  );

  stdout.writeln('Wrote alarm tones to ${out.path}');
}

typedef _Sample = double Function(double t);

/// Beep envelope: a sine at [freq] gated by a short attack/release so the
/// waveform starts and ends at zero (no clicks when looping).
_Sample _tone(double freq, {double gain = 0.5}) {
  return (t) => gain * math.sin(2 * math.pi * freq * t);
}

List<double> _classicPattern() {
  // Two-tone doorbell-like pattern: 880 Hz then 660 Hz, repeated.
  final events = <(double start, double dur, double freq)>[
    (0.00, 0.28, 880),
    (0.34, 0.28, 660),
    (0.72, 0.28, 880),
    (1.06, 0.28, 660),
    (1.44, 0.28, 880),
    (1.78, 0.28, 660),
    (2.12, 0.24, 880),
  ];
  return _pattern(events);
}

List<double> _gentlePattern() {
  // Soft rising/falling chime using 523/659/784 Hz (C5/E5/G5).
  final events = <(double start, double dur, double freq)>[
    (0.00, 0.5, 523.25),
    (0.45, 0.5, 659.25),
    (0.90, 0.6, 783.99),
    (1.60, 0.5, 659.25),
    (2.05, 0.7, 523.25),
    (2.80, 0.35, 392.00),
  ];
  return _pattern(events, gain: 0.38);
}

List<double> _urgentPattern() {
  // Fast, high-pitched triple beeps.
  final events = <(double start, double dur, double freq)>[
    (0.00, 0.12, 1200),
    (0.16, 0.12, 1200),
    (0.32, 0.12, 1200),
    (0.52, 0.12, 1000),
    (0.68, 0.12, 1000),
    (0.84, 0.12, 1000),
  ];
  return _pattern(events, gain: 0.45);
}

List<double> _pattern(
  List<(double, double, double)> events, {
  double gain = 0.5,
}) {
  var end = 0.0;
  for (final e in events) {
    end = math.max(end, e.$1 + e.$2);
  }
  final samples = List<double>.filled((end * _sampleRate).ceil() + 1, 0);
  for (final (start, dur, freq) in events) {
    final first = (start * _sampleRate).round();
    final count = (dur * _sampleRate).round();
    final tone = _tone(freq, gain: gain);
    final attack = (0.012 * _sampleRate).round().clamp(1, count);
    final release = (0.03 * _sampleRate).round().clamp(1, count);
    for (var i = 0; i < count; i++) {
      final t = i / _sampleRate;
      var env = 1.0;
      if (i < attack) {
        env = i / attack;
      } else if (i > count - release) {
        env = (count - i) / release;
      }
      final idx = first + i;
      if (idx >= 0 && idx < samples.length) {
        samples[idx] += tone(t) * env;
      }
    }
  }
  return samples;
}

Uint8List _render(List<double> samples, {required double totalSeconds}) {
  final dataLength = (_sampleRate * totalSeconds).round();
  final data = Int16List(dataLength);
  for (var i = 0; i < dataLength; i++) {
    final v = i < samples.length ? samples[i] : 0.0;
    data[i] = (v.clamp(-1.0, 1.0) * 32767).round();
  }

  final byteData = BytesBuilder();
  // RIFF header.
  byteData.add(_ascii('RIFF'));
  byteData.add(_u32(36 + data.length * 2));
  byteData.add(_ascii('WAVE'));
  // fmt chunk.
  byteData.add(_ascii('fmt '));
  byteData.add(_u32(16)); // PCM chunk size
  byteData.add(_u16(1)); // PCM format
  byteData.add(_u16(1)); // mono
  byteData.add(_u32(_sampleRate));
  byteData.add(_u32(_sampleRate * 2)); // byte rate
  byteData.add(_u16(2)); // block align
  byteData.add(_u16(16)); // bits per sample
  // data chunk.
  byteData.add(_ascii('data'));
  byteData.add(_u32(data.length * 2));
  final bytes = byteData.toBytes();
  final result = Uint8List(bytes.length + data.length * 2);
  result.setRange(0, bytes.length, bytes);
  final bd = ByteData.sublistView(result, bytes.length);
  for (var i = 0; i < data.length; i++) {
    bd.setInt16(i * 2, data[i], Endian.little);
  }
  return result;
}

Uint8List _ascii(String s) => Uint8List.fromList(s.codeUnits);
Uint8List _u32(int v) => Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.little);
Uint8List _u16(int v) => Uint8List(2)..buffer.asByteData().setUint16(0, v, Endian.little);
