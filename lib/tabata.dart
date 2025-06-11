import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart'; // just_audio を audioplayers に変更
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:io';

class TabataTimerPage extends StatefulWidget {
  final List<Map<String, String>> audioFiles;

  const TabataTimerPage({super.key, required this.audioFiles});

  @override
  State<TabataTimerPage> createState() => _TabataTimerPageState();
}

class _TabataTimerPageState extends State<TabataTimerPage> {
  // Timer settings
  int _countdownDuration = 5; // 追加: カウントダウン時間（秒）
  int _workDuration = 20; // seconds
  int _restDuration = 10; // seconds
  int _rounds = 8;

  // Timer state
  int _currentRound = 1;
  int _currentTime = 0; // in seconds
  bool _isWorkTime = true;
  bool _isRunning = false;
  Timer? _timer;
  bool _isCountingDown = false; // 追加: カウントダウン中かどうかのフラグ
  int _currentCountdownTime = 0; // 追加: 現在のカウントダウン残り時間

  // Audio
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _roundStartPlayer = AudioPlayer();
  String? _selectedAudioPath;
  bool _playRandomSong = false;
  String? _selectedRoundStartAudioPath;
  bool _playRandomRoundStartSong = false;

  // Banner Ad
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;
  final String _bannerAdUnitId = Platform.isAndroid
      ? 'ca-app-pub-7148683667182672/5530984071' // Androidのテスト広告IDまたは本番ID
      : 'ca-app-pub-7148683667182672/6456218782'; // iOSのテスト広告IDまたは本番ID

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
    _currentCountdownTime = _countdownDuration;
    _currentTime = _workDuration;
    if (widget.audioFiles.isNotEmpty) {
      // デフォルトで最初の曲を選択
      _selectedRoundStartAudioPath = widget.audioFiles.first['path'];
      _selectedAudioPath = widget.audioFiles.first['path']; // こちらも同様に初期化
    } else {
      // widget.audioFilesが空の場合の処理
      debugPrint("Audio files list is empty in TabataTimerPage initState.");
      _selectedRoundStartAudioPath = null;
      _selectedAudioPath = null;
    }
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: _bannerAdUnitId,
      request: const AdRequest(),
      size: AdSize.banner, // Tabataページでは通常のバナーサイズを使用
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
    _timer?.cancel();
    _audioPlayer.dispose();
    _roundStartPlayer.dispose(); // 追加
    _bannerAd?.dispose();
    super.dispose();
  }

  void _startTimer() {
    if (_isRunning && !_isCountingDown) return; // 通常タイマー実行中は何もしない
    if (_isRunning && _isCountingDown) return; // カウントダウン実行中は何もしない

    _timer?.cancel(); // 既存のタイマーがあればキャンセル

    // 一時停止からの再開かどうか
    if (!_isRunning && (_currentTime < _workDuration || _currentCountdownTime < _countdownDuration) && (_currentTime > 0 || _currentCountdownTime > 0) ) {
       // カウントダウン中の一時停止からの再開
      if(_isCountingDown && _currentCountdownTime > 0 && _currentCountdownTime < _countdownDuration){
        setState(() {
          _isRunning = true;
          // _isCountingDown は true のまま
        });
        _timer = Timer.periodic(const Duration(seconds: 1), _countdownTick);
      }
      // 通常タイマーの一時停止からの再開
      else if (!_isCountingDown && _currentTime > 0 && _currentTime < (_isWorkTime ? _workDuration : _restDuration) ){
        setState(() {
          _isRunning = true;
          // _isWorkTime はそのまま
        });
        _timer = Timer.periodic(const Duration(seconds: 1), _tick);
      }
      return;
    }


    // 新規開始またはリセット後の開始
    if (_countdownDuration > 0) {
      setState(() {
        _isCountingDown = true;
        _currentCountdownTime = _countdownDuration;
        _isRunning = true;
        _currentRound = 1;
        _isWorkTime = true;
        _currentTime = _workDuration;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), _countdownTick);
    } else {
      setState(() {
        _isCountingDown = false;
        _isRunning = true;
        _currentRound = 1;
        _isWorkTime = true;
        _currentTime = _workDuration;
      });
      _playRoundStartSound();
      _timer = Timer.periodic(const Duration(seconds: 1), _tick);
    }
  }

  void _pauseTimer() {
    if (!_isRunning) return;
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      // _isCountingDown の状態は維持する
      // _currentTime や _currentCountdownTime も維持する
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _currentRound = 1;
      _isWorkTime = true;
      _currentTime = _workDuration;
      _isRunning = false;
      _isCountingDown = false; // カウントダウン状態もリセット
      _currentCountdownTime = _countdownDuration; // カウントダウン時間も初期値に
    });
  }

  void _countdownTick(Timer timer) {
    if (!_isRunning) { // 一時停止された場合
      return;
    }
    setState(() {
      if (_currentCountdownTime > 1) {
        _currentCountdownTime--;
      } else {
        // カウントダウン終了
        timer.cancel(); // カウントダウンタイマーをキャンセル
        _isCountingDown = false;
        // 本タイマースタート (状態は_startTimerで初期化済み)
        _playRoundStartSound(); // 最初のラウンド開始音
        _timer = Timer.periodic(const Duration(seconds: 1), _tick); // 通常タイマーを開始
      }
    });
  }

  void _tick(Timer timer) {
    if (!_isRunning) {
      timer.cancel();
      return;
    }

    setState(() {
      if (_currentTime > 1) {
        _currentTime--;
      } else {
        // Time's up for current phase (work/rest)
        if (_isWorkTime) {
          // Work time finished, start rest time
          _isWorkTime = false;
          _currentTime = _restDuration;
          _playRoundEndSoundIfNeeded(); // Play sound after work interval
        } else {
          // Rest time finished
          if (_currentRound < _rounds) {
            _currentRound++;
            _isWorkTime = true;
            _currentTime = _workDuration;
            _playRoundStartSound(); // ラウンド開始音を再生
          } else {
            // All rounds completed
            _timer?.cancel();
            _isRunning = false;
            // Optionally play a final sound or show completion message
            _showCompletionDialog();
          }
        }
      }
    });
  }

  Future<void> _playRoundStartSound() async {
    if (_roundStartPlayer.state == PlayerState.playing) await _roundStartPlayer.stop();

    String? pathToPlay;

    if (_playRandomRoundStartSong) {
      if (widget.audioFiles.isNotEmpty) {
        final randomIndex = Random().nextInt(widget.audioFiles.length);
        pathToPlay = widget.audioFiles[randomIndex]['path'];
        debugPrint("Playing random round start sound: $pathToPlay");
      } else {
        debugPrint("Cannot play random round start sound: audioFiles is empty.");
        return;
      }
    } else {
      pathToPlay = _selectedRoundStartAudioPath;
      debugPrint("Playing selected round start sound: $pathToPlay");
    }

    if (pathToPlay != null && pathToPlay.isNotEmpty) {
      try {
        await _roundStartPlayer.play(AssetSource(pathToPlay));
      } catch (e) {
        debugPrint("Error playing round start sound at path '$pathToPlay': $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('ラウンド開始音の再生エラー: $e')),
          );
        }
      }
    } else {
      debugPrint("Round start sound path is null or empty. Cannot play.");
    }
  }

  Future<void> _playRoundEndSoundIfNeeded() async {
    if (_selectedAudioPath == null && !_playRandomSong) return;
    if (_audioPlayer.state == PlayerState.playing) await _audioPlayer.stop();

    String? pathToPlay;
    if (_playRandomSong && widget.audioFiles.isNotEmpty) {
      final randomIndex = Random().nextInt(widget.audioFiles.length);
      pathToPlay = widget.audioFiles[randomIndex]['path'];
    } else {
      pathToPlay = _selectedAudioPath;
    }

    if (pathToPlay != null) {
      try {
        await _audioPlayer.play(AssetSource(pathToPlay));
      } catch (e) {
        debugPrint("Error playing sound: $e");
        if (mounted) { // mounted を確認
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error playing audio: ${e.toString()}')),
          );
        }
      }
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('タバタ完了！'),
          content: const Text('お疲れ様でした！'),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
                _resetTimer();
              },
            ),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    bool isPaused = !_isRunning && (_currentTime < _workDuration || _currentCountdownTime < _countdownDuration) && (_currentTime > 0 || _currentCountdownTime > 0) && (_isCountingDown || _currentRound >=1 );
    String startButtonText = _isRunning ? '一時停止' : (isPaused ? '再開' : '開始');
    IconData startButtonIcon = _isRunning ? Icons.pause : Icons.play_arrow;

    return Scaffold(
      appBar: AppBar(
        title: const Text('タバタタイマー'),
        backgroundColor: Colors.black,
      ),
      bottomNavigationBar: _isBannerAdLoaded && _bannerAd != null
          ? Container(
              color: Colors.black,
              height: _bannerAd!.size.height.toDouble(),
              width: _bannerAd!.size.width.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            )
          : null,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black, Colors.grey[900]!, Colors.black],
          ),
        ),
        padding: const EdgeInsets.all(16.0),
        child: Column( // Main column
          mainAxisAlignment: MainAxisAlignment.center, // タイマー実行中は全体を中央寄せ
          crossAxisAlignment: CrossAxisAlignment.stretch, // 子要素の幅を最大にするために追加
          children: <Widget>[
            // Timer Display
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center, // 横方向中央揃え
              children: [
                Text(
                  _isCountingDown
                      ? '準備中...'
                      : (_isWorkTime ? 'WORK' : 'REST'),
                  textAlign: TextAlign.center, // テキスト自体も中央揃え
                  style: TextStyle(
                      fontSize: 48, // 例えば、画面幅に応じて調整
                      fontWeight: FontWeight.bold,
                      color: _isCountingDown
                          ? Colors.blueAccent
                          : (_isWorkTime ? Colors.greenAccent : Colors.orangeAccent)),
                ),
                FittedBox( // 時刻表示にFittedBoxを適用する例
                  fit: BoxFit.contain,
                  child: Text(
                    _isCountingDown
                        ? _currentCountdownTime.toString()
                        : '${(_currentTime ~/ 60).toString().padLeft(2, '0')}:${(_currentTime % 60).toString().padLeft(2, '0')}',
                    textAlign: TextAlign.center, // テキスト自体も中央揃え
                    style: const TextStyle(fontSize: 96, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                if (!_isCountingDown)
                  Text(
                    'ラウンド: $_currentRound / $_rounds',
                    textAlign: TextAlign.center, // テキスト自体も中央揃え
                    style: const TextStyle(fontSize: 24, color: Colors.white70),
                  ),
              ],
            ),
            const SizedBox(height: 30), // Space between timer and buttons

            // Control Buttons
            Wrap( // Rowの代わりにWrapを使用
              alignment: WrapAlignment.spaceEvenly,
              spacing: 8.0, // 要素間の横スペース
              runSpacing: 8.0, // 行間の縦スペース
              children: <Widget>[
                ElevatedButton.icon(
                  icon: Icon(startButtonIcon),
                  label: Text(startButtonText),
                  onPressed: _isRunning ? _pauseTimer : _startTimer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isRunning ? Colors.orange : Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('リセット'),
                  onPressed: _resetTimer, // リセットボタンは常に有効
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),

            // Settings (Scrollable, shown only when timer is not running)
            if (!_isRunning && !isPaused) // タイマーが実行中でなく、一時停止中でもない場合のみ表示
              Expanded(
                child: Padding( // 設定項目とボタンの間にスペースを確保
                  padding: const EdgeInsets.only(top: 30.0),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildSettingsRow(
                          label: '準備時間 (秒):',
                          value: _countdownDuration,
                          onChanged: (val) => setState(() {
                            _countdownDuration = val;
                            if (!_isRunning) {
                              _currentCountdownTime = _countdownDuration;
                            }
                          }),
                          minValue: 0,
                        ),
                        _buildSettingsRow(
                          label: '運動 (秒):',
                          value: _workDuration,
                          onChanged: (val) => setState(() {
                            _workDuration = val;
                            if (_isWorkTime && !_isRunning) _currentTime = _workDuration;
                          }),
                        ),
                        _buildSettingsRow(
                          label: '休憩 (秒):',
                          value: _restDuration,
                          onChanged: (val) => setState(() {
                            _restDuration = val;
                            if (!_isWorkTime && !_isRunning) _currentTime = _restDuration;
                          }),
                        ),
                        _buildSettingsRow(
                          label: 'ラウンド:',
                          value: _rounds,
                          onChanged: (val) => setState(() => _rounds = val),
                          minValue: 1,
                        ),
                        const SizedBox(height: 20),
                        // Round Start Song Selection
                        if (widget.audioFiles.isNotEmpty)
                          Card(
                            color: Colors.grey[850]?.withOpacity(0.8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                              child: DropdownButtonFormField<String>(
                                decoration: const InputDecoration(
                                  labelText: 'ラウンド開始時の曲',
                                  labelStyle: TextStyle(color: Colors.white70),
                                  border: InputBorder.none,
                                ),
                                dropdownColor: Colors.grey[800],
                                value: _selectedRoundStartAudioPath,
                                items: widget.audioFiles.map((file) {
                                  return DropdownMenuItem<String>(
                                    value: file['path'],
                                    child: Text(file['name']!, style: const TextStyle(color: Colors.white)),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedRoundStartAudioPath = value;
                                  });
                                },
                                isExpanded: true,
                              ),
                            ),
                          ),
                        if (widget.audioFiles.isNotEmpty)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('開始時ランダム再生', style: TextStyle(color: Colors.white70)),
                              Switch(
                                value: _playRandomRoundStartSong,
                                onChanged: (value) {
                                  setState(() {
                                    _playRandomRoundStartSong = value;
                                  });
                                },
                                activeColor: theme.colorScheme.primary,
                              ),
                            ],
                          ),
                        const SizedBox(height: 10),

                        // Round End Song Selection
                        if (widget.audioFiles.isNotEmpty)
                          Card(
                            color: Colors.grey[850]?.withOpacity(0.8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                              child: DropdownButtonFormField<String>(
                                decoration: const InputDecoration(
                                  labelText: 'ラウンド終了時の曲',
                                  labelStyle: TextStyle(color: Colors.white70),
                                  border: InputBorder.none,
                                ),
                                dropdownColor: Colors.grey[800],
                                value: _selectedAudioPath,
                                items: widget.audioFiles.map((file) {
                                  return DropdownMenuItem<String>(
                                    value: file['path'],
                                    child: Text(file['name']!, style: const TextStyle(color: Colors.white)),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedAudioPath = value;
                                  });
                                },
                                isExpanded: true,
                              ),
                            ),
                          ),
                        if (widget.audioFiles.isNotEmpty)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('ランダム再生', style: TextStyle(color: Colors.white70)),
                              Switch(
                                value: _playRandomSong,
                                onChanged: (value) {
                                  setState(() {
                                    _playRandomSong = value;
                                  });
                                },
                                activeColor: theme.colorScheme.primary,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsRow({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
    int minValue = 1,
    int maxValue = 300, // Max 5 minutes for work/rest, or 50 rounds
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16, color: Colors.white70)),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: Colors.white70),
                onPressed: _isRunning || value <= minValue
                    ? null
                    : () => onChanged(value - (label == 'ラウンド:'||label =='準備時間 (秒):'? 1 : 5)),
              ),
              Text('$value', style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: Colors.white70),
                onPressed: _isRunning || value >= maxValue
                    ? null
                    : () => onChanged(value + (label == 'ラウンド:' || label =='準備時間 (秒):' ? 1 : 5)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}