import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:io';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'マッチョサウンズ',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        cardTheme: CardTheme(
          elevation: 8,
          shadowColor: Colors.red.withOpacity(0.3),
        ),
      ),
      home: const MyHomePage(title: 'マッチョサウンズ'),
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
    {'path': 'assets/audio/decai.mp3', 'name': 'デカいよ'},
    {'path': 'assets/audio/nicebalc.mp3', 'name': 'ナイスバルク'},
    {'path': 'assets/audio/kireteru.mp3', 'name': 'キレてる'},
    {'path': 'assets/audio/senaka.mp3', 'name': '背中に鬼神が宿ってる！'},
    {'path': 'assets/audio/hukin.mp3', 'name': '腹筋が蟹の裏みたい'},
    {'path': 'assets/audio/nunega.mp3', 'name': '胸がはち切れそう'},
    {'path': 'assets/audio/dodai.mp3', 'name': '土台が違うよ土台が！'},
    {'path': 'assets/audio/chirsmas.mp3', 'name': '背中にクリスマスツリー'},
    {'path': 'assets/audio/3d.mp3', 'name': '3Dパーツの立体感！'},
    {'path': 'assets/audio/katameron.mp3', 'name': '肩メロン収穫祭だ！'},
    {'path': 'assets/audio/soubou.mp3', 'name': '僧帽筋が並みじゃない'},
    {'path': 'assets/audio/nemurenai.mp3', 'name': 'ここまで絞るには眠れない夜もあっただろ'},
    {'path': 'assets/audio/kabuto.mp3', 'name': '背中がカブトムシの腹だ'},
    {'path': 'assets/audio/6ldk.mp3', 'name': '腹筋6LDKかい！'},
    {'path': 'assets/audio/pan.mp3', 'name': '腹筋ちぎりパン'},
 		{'path': 'assets/audio/daicon.mp3', 'name': '腹斜筋で大根おろしたい'},
  	{'path': 'assets/audio/ketu.mp3', 'name': '胸がケツみたい'},
  	{'path': 'assets/audio/toberu.mp3', 'name': '空も飛べるはず'},
  	{'path': 'assets/audio/hane.mp3', 'name': '背中に羽が生えてる'},
  	{'path': 'assets/audio/ashi.mp3', 'name': '脚が歩いてる'},
		{'path': 'assets/audio/shiagari.mp3', 'name': '仕上がってるよ～仕上がってるよ～'},
	  {'path': 'assets/audio/daikyo.mp3', 'name': '大胸筋が歩いてる'},
		{'path': 'assets/audio/gori.mp3', 'name': '脚がゴリ'},

  ];
		
		
		
		
		
		
  int? _currentPlayingAudioSourceIndex;
  bool _isPlaying = false;
  bool _isShuffling = false;
  LoopMode _loopMode = LoopMode.off;
  double _currentSpeed = 1.0;
  final List<double> _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  int _currentSpeedIndex = 2;

  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;

  final String _bannerAdUnitId = Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/6300978111'
      : 'ca-app-pub-7148683667182672/6456218782';

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: _bannerAdUnitId,
      request: const AdRequest(),
      size: AdSize.largeBanner,
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          debugPrint('$BannerAd loaded.');
          setState(() {
            _isBannerAdLoaded = true;
          });
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          debugPrint('$BannerAd failedToLoad: $error');
          ad.dispose();
        },
        onAdOpened: (Ad ad) => debugPrint('$BannerAd onAdOpened.'),
        onAdClosed: (Ad ad) => debugPrint('$BannerAd onAdClosed.'),
        onAdImpression: (Ad ad) => debugPrint('$BannerAd onAdImpression.'),
      ),
    )..load();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
    _audioPlayer.setAudioSources(
      _audioFiles.map((file) => AudioSource.asset(file['path']!)).toList(),
      preload: false,
    );

    // 初期設定：リピートもシャッフルもオフの場合は1曲だけ再生
    _audioPlayer.setLoopMode(LoopMode.off);
    _audioPlayer.setShuffleModeEnabled(false);

    _audioPlayer.playerStateStream.listen((playerState) {
      if (mounted) {
        setState(() {
          _isPlaying = playerState.playing;
        });
      }
    });

    _audioPlayer.currentIndexStream.listen((streamIndex) {
      if (mounted && streamIndex != null) {
        // プレイリストモード（全曲リピート、1曲リピート、またはシャッフルオン）の場合のみ、
        // ストリームから来たインデックスを現在の再生インデックスとして設定する。
        // 単一曲再生モード（リピートオフかつシャッフルオフ）の場合は、
        // _currentPlayingAudioSourceIndex は _playAudioAtIndex で設定された値を維持する。
        if (_loopMode != LoopMode.off || _isShuffling) {
          setState(() {
            _currentPlayingAudioSourceIndex = streamIndex;
          });
        }
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

    // 曲が終了したときの処理を追加
    _audioPlayer.processingStateStream.listen((processingState) {
      if (processingState == ProcessingState.completed) {
        // リピートもシャッフルもオフの場合は停止
        if (_loopMode == LoopMode.off && !_isShuffling) {
          _audioPlayer.stop();
        }
      }
    });
  }

  void _playAudioAtIndex(int index) async {
    // タップされた曲のインデックスを即座に更新
    setState(() {
      _currentPlayingAudioSourceIndex = index;
    });

    if (_loopMode == LoopMode.off && !_isShuffling) {
      // リピート・シャッフルOFF → 単一曲再生（停止は processingStateStream で行う）
      await _audioPlayer.setAudioSource(
        AudioSource.asset(_audioFiles[index]['path']!),
        preload: false,
      );
      await _audioPlayer.setLoopMode(LoopMode.off);
      await _audioPlayer.setShuffleModeEnabled(false);
      await _audioPlayer.play();
    } else {
      // 全曲リピート・1曲リピート・シャッフル時 → プレイリスト再生
      await _audioPlayer.setAudioSources(
        _audioFiles.map((f) => AudioSource.asset(f['path']!)).toList(),
        preload: false,
      );
      await _audioPlayer.setLoopMode(
        _loopMode == LoopMode.one ? LoopMode.one : LoopMode.all,
      );
      await _audioPlayer.setShuffleModeEnabled(_isShuffling);
      await _audioPlayer.seek(Duration.zero, index: index);
      await _audioPlayer.play();
    }
  }

  /// シャッフル切り替え
  void _toggleShuffle() {
    setState(() {
      _isShuffling = !_isShuffling;      // 状態を即時反映
    });
    _audioPlayer.setShuffleModeEnabled(_isShuffling);
    _updateLoopMode();
  }

  /// リピート切り替え
  void _toggleRepeat() {
    LoopMode next = 
      _loopMode == LoopMode.off  ? LoopMode.one  :
      _loopMode == LoopMode.one  ? LoopMode.all  :
                                    LoopMode.off;
    setState(() {
      _loopMode = next;                  // 状態を即時反映
    });
    _audioPlayer.setLoopMode(_loopMode);
    _updateLoopMode();
  }

  // 新しいメソッドを追加：ループモードを適切に設定
  void _updateLoopMode() {
    if (_loopMode == LoopMode.off && !_isShuffling) {
      // リピートもシャッフルもオフの場合は、1曲再生後に停止
      _audioPlayer.setLoopMode(LoopMode.off);
    } else if (_loopMode == LoopMode.one) {
      // 1曲リピート
      _audioPlayer.setLoopMode(LoopMode.one);
    } else if (_loopMode == LoopMode.all || _isShuffling) {
      // 全曲リピートまたはシャッフル時
      _audioPlayer.setLoopMode(LoopMode.all);
    }
  }

  void _changeSpeed() {
    _currentSpeedIndex = (_currentSpeedIndex + 1) % _speeds.length;
    _currentSpeed = _speeds[_currentSpeedIndex];
    _audioPlayer.setSpeed(_currentSpeed);
    setState(() {});
  }

  IconData _getRepeatIcon() {
    if (_loopMode == LoopMode.one) return Icons.repeat_one;
    if (_loopMode == LoopMode.all) return Icons.repeat_on;
    return Icons.repeat;
  }

  Color _getActiveIconColor(BuildContext context) {
    return Colors.red;
  }

  Color _getInactiveIconColor(BuildContext context) {
    return Colors.grey[400]!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: _isBannerAdLoaded && _bannerAd != null
          ? Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black, Colors.grey[900]!],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SizedBox(
                width: _bannerAd!.size.width.toDouble(),
                height: _bannerAd!.size.height.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),
            )
          : null,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Colors.red, Colors.blue],
          ).createShader(bounds),
          child: Text(
            widget.title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black,
              Colors.grey[900]!,
              Colors.black,
            ],
          ),
        ),
        child: Stack(
          children: [
            // 背景の画像エフェクト
            Positioned.fill(
              child: Opacity(
                opacity: 0.1,
                child: Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/image/download.jpg'),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                        Colors.red.withOpacity(0.3),
                        BlendMode.overlay,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _audioFiles.isEmpty
                ? const Center(
                    child: Text(
                      'No audio files found in assets/audio.',
                      style: TextStyle(color: Colors.white),
                    ),
                  )
                : Column(
                    children: [
                      // コントロールパネル
                      Container(
                        margin: const EdgeInsets.all(20),
                        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.grey[800]!.withOpacity(0.9),
                              Colors.grey[900]!.withOpacity(0.9),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(
                            color: Colors.red.withOpacity(0.3),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.2),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(
                              icon: Icon(
                                _isShuffling ? Icons.shuffle_on : Icons.shuffle,
                                color: _isShuffling
                                    ? _getActiveIconColor(context)
                                    : _getInactiveIconColor(context),
                                size: 28,
                              ),
                              onPressed: _toggleShuffle,
                              tooltip: _isShuffling ? 'Shuffle Off' : 'Shuffle On',
                            ),
                            IconButton(
                              icon: Icon(
                                _getRepeatIcon(),
                                color: _loopMode != LoopMode.off
                                    ? _getActiveIconColor(context)
                                    : _getInactiveIconColor(context),
                                size: 28,
                              ),
                              onPressed: _toggleRepeat,
                              tooltip: _loopMode == LoopMode.one
                                  ? 'Repeat One'
                                  : (_loopMode == LoopMode.all
                                      ? 'Repeat All'
                                      : 'Repeat Off'),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [Colors.red, Colors.blue],
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: GestureDetector(
                                onTap: _changeSpeed,
                                child: Text(
                                  '${_currentSpeed.toStringAsFixed(_currentSpeed % 1 == 0 ? 0 : 1)}x',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            IconButton( // 追加: 停止ボタン
                              icon: Icon(
                                Icons.stop,
                                color: _getInactiveIconColor(context), // 必要に応じて色を調整
                                size: 28,
                              ),
                              onPressed: () => _audioPlayer.stop(),
                              tooltip: 'Stop',
                            ),
                          ],

                        ),
                      ),
                      // プレイリスト
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _audioFiles.length,
                          itemBuilder: (context, index) {
                            final audioFile = _audioFiles[index];
                            bool isCurrentlyPlayingTrack =
                                _currentPlayingAudioSourceIndex == index;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Card(
                                color: Colors.transparent,
                                elevation: 0,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      colors: isCurrentlyPlayingTrack
                                          ? [
                                              Colors.grey.withOpacity(0.3),
                                              Colors.blue.withOpacity(0.2),
                                            ]
                                          : [
                                              Colors.grey[800]!.withOpacity(0.7),
                                              Colors.grey[900]!.withOpacity(0.7),
                                            ],
                                    ),
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(
                                      color: isCurrentlyPlayingTrack
                                          ? Colors.red.withOpacity(0.5)
                                          : Colors.grey.withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 8),
                                    leading: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: isCurrentlyPlayingTrack && _isPlaying
                                              ? [Colors.green, Colors.blue]
                                              : [Colors.grey[600]!, Colors.grey[700]!],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        isCurrentlyPlayingTrack && _isPlaying
                                            ? Icons.volume_up
                                            : Icons.music_note,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                    title: Text(
                                      audioFile['name']!,
                                      style: TextStyle(
                                        color: isCurrentlyPlayingTrack
                                            ? Colors.white
                                            : Colors.grey[300],
                                        fontWeight: isCurrentlyPlayingTrack
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        fontSize: 16,
                                      ),
                                    ),
                                    onTap: () => _playAudioAtIndex(index),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}
