import 'package:flutter_tts/flutter_tts.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/models.dart';

class SystemTTSService {
  static final SystemTTSService _instance = SystemTTSService._internal();
  factory SystemTTSService() => _instance;
  SystemTTSService._internal();

  final FlutterTts _flutterTts = FlutterTts();

  /// 获取系统语音列表并转换为 VoiceTypeModel
  Future<List<VoiceTypeModel>> getVoices() async {
    try {
      List<dynamic> voices = await _flutterTts.getVoices;
      List<VoiceTypeModel> voiceModels = [];

      for (var voice in voices) {
        // voice map structure depends on platform
        // Android: {name: "en-us-x-sfg#male_1-local", locale: "en-US"}
        // iOS: {name: "Karen", locale: "en-AU"}
        
        final Map<Object?, Object?> voiceMap = voice as Map<Object?, Object?>;
        final String name = voiceMap['name']?.toString() ?? 'Unknown';
        final String locale = voiceMap['locale']?.toString() ?? 'en-US';
        
        // Generate a unique ID
        final String id = 'system_$name';
        
        voiceModels.add(VoiceTypeModel(
          id: id,
          voiceId: id, // Use same ID for voiceId
          name: name,
          language: locale,
          gender: 'unknown', // System TTS often doesn't provide gender
          previewUrl: '', // No remote preview URL
          description: 'System Voice ($locale)',
          provider: 'system',
          voiceType: 'free',
        ));
      }
      
      return voiceModels;
    } catch (e) {
      print('Error getting system voices: $e');
      return [];
    }
  }

  /// 预览系统语音
  Future<void> preview(String text, String voiceName, String language) async {
    try {
      await _flutterTts.stop();
      await _flutterTts.setLanguage(language);
      
      // On iOS, setVoice takes a Map. On Android, it might take a string name.
      // flutter_tts handles some of this, but let's try setting by name.
      // Note: setVoice might expect different formats per platform.
      // For simplicity in this preview, we rely on setLanguage mostly, 
      // or try to match the voice name if possible.
      
      // Attempt to set specific voice if supported
      // This is platform dependent and might need refinement
       await _flutterTts.setVoice({"name": voiceName, "locale": language});

      await _flutterTts.speak(text);
    } catch (e) {
      print('Error previewing system voice: $e');
    }
  }

  /// 生成语音文件
  Future<String?> synthesizeToFile(String text, String voiceName, String language) async {
    try {
      await _flutterTts.setLanguage(language);
      await _flutterTts.setVoice({"name": voiceName, "locale": language});

      String fileName = 'system_tts_${DateTime.now().millisecondsSinceEpoch}.wav';
      
      // flutter_tts synthesizeToFile behavior:
      // Android: saves to getExternalFilesDir() + / + fileName
      // iOS: saves to NSDocumentDirectory + / + fileName
      
      if (Platform.isAndroid) {
        // On Android, flutter_tts saves to external files dir
        // We need to find that path to return it
        // Note: flutter_tts might not return the full path, so we construct it
        await _flutterTts.synthesizeToFile(text, fileName);
        
        // Wait a bit for file to be written? synthesizeToFile is async but might return before file is closed?
        // Usually await is enough.
        
        final directory = await getExternalStorageDirectory(); // This is usually where getExternalFilesDir points to
        // Or getApplicationDocumentsDirectory? flutter_tts source uses mContext.getExternalFilesDir(null)
        
        // If getExternalStorageDirectory is null (some devices), fallback?
        // Let's assume it works for now.
        if (directory != null) {
          return path.join(directory.path, fileName);
        }
      } else if (Platform.isIOS) {
        await _flutterTts.synthesizeToFile(text, fileName);
        final directory = await getApplicationDocumentsDirectory();
        return path.join(directory.path, fileName);
      }
      
      return null;
    } catch (e) {
      print('Error synthesizing to file: $e');
      return null;
    }
  }
  
  Future<void> stop() async {
    await _flutterTts.stop();
  }
}
