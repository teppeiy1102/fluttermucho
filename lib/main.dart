import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Audio Player Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Red Audio Player'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final List<Map<String, String>> _audioFiles = [
    {'path': 'assets/audio/sample1.mp3', 'name': 'Groovy Hip Hop'},
    {'path': 'assets/audio/sample2.mp3', 'name': 'Ambient Bliss'},
    {'path': 'assets/audio/sample3.mp3', 'name': 'Upbeat Funk'},
    // 必要に応じて音声ファイルを追加してください
    // 例: {'path': 'assets/audio/your_audio_file.mp3', 'name': 'Your Audio Name'}
  ];

  late ConcatenatingAudioSource _playlist;

  int? _currentPlayingAudioSourceIndex;
  bool _isPlaying = false;
  bool _isShuffling = false;
  LoopMode _loopMode = LoopMode.off;
  double _currentSpeed = 1.0;
  final List<double> _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  int _currentSpeedIndex = 2; // 1.0x speed

  @override
  void initState() {
    super.initState();
    _playlist = ConcatenatingAudioSource(
      children:
          _audioFiles.map((file) => AudioSource.asset(file['path']!)).toList(),
    );
    _audioPlayer.setAudioSource(_playlist, preload: false);

    _audioPlayer.playerStateStream.listen((playerState) {
      if (mounted) {
        setState(() {
          _isPlaying = playerState.playing;
        });
      }
    });

    _audioPlayer.currentIndexStream.listen((index) {
      if (mounted && index != null) {
        setState(() {
          _currentPlayingAudioSourceIndex = index;
        });
      }
    });

    _audioPlayer.loopModeStream.listen((loopMode) {
      if (mounted) {
        setState(() {
          _loopMode = loopMode;
        });
      }
    });

    _audioPlayer.shuffleModeEnabledStream.listen((isShuffling) {
      if (mounted) {
        setState(() {
          _isShuffling = isShuffling;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _playAudioAtIndex(int index) async {
    if (_audioPlayer.audioSource != _playlist) {
      await _audioPlayer.setAudioSource(_playlist,
          initialIndex: index, preload: true);
    } else {
      await _audioPlayer.seek(Duration.zero, index: index);
    }
    _audioPlayer.play();
  }

  void _toggleShuffle() {
    final newShuffleState = !_isShuffling;
    _audioPlayer.setShuffleModeEnabled(newShuffleState);
    // State will be updated by shuffleModeEnabledStream listener
  }

  void _toggleRepeat() {
    LoopMode nextLoopMode;
    if (_loopMode == LoopMode.off) {
      nextLoopMode = LoopMode.one;
    } else if (_loopMode == LoopMode.one) {
      nextLoopMode = LoopMode.all;
    } else {
      nextLoopMode = LoopMode.off;
    }
    _audioPlayer.setLoopMode(nextLoopMode);
    // State will be updated by loopModeStream listener
  }

  void _changeSpeed() {
    _currentSpeedIndex = (_currentSpeedIndex + 1) % _speeds.length;
    _currentSpeed = _speeds[_currentSpeedIndex];
    _audioPlayer.setSpeed(_currentSpeed);
    setState(() {}); // Update UI for speed text
  }

  IconData _getRepeatIcon() {
    if (_loopMode == LoopMode.one) return Icons.repeat_one;
    if (_loopMode == LoopMode.all) return Icons.repeat_on;
    return Icons.repeat;
  }

  Color _getActiveIconColor(BuildContext context) {
    return Theme.of(context).colorScheme.primary;
  }

  Color _getInactiveIconColor(BuildContext context) {
    // AppBarのIconThemeに従うか、デフォルトの色を使用
    return Theme.of(context).appBarTheme.iconTheme?.color ??
           (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black54) ;
  }

  @override
  Widget build(BuildContext context) {
    final Color onAppBarColor = Colors.red;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title, style: TextStyle(color: onAppBarColor)),
        actions: <Widget>[
          IconButton(
            icon: Icon(
              _isShuffling ? Icons.shuffle_on : Icons.shuffle,
              color: _isShuffling ? _getActiveIconColor(context) : _getInactiveIconColor(context),
            ),
            onPressed: _toggleShuffle,
            tooltip: _isShuffling ? 'Shuffle Off' : 'Shuffle On',
          ),
          IconButton(
            icon: Icon(
              _getRepeatIcon(),
              color: _loopMode != LoopMode.off ? _getActiveIconColor(context) : _getInactiveIconColor(context),
            ),
            onPressed: _toggleRepeat,
            tooltip: _loopMode == LoopMode.one ? 'Repeat One' : (_loopMode == LoopMode.all ? 'Repeat All' : 'Repeat Off'),
          ),
          TextButton(
            onPressed: _changeSpeed,
            child: Text(
              '${_currentSpeed.toStringAsFixed(_currentSpeed % 1 == 0 ? 0 : 1)}x',
              style: TextStyle(color: onAppBarColor, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: _audioFiles.isEmpty
          ? const Center(child: Text('No audio files found in assets/audio.'))
          : ListView.builder(
              itemCount: _audioFiles.length,
              itemBuilder: (context, index) {
                final audioFile = _audioFiles[index];
                bool isCurrentlyPlayingTrack = _currentPlayingAudioSourceIndex == index;

                return ListTile(
                  leading: Icon(
                    isCurrentlyPlayingTrack && _isPlaying
                        ? Icons.volume_up
                        : Icons.music_note,
                    color: isCurrentlyPlayingTrack && _isPlaying
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.secondary,
                  ),
                  title: Text(audioFile['name']!),
                  subtitle: Text(audioFile['path']!.split('/').last),
                  selected: isCurrentlyPlayingTrack,
                  selectedTileColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                  onTap: () => _playAudioAtIndex(index),
                );
              },
            ),
      );
  }
}
