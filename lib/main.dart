import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart'; // just_audio を audioplayers に変更
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'tabata.dart';

// Enumをトップレベルに移動
enum CustomLoopMode { off, one, all }

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
    {'path': 'audio/decai.mp3', 'name': 'デカいよ'},
    {'path': 'audio/nicebalc.mp3', 'name': 'ナイスバルク'},
    {'path': 'audio/kireteru.mp3', 'name': 'キレてる'},
    {'path': 'audio/senaka.mp3', 'name': '背中に鬼神が宿ってる！'},
    {'path': 'audio/hukin.mp3', 'name': '腹筋が蟹の裏みたい'},
    {'path': 'audio/nunega.mp3', 'name': '胸がはち切れそう'},
    {'path': 'audio/dodai.mp3', 'name': '土台が違うよ土台が！'},
    {'path': 'audio/chirsmas.mp3', 'name': '背中にクリスマスツリー'},
    {'path': 'audio/3d.mp3', 'name': '3Dパーツの立体感！'},
    {'path': 'audio/katameron.mp3', 'name': '肩メロン収穫祭だ！'},
    {'path': 'audio/soubou.mp3', 'name': '僧帽筋が並みじゃない'},
    {'path': 'audio/nemurenai.mp3', 'name': 'ここまで絞るには眠れない夜もあっただろ'},
    {'path': 'audio/kabuto.mp3', 'name': '背中がカブトムシの腹だ'},
    {'path': 'audio/6ldk.mp3', 'name': '腹筋6LDKかい！'},
    {'path': 'audio/pan.mp3', 'name': '腹筋ちぎりパン'},
    {'path': 'audio/daicon.mp3', 'name': '腹斜筋で大根おろしたい'},
    {'path': 'audio/ketu.mp3', 'name': '胸がケツみたい'},
    {'path': 'audio/toberu.mp3', 'name': '空も飛べるはず'},
    {'path': 'audio/hane.mp3', 'name': '背中に羽が生えてる'},
    {'path': 'audio/ashi.mp3', 'name': '脚が歩いてる'},
    {'path': 'audio/shiagari.mp3', 'name': '仕上がってるよ～仕上がってるよ～'},
    {'path': 'audio/daikyo.mp3', 'name': '大胸筋が歩いてる'},
    {'path': 'audio/gori.mp3', 'name': '脚がゴリラ'},
  ];

  int? _currentPlayingAudioSourceIndex;
  bool _isPlaying = false;
  bool _isShuffling = false;
  CustomLoopMode _loopMode = CustomLoopMode.off;

  double _currentSpeed = 1.0;
  final List<double> _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  int _currentSpeedIndex = 2;

  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;

  final String _bannerAdUnitId = Platform.isAndroid
      ? 'ca-app-pub-7148683667182672/5530984071'
      : 'ca-app-pub-7148683667182672/6456218782';

  bool _isAlertDialogShown = false;
  List<String> _bodyImagePaths = [];
  final Random _random = Random();

  // シャッフル再生用のキュー
  List<int> _shuffledIndices = [];
  int _currentShuffledQueueIndex = -1;

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
    _loadBodyImages();

    _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      if (!mounted) return;
      final bool isEffectivelyPlaying = state == PlayerState.playing;

      if (_isPlaying && !isEffectivelyPlaying && _isAlertDialogShown) {
        if (Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        _isAlertDialogShown = false;
      }

      setState(() {
        _isPlaying = isEffectivelyPlaying;
        // 1曲再生モード(非シャッフル、非ループ)で再生が終わった場合の処理は onPlayerComplete で行う
      });

    });

    _audioPlayer.onPlayerComplete.listen((_) {
      if (!mounted) return;

      if (_isAlertDialogShown) {
        if (Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        _isAlertDialogShown = false;
      }

      if (_isShuffling) {
        if (_shuffledIndices.isEmpty && _audioFiles.isNotEmpty) {
          _generateShuffledList();
        }
        if (_shuffledIndices.isNotEmpty) {
          _currentShuffledQueueIndex++;
          if (_currentShuffledQueueIndex >= _shuffledIndices.length) {
            if (_loopMode == CustomLoopMode.all) {
              _generateShuffledList();
              if (_shuffledIndices.isNotEmpty) {
                _currentShuffledQueueIndex = 0;
                _playAudioAtIndex(_shuffledIndices[_currentShuffledQueueIndex], playImmediately: true);
              } else {
                setState(() { _isPlaying = false; _currentPlayingAudioSourceIndex = null; });
              }
            } else {
              setState(() { _isPlaying = false; });
            }
          } else {
            _playAudioAtIndex(_shuffledIndices[_currentShuffledQueueIndex], playImmediately: true);
          }
        } else {
          setState(() { _isPlaying = false; _currentPlayingAudioSourceIndex = null; });
        }
      } else if (_loopMode == CustomLoopMode.one) {
        // 1曲リピート：同じ曲を再生
        _playAudioAtIndex(_currentPlayingAudioSourceIndex!, playImmediately: true);
      } else if (_loopMode == CustomLoopMode.all) {
        if (_audioFiles.isEmpty) {
          setState(() { _isPlaying = false; _currentPlayingAudioSourceIndex = null; });
          return;
        }
        if (_currentPlayingAudioSourceIndex == null && _audioFiles.isNotEmpty) {
          _currentPlayingAudioSourceIndex = 0;
        }
        if (_currentPlayingAudioSourceIndex != null) {
          int nextIndex = (_currentPlayingAudioSourceIndex! + 1) % _audioFiles.length;
          _playAudioAtIndex(nextIndex, playImmediately: true);
        } else if (_audioFiles.isNotEmpty) {
          _playAudioAtIndex(0, playImmediately: true);
        }
      } else { // CustomLoopMode.off
        setState(() { _isPlaying = false; });
      }
    });
  }

  // asset/image/body/ 内の画像パスを読み込むメソッド
  Future<void> _loadBodyImages() async {
    final manifestContent = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> manifestMap = json.decode(manifestContent);
    final imagePaths = manifestMap.keys
        .where((String key) => key.startsWith('assets/image/body/'))
        .toList();
    if (mounted) {
      setState(() {
        _bodyImagePaths = imagePaths;
      });
    }
  }

  void _showPlayingAlertDialog() {
    if (_currentPlayingAudioSourceIndex == null || !mounted) return;

    // 既にアラートが表示されている場合は何もしない
    if (_isAlertDialogShown) return;

    _isAlertDialogShown = true;

    String? randomImagePath;
    if (_bodyImagePaths.isNotEmpty) {
      randomImagePath = _bodyImagePaths[_random.nextInt(_bodyImagePaths.length)];
    }

    showDialog(
      barrierColor: Colors.black54, // ダイアログの背景色を半透明に
      context: context,
      barrierDismissible: false, // アラートの外側をタップしても閉じない
      builder: (BuildContext dialogContext) { // ダイアログ専用のコンテキスト
        return AlertDialog(
          actionsAlignment: MainAxisAlignment.center,
          backgroundColor: Colors.black, // ダイアログの背景色を半透明に
         alignment: Alignment.center,
          title: Center(child: const Text('再生中', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
          content: _ZoomableImageDialogContent( // <-- 変更
            imagePath: randomImagePath,
            audioName: _audioFiles[_currentPlayingAudioSourceIndex!]['name']!,
          ),
          actions: <Widget>[
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [const Color.fromARGB(255, 189, 189, 189), const Color.fromARGB(255, 139, 138, 138)],
                ),
                borderRadius: BorderRadius.circular(5),
              ),
              child: TextButton.icon(
                label: const Text('停止', style: TextStyle(fontSize: 16, color: Colors.black)),
                icon: const Icon(Icons.stop, size: 24, color: Colors.black),
                onPressed: () {
                  _audioPlayer.stop(); // 先にオーディオを停止
                  // Navigator.of(dialogContext).pop(); // ダイアログを閉じるのは playerStateStream に任せる場合がある
                                                  // ただし、ユーザーが明示的に停止した場合は即時閉じて良い
                  if (Navigator.of(dialogContext).canPop()) {
                    Navigator.of(dialogContext).pop();
                  }
                  _isAlertDialogShown = false; // 停止ボタンで閉じたことを明確にする
                },
              ),
            ),
          ],
        );
      },
    ).then((_) {
      // ダイアログが（理由を問わず）閉じた後に呼ばれる
      _isAlertDialogShown = false;
      // プレイヤーがまだ再生中の場合（例：ダイアログ外タップで閉じられたが、実際には閉じられない設定）、
      // UIの整合性を保つために停止することが望ましい場合がある。
      // ただし、barrierDismissible: false のため、このケースは通常発生しない。
      // もし再生が続いていたら停止するロジックは playerStateStream にもある。
      if (_audioPlayer.state == PlayerState.playing && _loopMode == CustomLoopMode.off && !_isShuffling) {
          // _audioPlayer.stop(); // ここで停止すると、曲の終わりに自動で閉じる挙動と競合する可能性あり
      }
    });
  }

  void _playAudioAtIndex(int index, {bool playImmediately = true}) async {
    if (!mounted || _audioFiles.isEmpty || index < 0 || index >= _audioFiles.length) return;

    if (_isAlertDialogShown && mounted) {
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      _isAlertDialogShown = false; 
    }

    await _audioPlayer.stop();

    setState(() {
      _currentPlayingAudioSourceIndex = index;
      if (playImmediately) _isPlaying = true;
    });

    if (mounted && playImmediately) _showPlayingAlertDialog();

    final source = AssetSource(_audioFiles[index]['path']!);

    // 常にReleaseモードに設定（Repeat OneはonPlayerCompleteでハンドリングする）
    await _audioPlayer.setReleaseMode(ReleaseMode.release);
    
    if (playImmediately) {
      await _audioPlayer.play(source);
      await _audioPlayer.setPlaybackRate(_currentSpeed);
    } else {
      await _audioPlayer.setSource(source);
      await _audioPlayer.setPlaybackRate(_currentSpeed);
    }
  }

  void _generateShuffledList() {
    if (!_isShuffling || _audioFiles.isEmpty) {
      _shuffledIndices = [];
      _currentShuffledQueueIndex = -1;
      return;
    }
    _shuffledIndices = List<int>.generate(_audioFiles.length, (i) => i);
    _shuffledIndices.shuffle(_random);
    _currentShuffledQueueIndex = -1; // 次に再生する際にインクリメントして0から開始
  }

  void _toggleShuffle() {
    setState(() {
      _isShuffling = !_isShuffling;
      if (_isShuffling) {
        _generateShuffledList();
      } else {
        _shuffledIndices = [];
        _currentShuffledQueueIndex = -1;
      }
    });
    _updatePlayerMode();
  }

  void _toggleRepeat() {
    setState(() {
      if (_loopMode == CustomLoopMode.off) {
        _loopMode = CustomLoopMode.one;
      } else if (_loopMode == CustomLoopMode.one) {
        _loopMode = CustomLoopMode.all;
      } else {
        _loopMode = CustomLoopMode.off;
      }
      // シャッフル中にリピートモードを変更した場合、次の曲の選択ロジックに影響する
      // 特に、シャッフルリストの終端に達したときの挙動が変わる
      if (_isShuffling && _loopMode != CustomLoopMode.all) {
          // もしシャッフル中で全曲リピートでなくなった場合、
          // 現在のシャッフルキューを最後まで再生したら止まるようになる。
          // 必要であれば _generateShuffledList() を呼んでキューをリセットするなどの制御も可能。
      }
    });
    _updatePlayerMode();
  }

  void _updatePlayerMode() {
    if (_audioPlayer.source == null || _currentPlayingAudioSourceIndex == null) return;
    // 常にReleaseモードに設定（Repeat Oneの処理はonPlayerCompleteで行うため）
    _audioPlayer.setReleaseMode(ReleaseMode.release);
  }

  void _changeSpeed() {
    _currentSpeedIndex = (_currentSpeedIndex + 1) % _speeds.length;
    _currentSpeed = _speeds[_currentSpeedIndex];
    _audioPlayer.setPlaybackRate(_currentSpeed);
    setState(() {});
  }

  IconData _getRepeatIcon() {
    if (_loopMode == CustomLoopMode.one) return Icons.repeat_one;
    if (_loopMode == CustomLoopMode.all) return Icons.repeat_on; // just_audio の Icons.repeat_on に相当
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
        actions: [ // 追加
          IconButton(
            icon: const Icon(Icons.timer_outlined, color: Colors.white),
            tooltip: 'タバタタイマー',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TabataTimerPage(audioFiles: _audioFiles),
                ),
              );
            },
          ),
        ],
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
                        margin: const EdgeInsets.only(top: 0),
                        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color.fromARGB(255, 41, 41, 41).withOpacity(0.6),
                              const Color.fromARGB(255, 25, 25, 25)!.withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(20),
                            bottomRight: Radius.circular(20),
                          ),
                          border: Border.all(
                            color: Colors.red.withOpacity(0.3),
                            width: 0,
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
                                _isShuffling ? Icons.shuffle : Icons.shuffle,
                                color: _isShuffling
                                    ? _getActiveIconColor(context)
                                    : _getInactiveIconColor(context),
                                size: 28,
                              ),
                              onPressed:_toggleShuffle,
                              tooltip: _isShuffling ? 'Shuffle Off' : 'Shuffle On',
                            ),
                            IconButton(
                              icon: Icon(
                                _getRepeatIcon(),
                                color: _loopMode != CustomLoopMode.off
                                    ? _getActiveIconColor(context)
                                    : _getInactiveIconColor(context),
                                size: 28,
                              ),
                              onPressed: _toggleRepeat,
                              tooltip: _loopMode == CustomLoopMode.one
                                  ? 'Repeat One'
                                  : (_loopMode == CustomLoopMode.all
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
                       //     IconButton( // 追加: 停止ボタン
                       //       icon: Icon(
                       //         Icons.stop,
                       //         color: _getInactiveIconColor(context), // 必要に応じて色を調整
                       //         size: 28,
                       //       ),
                       //       onPressed: () {
                       //         _audioPlayer.stop();
                       //         // コントロールパネルの停止ボタンが押されたときもアラートを閉じる
                       //         if (_isAlertDialogShown && mounted) {
                       //           if (Navigator.of(context, rootNavigator: true).canPop()) {
                       //              Navigator.of(context, rootNavigator: true).pop();
                       //           }
                       //           _isAlertDialogShown = false;
                       //         }
                       //       },
                       //       tooltip: 'Stop',
                       //     ),
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
                                          colors: 
                                              [Colors.grey[600]!, Colors.grey[700]!],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        isCurrentlyPlayingTrack && _isPlaying
                                            ? (_isShuffling && _loopMode == CustomLoopMode.all ? Icons.shuffle_on_outlined : Icons.volume_up) // シャッフル中アイコン変更の可能性
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

// 新しい StatefulWidget を追加
class _ZoomableImageDialogContent extends StatefulWidget {
  final String? imagePath;
  final String audioName;

  const _ZoomableImageDialogContent({
    Key? key,
    required this.imagePath,
    required this.audioName,
  }) : super(key: key);

  @override
  _ZoomableImageDialogContentState createState() =>
      _ZoomableImageDialogContentState();
}

class _ZoomableImageDialogContentState
    extends State<_ZoomableImageDialogContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 10), // ズームにかかる時間
      vsync: this,
    )..forward(); // アニメーションを開始

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.linear, // ゆっくりズームイン
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.imagePath != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 15.0),
            child: ScaleTransition( // <-- ScaleTransition を使用
              scale: _scaleAnimation,
              child: Image.asset(
                widget.imagePath!,
               // height: 500,
                fit: BoxFit.contain,
              ),
            ),
          ),
        Container(
          constraints: const BoxConstraints(minHeight: 70),
          child: Text(
            widget.audioName,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, color: Colors.white),
          ),
        ),
      ],
    );
  }
}
