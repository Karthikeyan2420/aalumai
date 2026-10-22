import 'package:aalumai/core/providers/providers.dart';
import 'package:aalumai/features/jarvis/conversation/assistant_engine.dart';
import 'package:aalumai/features/jarvis/data/tool_executor.dart';
import 'package:aalumai/features/jarvis/maps/maps_service.dart';
import 'package:aalumai/features/jarvis/tts/assistant_voice_service.dart';
import 'package:aalumai/features/jarvis/voice/voice_service.dart';
import 'package:aalumai/features/jarvis/web_search/http_web_search.dart';
import 'package:aalumai/features/jarvis/web_search/search_result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Online research providers (Wikipedia, weather, USGS). A single shared
/// instance keeps the in-memory response cache warm across turns.
final webSearchProvider = Provider<WebSearchPort>((ref) => HttpWebSearch());

/// OpenStreetMap-backed maps & places service.
final mapsServiceProvider = Provider<MapsService>((ref) => MapsService());

/// Text-to-speech for the assistant, honouring user voice preferences.
final assistantVoiceServiceProvider = Provider<AssistantVoiceService>(
  (ref) => AssistantVoiceService(prefs: ref.watch(appPreferencesProvider)),
);

/// Speech recognition + wake-word monitoring.
final voiceServiceProvider = Provider<VoiceService>((ref) {
  final service = VoiceService();
  ref.onDispose(service.dispose);
  return service;
});

/// The deterministic, model-free assistant.
final assistantEngineProvider = Provider<AssistantEngine>((ref) {
  return AssistantEngine(
    executor: ref.watch(jarvisToolExecutorProvider),
    prefs: ref.watch(appPreferencesProvider),
    webSearch: ref.watch(webSearchProvider),
    maps: ref.watch(mapsServiceProvider),
  );
});
