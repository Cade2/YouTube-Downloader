import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

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

enum _AppState { idle, loading, ready, downloading, error }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  // ─── Controllers ────────────────────────────────────────────────────────────
  final _urlController = TextEditingController();
  final _scrollController = ScrollController();
  late final AnimationController _successCtrl;
  late final Animation<double> _successScale;

  // ─── State ──────────────────────────────────────────────────────────────────
  _AppState _state = _AppState.idle;
  String? _errorMessage;
  VideoInfo? _videoInfo;
  List<StreamOption> _videoStreams = [];
  List<StreamOption> _audioStreams = [];
  StreamOption? _selectedStream;
  MediaFormat _format = MediaFormat.mp4;
  double _downloadProgress = 0;
  double _downloadSpeed = 0;

  StreamSubscription<DownloadProgress>? _downloadSub;

  // ─── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _successCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _successScale = CurvedAnimation(
      parent: _successCtrl,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    _scrollController.dispose();
    _successCtrl.dispose();
    _downloadSub?.cancel();
    YouTubeService.instance.dispose();
    super.dispose();
  }

  // ─── Actions ─────────────────────────────────────────────────────────────────

  Future<void> _pasteAndFetch() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) return;
    _urlController.text = text;
    await _fetchVideoInfo(text);
  }

  Future<void> _fetchVideoInfo(String url) async {
    if (url.trim().isEmpty) return;
    setState(() {
      _state = _AppState.loading;
      _errorMessage = null;
      _videoInfo = null;
      _videoStreams = [];
      _audioStreams = [];
    });

    try {
      final result = await YouTubeService.instance.fetchVideoData(url);
      if (!mounted) return;

      if (result.videoStreams.isEmpty && result.audioStreams.isEmpty) {
        setState(() {
          _state = _AppState.error;
          _errorMessage =
              'No downloadable streams found for this video. It may be restricted or unavailable.';
        });
        return;
      }

      setState(() {
        _videoInfo = result.info;
        _videoStreams = result.videoStreams;
        _audioStreams = result.audioStreams;
        _format = MediaFormat.mp4;
        _selectedStream =
            result.videoStreams.isNotEmpty ? result.videoStreams.first : null;
        _state = _AppState.ready;
      });

      // Scroll down so controls are visible
      await Future.delayed(const Duration(milliseconds: 100));
      _scrollToBottom();
    } on FormatException catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _AppState.error;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _AppState.error;
        _errorMessage =
            'Could not load video. Check your internet connection and the URL.';
      });
    }
  }

  void _onFormatChanged(MediaFormat format) {
    final streams =
        format == MediaFormat.mp4 ? _videoStreams : _audioStreams;
    setState(() {
      _format = format;
      _selectedStream = streams.isNotEmpty ? streams.first : null;
    });
  }

  void _startDownload() {
    if (_selectedStream == null || _videoInfo == null) return;
    final isVideo = _format == MediaFormat.mp4;

    setState(() {
      _state = _AppState.downloading;
      _downloadProgress = 0;
      _downloadSpeed = 0;
    });

    _downloadSub?.cancel();
    _downloadSub = YouTubeService.instance
        .download(
          streamInfo: _selectedStream!.streamInfo,
          safeTitle: _videoInfo!.title,
          isVideo: isVideo,
          onComplete: (result) {
            if (!mounted) return;
            setState(() {
              _state = _AppState.ready;
              _downloadProgress = 0;
              _downloadSpeed = 0;
            });
            _successCtrl.forward(from: 0);
            final msg = result.savedToGallery
                ? 'Saved to Gallery'
                : 'Saved to Files';
            _showSuccessSnackbar(msg);
          },
          onError: (msg) {
            if (!mounted) return;
            setState(() {
              _state = _AppState.ready;
              _downloadProgress = 0;
              _downloadSpeed = 0;
            });
            _showErrorSnackbar(msg);
          },
        )
        .listen((event) {
      if (!mounted) return;
      setState(() {
        _downloadProgress = event.progress;
        if (event.speedMBps > 0) _downloadSpeed = event.speedMBps;
      });
    });
  }

  void _reset() {
    _downloadSub?.cancel();
    _urlController.clear();
    setState(() {
      _state = _AppState.idle;
      _errorMessage = null;
      _videoInfo = null;
      _videoStreams = [];
      _audioStreams = [];
      _selectedStream = null;
      _downloadProgress = 0;
      _downloadSpeed = 0;
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    }
  }

  // ─── Snackbars ──────────────────────────────────────────────────────────────

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Color(0xFF4CAF50), size: 20),
            const SizedBox(width: 10),
            Text(message,
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppColors.accent, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message,
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w500)),
            ),
          ],
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isAudio = _format == MediaFormat.mp3;
    final accent = isAudio ? AppColors.accentAudio : AppColors.accent;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(accent, isAudio),
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                children: [
                  _buildUrlInput(accent),
                  const SizedBox(height: 20),
                  _buildMainContent(isAudio, accent),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(Color accent, bool isAudio) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 4),
      child: Row(
        children: [
          // Logo / Title
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                style: GoogleFonts.dmSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
                child: const Text('PullTube'),
              ),
            ],
          ),
          const Spacer(),
          // Audio mode indicator
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: isAudio
                ? Padding(
                    key: const ValueKey('wave'),
                    padding: const EdgeInsets.only(right: 4),
                    child: const SoundWaveWidget(size: 24),
                  )
                : const SizedBox.shrink(key: ValueKey('empty')),
          ),
          // Reset button (shown when video is loaded)
          if (_state != _AppState.idle && _state != _AppState.loading)
            IconButton(
              icon: const Icon(Icons.close_rounded,
                  color: AppColors.textSecondary),
              onPressed: _state == _AppState.downloading ? null : _reset,
              tooltip: 'Clear',
            ),
        ],
      ),
    );
  }

  Widget _buildUrlInput(Color accent) {
    final hasText = _urlController.text.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _state == _AppState.loading || _state == _AppState.downloading
              ? accent.withOpacity(0.4)
              : AppColors.border,
        ),
        boxShadow: [
          if (_state == _AppState.loading || _state == _AppState.downloading)
            BoxShadow(
              color: accent.withOpacity(0.08),
              blurRadius: 20,
              spreadRadius: 2,
            ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YouTube URL',
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _urlController,
                  enabled: _state != _AppState.downloading,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w400,
                  ),
                  decoration: InputDecoration(
                    hintText: 'https://youtube.com/watch?v=…',
                    hintStyle: GoogleFonts.dmSans(
                      color: AppColors.textMuted,
                      fontSize: 14,
                    ),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                  onSubmitted: (url) => _fetchVideoInfo(url),
                  textInputAction: TextInputAction.go,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                ),
              ),
              if (hasText)
                GestureDetector(
                  onTap: () {
                    _urlController.clear();
                    setState(() {});
                  },
                  child: const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(Icons.cancel_rounded,
                        color: AppColors.textMuted, size: 18),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // Paste button
              _UrlActionButton(
                icon: Icons.content_paste_rounded,
                label: 'Paste & Fetch',
                color: accent,
                onTap: _state == _AppState.downloading
                    ? null
                    : _pasteAndFetch,
              ),
              const SizedBox(width: 10),
              // Fetch button (when URL is typed manually)
              if (hasText)
                _UrlActionButton(
                  icon: Icons.search_rounded,
                  label: 'Fetch',
                  color: AppColors.textSecondary,
                  onTap: _state == _AppState.downloading
                      ? null
                      : () => _fetchVideoInfo(_urlController.text),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(bool isAudio, Color accent) {
    switch (_state) {
      case _AppState.idle:
        return _buildIdleHint();

      case _AppState.loading:
        return Column(
          children: const [
            ShimmerLoader(),
            SizedBox(height: 16),
            ShimmerControls(),
          ],
        );

      case _AppState.error:
        return _buildErrorCard();

      case _AppState.ready:
      case _AppState.downloading:
        final streams =
            isAudio ? _audioStreams : _videoStreams;
        return Column(
          children: [
            // Video info card with entry animation
            if (_videoInfo != null)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
                builder: (_, v, child) => Opacity(
                  opacity: v,
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - v)),
                    child: child,
                  ),
                ),
                child: VideoInfoCard(info: _videoInfo!),
              ),

            const SizedBox(height: 20),

            // Audio mode badge
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: isAudio
                  ? _AudioModeBadge(key: const ValueKey('badge'))
                  : const SizedBox.shrink(key: ValueKey('empty')),
            ),
            if (isAudio) const SizedBox(height: 12),

            // Format toggle
            FormatToggle(
              selected: _format,
              onChanged: _state == _AppState.downloading
                  ? (_) {}
                  : _onFormatChanged,
            ),
            const SizedBox(height: 16),

            // Quality dropdown
            if (streams.isNotEmpty)
              QualityDropdown(
                options: streams,
                selected: _selectedStream,
                format: _format,
                onChanged: _state == _AppState.downloading
                    ? (_) {}
                    : (s) => setState(() => _selectedStream = s),
              ),

            const SizedBox(height: 16),

            // Progress card (downloading only)
            if (_state == _AppState.downloading)
              ProgressCard(
                progress: _downloadProgress,
                speedMBps: _downloadSpeed,
                format: _format,
              ),

            if (_state == _AppState.downloading) const SizedBox(height: 16),

            // Download button
            DownloadButton(
              format: _format,
              isEnabled: _state == _AppState.ready &&
                  _selectedStream != null,
              onPressed: _startDownload,
            ),
          ],
        );
    }
  }

  Widget _buildIdleHint() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Icons.link_rounded,
                color: AppColors.textMuted,
                size: 32,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Paste a YouTube URL above',
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Download videos in MP4 or\naudio tracks in MP3',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: AppColors.textMuted,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.accent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Something went wrong',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _errorMessage ?? 'An unexpected error occurred.',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => _fetchVideoInfo(_urlController.text),
                  child: Text(
                    'Try again',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Small helper widgets ──────────────────────────────────────────────────────

class _UrlActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _UrlActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: enabled ? color.withOpacity(0.12) : AppColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: enabled ? color.withOpacity(0.25) : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: enabled ? color : AppColors.textMuted),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: enabled ? color : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AudioModeBadge extends StatelessWidget {
  const _AudioModeBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.accentAudio.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accentAudio.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const SoundWaveWidget(size: 20),
          const SizedBox(width: 12),
          Text(
            'Audio mode — extracts the audio track only',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.accentAudio,
            ),
          ),
        ],
      ),
    );
  }
}
