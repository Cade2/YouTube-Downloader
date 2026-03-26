import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../models/video_info.dart';
import '../services/youtube_service.dart';
import '../widgets/download_button.dart';
import '../widgets/format_toggle.dart';
import '../widgets/progress_card.dart';
import '../widgets/quality_dropdown.dart';
import '../widgets/shimmer_loader.dart';
import '../widgets/sound_wave_widget.dart';
import '../widgets/video_info_card.dart';

enum _ScreenState { idle, loading, ready, downloading }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _urlController = TextEditingController();
  final _scrollController = ScrollController();
  final _youtubeService = YouTubeService();

  late final AnimationController _successController;
  late final Animation<double> _successScale;

  _ScreenState _screenState = _ScreenState.idle;
  MediaFormat _selectedFormat = MediaFormat.mp4;
  VideoInfo? _videoInfo;
  List<StreamOption> _videoOptions = const [];
  List<StreamOption> _audioOptions = const [];
  StreamOption? _selectedOption;
  DownloadProgress _downloadProgress = const DownloadProgress.zero();
  String? _errorMessage;
  String? _successMessage;
  Timer? _successTimer;

  bool get _isLoading => _screenState == _ScreenState.loading;
  bool get _isDownloading => _screenState == _ScreenState.downloading;
  bool get _hasVideo => _videoInfo != null;
  bool get _isAudioMode => _selectedFormat == MediaFormat.mp3;
  Color get _accent =>
      _isAudioMode ? PullTubeColors.audioAccent : PullTubeColors.videoAccent;

  List<StreamOption> get _activeOptions =>
      _isAudioMode ? _audioOptions : _videoOptions;

  @override
  void initState() {
    super.initState();
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _successScale = CurvedAnimation(
      parent: _successController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _successTimer?.cancel();
    _successController.dispose();
    _urlController.dispose();
    _scrollController.dispose();
    _youtubeService.dispose();
    super.dispose();
  }

  Future<void> _pasteAndFetch() async {
    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clipboard?.text?.trim() ?? '';
    if (text.isEmpty) {
      _showError('Clipboard is empty. Copy a YouTube URL first.');
      return;
    }
    _urlController.text = text;
    await _fetchVideoInfo();
  }

  Future<void> _fetchVideoInfo() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _showError('Paste a YouTube URL to start.');
      return;
    }

    setState(() {
      _screenState = _ScreenState.loading;
      _errorMessage = null;
      _successMessage = null;
      _videoInfo = null;
      _videoOptions = const [];
      _audioOptions = const [];
      _selectedOption = null;
    });

    try {
      final result = await _youtubeService.fetchVideoInfo(url);
      if (!mounted) {
        return;
      }

      final defaultFormat = result.videoOptions.isNotEmpty
          ? MediaFormat.mp4
          : MediaFormat.mp3;
      final defaultOptions = defaultFormat == MediaFormat.mp4
          ? result.videoOptions
          : result.audioOptions;

      setState(() {
        _screenState = _ScreenState.ready;
        _selectedFormat = defaultFormat;
        _videoInfo = result.videoInfo;
        _videoOptions = result.videoOptions;
        _audioOptions = result.audioOptions;
        _selectedOption = defaultOptions.isEmpty ? null : defaultOptions.first;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent.clamp(0, 420),
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
          );
        }
      });
    } on YouTubeServiceException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _screenState = _ScreenState.idle;
        _errorMessage = error.message;
      });
    }
  }

  void _onFormatChanged(MediaFormat format) {
    final options = format == MediaFormat.mp4 ? _videoOptions : _audioOptions;
    setState(() {
      _selectedFormat = format;
      _selectedOption = options.isEmpty ? null : options.first;
      _errorMessage = null;
      _successMessage = null;
    });
  }

  Future<void> _downloadSelectedStream() async {
    final videoInfo = _videoInfo;
    final selectedOption = _selectedOption;
    if (videoInfo == null || selectedOption == null) {
      _showError('Choose a stream option before downloading.');
      return;
    }

    setState(() {
      _screenState = _ScreenState.downloading;
      _downloadProgress = const DownloadProgress.zero();
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final result = await _youtubeService.downloadSelection(
        videoInfo: videoInfo,
        option: selectedOption,
        format: _selectedFormat,
        onProgress: (progress) {
          if (!mounted) {
            return;
          }
          setState(() {
            _downloadProgress = progress;
          });
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _screenState = _ScreenState.ready;
      });
      _showSuccess(
        result.savedToGallery ? 'Saved to Gallery' : 'Saved to Files',
      );
    } on YouTubeServiceException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _screenState = _ScreenState.ready;
      });
      _showError(error.message);
    }
  }

  void _reset() {
    _successTimer?.cancel();
    _urlController.clear();
    setState(() {
      _screenState = _ScreenState.idle;
      _selectedFormat = MediaFormat.mp4;
      _videoInfo = null;
      _videoOptions = const [];
      _audioOptions = const [];
      _selectedOption = null;
      _downloadProgress = const DownloadProgress.zero();
      _errorMessage = null;
      _successMessage = null;
    });
  }

  void _showSuccess(String message) {
    _successTimer?.cancel();
    setState(() {
      _successMessage = message;
      _errorMessage = null;
    });
    _successController.forward(from: 0);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: PullTubeColors.success,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
    _successTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _successMessage = null;
      });
    });
  }

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
      _successMessage = null;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: PullTubeColors.error,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final showCompatBanner =
        !_isAudioMode && _videoOptions.any((option) => !option.hasAudio);

    return Scaffold(
      body: Stack(
        children: [
          Container(color: PullTubeColors.background),
          _buildBackdrop(),
          SafeArea(
            child: ListView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              children: [
                _buildHeader(),
                const SizedBox(height: 22),
                _buildUrlCard(),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 14),
                  _buildNotice(
                    title: 'Fetch issue',
                    message: _errorMessage!,
                    color: PullTubeColors.error,
                    icon: Icons.info_outline_rounded,
                  ),
                ],
                if (_successMessage != null) ...[
                  const SizedBox(height: 14),
                  ScaleTransition(
                    scale: _successScale,
                    child: _buildNotice(
                      title: 'Complete',
                      message: _successMessage!,
                      color: PullTubeColors.success,
                      icon: Icons.check_circle_rounded,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                if (_isLoading)
                  const ShimmerLoader()
                else if (!_hasVideo)
                  _buildIdleCard()
                else ...[
                  VideoInfoCard(
                    info: _videoInfo!,
                    accent: _accent,
                    isAudioMode: _isAudioMode,
                  ),
                  const SizedBox(height: 18),
                  if (_isAudioMode) _buildAudioBanner(),
                  if (showCompatBanner) _buildCompatBanner(),
                  if (_isAudioMode || showCompatBanner)
                    const SizedBox(height: 18),
                  FormatToggle(
                    selected: _selectedFormat,
                    onChanged: _isDownloading ? null : _onFormatChanged,
                  ),
                  const SizedBox(height: 16),
                  QualityDropdown(
                    options: _activeOptions,
                    selected: _selectedOption,
                    format: _selectedFormat,
                    enabled: !_isDownloading,
                    onChanged: (value) =>
                        setState(() => _selectedOption = value),
                  ),
                  if (_isDownloading) ...[
                    const SizedBox(height: 16),
                    ProgressCard(
                      progress: _downloadProgress,
                      format: _selectedFormat,
                    ),
                  ],
                  const SizedBox(height: 16),
                  DownloadButton(
                    format: _selectedFormat,
                    isEnabled: !_isDownloading && _selectedOption != null,
                    isBusy: _isDownloading,
                    onPressed: _downloadSelectedStream,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackdrop() {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -120,
            right: -50,
            child: _BackdropOrb(color: _accent, size: 240),
          ),
          Positioned(
            top: 220,
            left: -80,
            child: _BackdropOrb(
              color: _isAudioMode
                  ? PullTubeColors.audioAccentDeep
                  : PullTubeColors.videoAccentDeep,
              size: 180,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        colors: [_accent, _accent.withValues(alpha: 0.72)],
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: const [
                        Icon(Icons.bolt_rounded, color: Colors.white, size: 28),
                        Positioned(
                          bottom: 9,
                          child: Icon(
                            Icons.arrow_downward_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PullTube',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.1,
                          ),
                        ),
                        Text(
                          _isAudioMode
                              ? 'Audio mode is armed with warm bitrate controls.'
                              : 'Premium personal downloads with full stream visibility.',
                          style: const TextStyle(
                            color: PullTubeColors.textSecondary,
                            fontSize: 13.5,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_hasVideo)
                    IconButton(
                      onPressed: _isDownloading ? null : _reset,
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: PullTubeColors.textSecondary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricPill(
                      'Theme',
                      _isAudioMode ? 'Audio' : 'Video',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricPill(
                      'Outputs',
                      _isAudioMode ? 'Files' : 'Gallery',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: PullTubeColors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: PullTubeColors.border),
                      ),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _isAudioMode
                                    ? Icons.graphic_eq_rounded
                                    : Icons.high_quality_rounded,
                                color: _accent,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _isAudioMode
                                    ? 'Bitrate-first'
                                    : 'Muxed + VideoOnly',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (_isAudioMode) ...[
                                const SizedBox(width: 12),
                                const SoundWaveWidget(
                                  color: PullTubeColors.audioAccent,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricPill(String title, String value) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: PullTubeColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PullTubeColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: PullTubeColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(color: _accent, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildUrlCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: PullTubeColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: _isLoading || _isDownloading
              ? _accent.withValues(alpha: 0.6)
              : PullTubeColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'YouTube URL',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: PullTubeColors.textSecondary,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _urlController,
            enabled: !_isDownloading,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _fetchVideoInfo(),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.go,
            autocorrect: false,
            decoration: InputDecoration(
              hintText: 'https://youtube.com/watch?v=...',
              suffixIcon: _urlController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: _isDownloading
                          ? null
                          : () => setState(_urlController.clear),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: PullTubeColors.textMuted,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 8,
                child: _buildActionButton(
                  title: 'Paste & Fetch',
                  icon: Icons.content_paste_go_rounded,
                  enabled: !_isDownloading,
                  filled: true,
                  onTap: _pasteAndFetch,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 5,
                child: _buildActionButton(
                  title: 'Fetch',
                  icon: Icons.north_east_rounded,
                  enabled:
                      !_isDownloading && _urlController.text.trim().isNotEmpty,
                  filled: false,
                  onTap: _fetchVideoInfo,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String title,
    required IconData icon,
    required bool enabled,
    required bool filled,
    required FutureOr<void> Function() onTap,
  }) {
    final gradient = filled
        ? LinearGradient(colors: [_accent, _accent.withValues(alpha: 0.75)])
        : null;

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: InkWell(
        onTap: enabled ? () => onTap() : null,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          height: 54,
          decoration: BoxDecoration(
            color: filled ? null : PullTubeColors.surfaceSecondary,
            gradient: gradient,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: filled
                  ? Colors.transparent
                  : _accent.withValues(alpha: 0.24),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotice({
    required String title,
    required String message,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PullTubeColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 5),
                Text(
                  message,
                  style: const TextStyle(
                    color: PullTubeColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdleCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: PullTubeColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: PullTubeColors.border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IdleTile(
            icon: Icons.auto_awesome_rounded,
            title: 'Paste a link and fetch instantly',
            message:
                'PullTube surfaces metadata fast, then preselects the highest quality stream option available.',
          ),
          SizedBox(height: 14),
          _IdleTile(
            icon: Icons.high_quality_rounded,
            title: 'See every quality tier',
            message:
                'MP4 combines muxed and video-only manifests, deduplicated by height and sorted from highest to lowest.',
          ),
          SizedBox(height: 14),
          _IdleTile(
            icon: Icons.graphic_eq_rounded,
            title: 'Switch into audio mode',
            message:
                'Warm amber styling, bitrate-first choices, animated wave feedback, and Files saving for audio downloads.',
          ),
        ],
      ),
    );
  }

  Widget _buildAudioBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PullTubeColors.audioAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: PullTubeColors.audioAccent.withValues(alpha: 0.26),
        ),
      ),
      child: const Row(
        children: [
          SoundWaveWidget(color: PullTubeColors.audioAccent),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Audio mode highlights bitrate options and saves the downloaded file into PullTube documents for Files access.',
              style: TextStyle(
                color: PullTubeColors.audioAccentDeep,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompatBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PullTubeColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: PullTubeColors.borderStrong),
      ),
      child: const Text(
        'Higher resolutions can appear as video-only because YouTube does not always expose a muxed stream at every height. PullTube will pair those selections with audio before saving.',
        style: TextStyle(color: PullTubeColors.textSecondary, height: 1.45),
      ),
    );
  }
}

class _BackdropOrb extends StatelessWidget {
  const _BackdropOrb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: 0.28),
            color.withValues(alpha: 0.04),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

class _IdleTile extends StatelessWidget {
  const _IdleTile({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: PullTubeColors.surfaceSecondary,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: PullTubeColors.border),
          ),
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                message,
                style: const TextStyle(
                  color: PullTubeColors.textSecondary,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
