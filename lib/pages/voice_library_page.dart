import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/voice_card_widget.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';
import '../models/models.dart';

/// 语音库页面
class VoiceLibraryPage extends StatefulWidget {
  const VoiceLibraryPage({Key? key}) : super(key: key);

  @override
  State<VoiceLibraryPage> createState() => _VoiceLibraryPageState();
}

class _VoiceLibraryPageState extends State<VoiceLibraryPage> {
  final ApiService _apiService = ApiService();
  final AudioService _audioService = AudioService();
  
  List<VoiceTypeModel> _voices = [];
  VoiceTypeModel? _selectedVoice;
  String? _filterLanguage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadVoices();
  }

  Future<void> _loadVoices() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final voices = await _apiService.getVoiceTypes(language: _filterLanguage);
      setState(() {
        _voices = voices;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading voices: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Theme.of(context).brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Voice Library'),
          elevation: 0,
          backgroundColor: Colors.transparent,
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.filter_list),
              onSelected: (value) {
                setState(() {
                  _filterLanguage = value == 'all' ? null : value;
                });
                _loadVoices();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'all',
                  child: Text('All Languages'),
                ),
                const PopupMenuItem(
                  value: 'zh',
                  child: Text('Chinese'),
                ),
                const PopupMenuItem(
                  value: 'en',
                  child: Text('English'),
                ),
              ],
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildVoiceGrid(),
        floatingActionButton: _selectedVoice != null
            ? FloatingActionButton.extended(
                onPressed: () {
                  Navigator.pop(context, _selectedVoice);
                },
                icon: const Icon(Icons.check),
                label: const Text('Confirm'),
              )
            : null,
      ),
    );
  }

  Widget _buildVoiceGrid() {
    if (_voices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.voice_over_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No voices available',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _voices.length,
      itemBuilder: (context, index) {
        final voice = _voices[index];
        return VoiceCardWidget(
          voice: voice,
          isSelected: _selectedVoice?.id == voice.id,
          onTap: () {
            setState(() {
              _selectedVoice = voice;
            });
          },
          onPreview: () => _previewVoice(voice),
        );
      },
    );
  }

  Future<void> _previewVoice(VoiceTypeModel voice) async {
    try {
      await _audioService.play(voice.previewUrl);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing preview: $e')),
        );
      }
    }
  }
}
