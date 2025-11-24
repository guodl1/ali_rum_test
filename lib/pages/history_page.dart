import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/audio_card_widget.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import 'audio_player_page.dart';

/// 历史记录页面
class HistoryPage extends StatefulWidget {
  const HistoryPage({Key? key}) : super(key: key);

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  
  late TabController _tabController;
  List<HistoryModel> _allHistory = [];
  List<HistoryModel> _favorites = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final allHistory = await _apiService.getHistory();
      final favorites = await _apiService.getHistory(isFavorite: true);
      
      setState(() {
        _allHistory = allHistory;
        _favorites = favorites;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading history: $e')),
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
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Theme.of(context).brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('History'),
            elevation: 0,
            backgroundColor: Colors.transparent,
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'All'),
                Tab(text: 'Favorites'),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () {
                  // TODO: 实现搜索功能
                },
              ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildHistoryList(_allHistory),
                    _buildHistoryList(_favorites),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildHistoryList(List<HistoryModel> historyList) {
    if (historyList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No history yet',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: historyList.length,
        itemBuilder: (context, index) {
          final history = historyList[index];
          return AudioCardWidget(
            history: history,
            onPlay: () => _playAudio(history),
            onFavorite: () => _toggleFavorite(history),
            onDelete: () => _deleteHistory(history),
          );
        },
      ),
    );
  }

  Future<void> _playAudio(HistoryModel history) async {
    try {
      // 导航到播放页面，支持断点续播
      if (mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => AudioPlayerPage(history: history),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _toggleFavorite(HistoryModel history) async {
    try {
      final newFavoriteStatus = !history.isFavorite;
      await _apiService.toggleFavorite(
        historyId: history.id,
        isFavorite: newFavoriteStatus,
      );
      
      setState(() {
        history.isFavorite = newFavoriteStatus;
        if (newFavoriteStatus) {
          if (!_favorites.contains(history)) {
            _favorites.add(history);
          }
        } else {
          _favorites.remove(history);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _deleteHistory(HistoryModel history) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete History'),
        content: const Text('Are you sure you want to delete this item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _apiService.deleteHistory(history.id);
      
      setState(() {
        _allHistory.remove(history);
        _favorites.remove(history);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}
