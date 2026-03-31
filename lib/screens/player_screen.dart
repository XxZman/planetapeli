import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:better_player/better_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:screen_brightness/screen_brightness.dart';
import '../models/movie.dart';
import '../providers/history_provider.dart';

const _purple = Color(0xFF7B2FBE);
const _purpleLight = Color(0xFF9D4EDD);
const _blue = Color(0xFF2F86BE);

bool _isNativeUrl(String url) {
  final path = url.toLowerCase().split('?').first;
  return path.endsWith('.mp4') || path.endsWith('.m3u8');
}

String _fmt(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  if (h > 0) {
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

// ══════════════════════════════════════════════════════════════════════════════
// PlayerScreen
// ══════════════════════════════════════════════════════════════════════════════

class PlayerScreen extends StatefulWidget {
  final Movie movie;
  const PlayerScreen({super.key, required this.movie});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  BetterPlayerController? _betterCtrl;
  WebViewController? _webCtrl;

  List<VideoServer> _servers = [];
  VideoServer? _currentServer;
  bool _loading = false;
  String? _error;
  bool _useWebView = false;

  // Controls overlay
  bool _controlsVisible = true;
  Timer? _hideTimer;

  // Server panel
  bool _panelVisible = false;

  // Orientation — session preference, starts in portrait
  bool _isLandscape = false;

  // Filters
  String _selectedIdioma = 'Todos';
  String _selectedCalidad = 'Todos';

  // Brightness / Volume gesture state
  double _brightnessValue = 0.5;
  double _volumeValue = 1.0;
  bool _showBrightnessIndicator = false;
  bool _showVolumeIndicator = false;
  Timer? _indicatorHideTimer;

  // Toast
  OverlayEntry? _toastEntry;

  @override
  void initState() {
    super.initState();
    // Do NOT force landscape — respect user's current orientation
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    _servers = widget.movie.servidores;
    if (_servers.isNotEmpty) _loadServer(_servers.first);
    _scheduleHide();
    _initBrightness();
  }

  Future<void> _initBrightness() async {
    try {
      _brightnessValue = await ScreenBrightness().current;
    } catch (_) {}
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _indicatorHideTimer?.cancel();
    _betterCtrl?.removeEventsListener(_onPlayerEvent);
    _betterCtrl?.dispose();
    _toastEntry?.remove();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    try {
      ScreenBrightness().resetScreenBrightness();
    } catch (_) {}
    super.dispose();
  }

  // ── Controls visibility ────────────────────────────────────────────────────

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_panelVisible) setState(() => _controlsVisible = false);
    });
  }

  void _onTap() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) {
      _scheduleHide();
    } else {
      _hideTimer?.cancel();
    }
  }

  // ── Orientation toggle ─────────────────────────────────────────────────────

  void _toggleOrientation() {
    _isLandscape = !_isLandscape;
    SystemChrome.setPreferredOrientations(
      _isLandscape
          ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
          : [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown],
    );
    setState(() {});
    _scheduleHide();
  }

  // ── Server loading ─────────────────────────────────────────────────────────

  Future<void> _loadServer(VideoServer server) async {
    final isFirstLoad = _currentServer == null;

    // Clean up old controller BEFORE setState to avoid rendering disposed ctrl
    _betterCtrl?.removeEventsListener(_onPlayerEvent);
    _betterCtrl?.dispose();
    _betterCtrl = null;
    _webCtrl = null;

    setState(() {
      _loading = true;
      _error = null;
      _currentServer = server;
      _useWebView = !_isNativeUrl(server.url);
      _controlsVisible = true;
    });
    _scheduleHide();

    if (!isFirstLoad) {
      _showToast(
        server.nombre.isNotEmpty ? server.nombre : '${server.idioma} · ${server.calidad}',
      );
    }

    if (server.url.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Este servidor no tiene URL configurada';
      });
      return;
    }

    if (_useWebView) {
      _webCtrl = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (err) {
            if (mounted) {
              setState(() {
                _loading = false;
                _error = 'Error: ${err.description}';
              });
            }
          },
        ))
        ..loadRequest(Uri.parse(server.url));
      setState(() {});
    } else {
      try {
        final url = server.url;
        final isHls = url.toLowerCase().split('?').first.endsWith('.m3u8');
        final savedPos = context.read<HistoryProvider>().getPosition(widget.movie.id);

        final dataSource = BetterPlayerDataSource(
          BetterPlayerDataSourceType.network,
          url,
          headers: server.headers.isNotEmpty ? server.headers : null,
          videoFormat: isHls
              ? BetterPlayerVideoFormat.hls
              : BetterPlayerVideoFormat.other,
        );

        _betterCtrl = BetterPlayerController(
          BetterPlayerConfiguration(
            autoPlay: true,
            aspectRatio: 16 / 9,
            fit: BoxFit.contain,
            startAt: savedPos,
            looping: false,
            fullScreenByDefault: false,
            allowedScreenSleep: false,
            // Use custom theme so we render our own controls on top
            controlsConfiguration: BetterPlayerControlsConfiguration(
              playerTheme: BetterPlayerTheme.custom,
              customControlsBuilder: (ctrl, onVisibilityChanged) =>
                  const SizedBox.shrink(),
              showControlsOnInitialize: false,
            ),
          ),
          betterPlayerDataSource: dataSource,
        );

        _betterCtrl!.addEventsListener(_onPlayerEvent);
        _volumeValue = 1.0;
        setState(() => _loading = false);
      } catch (e) {
        setState(() {
          _loading = false;
          _error = 'Error al cargar:\n$e';
        });
      }
    }
  }

  void _onPlayerEvent(BetterPlayerEvent event) {
    if (!mounted) return;
    if (event.betterPlayerEventType == BetterPlayerEventType.progress) {
      final pos = _betterCtrl?.videoPlayerController?.value.position;
      if (pos != null && pos.inSeconds % 10 == 0 && pos.inSeconds > 0) {
        context.read<HistoryProvider>().addOrUpdate(widget.movie, pos);
      }
    }
    if (event.betterPlayerEventType == BetterPlayerEventType.exception) {
      setState(() => _error = 'Error al reproducir el video');
    }
  }

  // ── Toast ──────────────────────────────────────────────────────────────────

  void _showToast(String message) {
    _toastEntry?.remove();
    _toastEntry = null;

    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ToastWidget(
        message: message,
        onDismissed: () {
          entry.remove();
          if (_toastEntry == entry) _toastEntry = null;
        },
      ),
    );
    _toastEntry = entry;
    overlay.insert(entry);
  }

  // ── Gesture handlers: brightness (left) / volume (right) ──────────────────

  void _handleBrightnessDrag(DragUpdateDetails details) {
    final delta = -details.delta.dy / MediaQuery.of(context).size.height * 2;
    _brightnessValue = (_brightnessValue + delta).clamp(0.0, 1.0);
    try {
      ScreenBrightness().setScreenBrightness(_brightnessValue);
    } catch (_) {}
    _indicatorHideTimer?.cancel();
    setState(() => _showBrightnessIndicator = true);
    _indicatorHideTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showBrightnessIndicator = false;
          _showVolumeIndicator = false;
        });
      }
    });
  }

  void _handleVolumeDrag(DragUpdateDetails details) {
    final delta = -details.delta.dy / MediaQuery.of(context).size.height * 2;
    _volumeValue = (_volumeValue + delta).clamp(0.0, 1.0);
    _betterCtrl?.videoPlayerController?.setVolume(_volumeValue);
    _indicatorHideTimer?.cancel();
    setState(() => _showVolumeIndicator = true);
    _indicatorHideTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showBrightnessIndicator = false;
          _showVolumeIndicator = false;
        });
      }
    });
  }

  // ── Filter helpers ─────────────────────────────────────────────────────────

  List<String> get _idiomas =>
      ['Todos', ..._servers.map((s) => s.idioma).toSet()];

  List<String> get _calidades {
    final filtered = _selectedIdioma == 'Todos'
        ? _servers
        : _servers.where((s) => s.idioma == _selectedIdioma).toList();
    return ['Todos', ...filtered.map((s) => s.calidad).toSet()];
  }

  List<VideoServer> get _filteredServers => _servers.where((s) {
        final ok1 = _selectedIdioma == 'Todos' || s.idioma == _selectedIdioma;
        final ok2 = _selectedCalidad == 'Todos' || s.calidad == _selectedCalidad;
        return ok1 && ok2;
      }).toList();

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final showNativeControls = !_useWebView && _betterCtrl != null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _onTap,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            // ── Player / WebView / States ───────────────────────────────────
            Positioned.fill(child: _buildPlayerArea()),

            // ── Gesture zones for brightness/volume ─────────────────────────
            if (showNativeControls) ...[
              Positioned(
                left: 0,
                top: 60,
                bottom: 80,
                width: size.width * 0.35,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onVerticalDragUpdate: _handleBrightnessDrag,
                  child: const SizedBox.expand(),
                ),
              ),
              Positioned(
                right: 0,
                top: 60,
                bottom: 80,
                width: size.width * 0.35,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onVerticalDragUpdate: _handleVolumeDrag,
                  child: const SizedBox.expand(),
                ),
              ),
            ],

            // ── Custom controls overlay (fade + slide) ──────────────────────
            if (showNativeControls)
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !_controlsVisible,
                  child: AnimatedOpacity(
                    opacity: _controlsVisible ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: AnimatedSlide(
                      offset: _controlsVisible
                          ? Offset.zero
                          : const Offset(0, 0.04),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      child: _CustomPlayerControls(controller: _betterCtrl!),
                    ),
                  ),
                ),
              ),

            // ── Top bar ─────────────────────────────────────────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                ignoring: !_controlsVisible && !_useWebView,
                child: AnimatedOpacity(
                  opacity: _controlsVisible || _useWebView ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: _buildTopBar(),
                ),
              ),
            ),

            // ── Brightness indicator ────────────────────────────────────────
            if (_showBrightnessIndicator)
              Positioned(
                left: 20,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _SideIndicator(
                    value: _brightnessValue,
                    icon: _brightnessValue > 0.5
                        ? Icons.brightness_high_rounded
                        : Icons.brightness_4_rounded,
                    color: Colors.amber,
                  ),
                ),
              ),

            // ── Volume indicator ────────────────────────────────────────────
            if (_showVolumeIndicator)
              Positioned(
                right: 20,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _SideIndicator(
                    value: _volumeValue,
                    icon: _volumeValue > 0.5
                        ? Icons.volume_up_rounded
                        : _volumeValue > 0
                            ? Icons.volume_down_rounded
                            : Icons.volume_off_rounded,
                    color: Colors.white,
                  ),
                ),
              ),

            // ── Server panel (slide from bottom) ────────────────────────────
            if (_servers.isNotEmpty)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: AnimatedSlide(
                  offset: _panelVisible ? Offset.zero : const Offset(0, 1),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: AnimatedOpacity(
                    opacity: _panelVisible ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: _ServerPanel(
                      servers: _servers,
                      filteredServers: _filteredServers,
                      currentServer: _currentServer,
                      idiomas: _idiomas,
                      calidades: _calidades,
                      selectedIdioma: _selectedIdioma,
                      selectedCalidad: _selectedCalidad,
                      onIdiomaChanged: (v) => setState(() {
                        _selectedIdioma = v;
                        _selectedCalidad = 'Todos';
                      }),
                      onCalidadChanged: (v) =>
                          setState(() => _selectedCalidad = v),
                      onServerTap: (s) {
                        setState(() => _panelVisible = false);
                        _loadServer(s);
                      },
                      onClose: () => setState(() => _panelVisible = false),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Top bar ────────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    final server = _currentServer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // Back button
            _IconBtn(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => Navigator.pop(context),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.movie.titulo,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (server != null)
                    Text(
                      '${server.nombre.isNotEmpty ? server.nombre : "Servidor"}'
                      ' · ${server.idioma} · ${server.calidad}',
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            // Rotate button
            _IconBtn(
              icon: _isLandscape
                  ? Icons.stay_current_portrait_rounded
                  : Icons.stay_current_landscape_rounded,
              color: _isLandscape ? _purpleLight : Colors.white70,
              onTap: _toggleOrientation,
              tooltip: _isLandscape ? 'Portrait' : 'Landscape',
            ),
            // Servers floating button
            if (_servers.isNotEmpty)
              _IconBtn(
                icon: _panelVisible ? Icons.dns : Icons.dns_outlined,
                color: _panelVisible ? _purpleLight : Colors.white70,
                label: '${_servers.length}',
                onTap: () {
                  setState(() => _panelVisible = !_panelVisible);
                  if (_panelVisible) {
                    _hideTimer?.cancel();
                    setState(() => _controlsVisible = true);
                  } else {
                    _scheduleHide();
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  // ── Player area ────────────────────────────────────────────────────────────

  Widget _buildPlayerArea() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _purple),
            SizedBox(height: 16),
            Text('Cargando...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: _purpleLight, size: 56),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            if (_currentServer != null)
              ElevatedButton.icon(
                onPressed: () => _loadServer(_currentServer!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _purple,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
          ],
        ),
      );
    }

    if (_useWebView && _webCtrl != null) {
      return WebViewWidget(controller: _webCtrl!);
    }

    if (_betterCtrl != null) {
      return BetterPlayer(controller: _betterCtrl!);
    }

    if (_servers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_off_rounded, color: Colors.grey, size: 72),
            SizedBox(height: 16),
            Text('No hay servidores disponibles',
                style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }

    return const Center(
      child: Text('Selecciona un servidor',
          style: TextStyle(color: Colors.grey)),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Custom Player Controls
// ══════════════════════════════════════════════════════════════════════════════

class _CustomPlayerControls extends StatefulWidget {
  final BetterPlayerController controller;
  const _CustomPlayerControls({required this.controller});

  @override
  State<_CustomPlayerControls> createState() => _CustomPlayerControlsState();
}

class _CustomPlayerControlsState extends State<_CustomPlayerControls> {
  @override
  void initState() {
    super.initState();
    widget.controller.addEventsListener(_onEvent);
  }

  @override
  void didUpdateWidget(_CustomPlayerControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      try {
        oldWidget.controller.removeEventsListener(_onEvent);
      } catch (_) {}
      widget.controller.addEventsListener(_onEvent);
      setState(() {});
    }
  }

  @override
  void dispose() {
    try {
      widget.controller.removeEventsListener(_onEvent);
    } catch (_) {}
    super.dispose();
  }

  void _onEvent(BetterPlayerEvent event) {
    if (mounted &&
        event.betterPlayerEventType == BetterPlayerEventType.initialized) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final vpc = widget.controller.videoPlayerController;
    if (vpc == null) return const SizedBox.shrink();

    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: vpc,
      builder: (context, value, _) {
        final isPlaying = value.isPlaying;
        final position = value.position;
        final duration = value.duration ?? Duration.zero;
        final buffered = value.buffered.isNotEmpty
            ? value.buffered.last.end
            : Duration.zero;

        return Stack(
          children: [
            // Bottom gradient + progress bar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xE0000000), Colors.transparent],
                    stops: [0, 0.75],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(16, 36, 16, 14),
                child: _ProgressBar(
                  controller: widget.controller,
                  position: position,
                  duration: duration,
                  buffered: buffered,
                ),
              ),
            ),

            // Center controls: skip back | play/pause | skip forward
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CtrlButton(
                    icon: Icons.replay_10_rounded,
                    size: 34,
                    onTap: () {
                      final np = position - const Duration(seconds: 10);
                      widget.controller.seekTo(
                          np < Duration.zero ? Duration.zero : np);
                    },
                  ),
                  const SizedBox(width: 28),
                  _CtrlButton(
                    icon: isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 54,
                    onTap: () {
                      if (isPlaying) {
                        widget.controller.pause();
                      } else {
                        widget.controller.play();
                      }
                    },
                  ),
                  const SizedBox(width: 28),
                  _CtrlButton(
                    icon: Icons.forward_10_rounded,
                    size: 34,
                    onTap: () {
                      final np = position + const Duration(seconds: 10);
                      widget.controller
                          .seekTo(np > duration ? duration : np);
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Progress Bar
// ══════════════════════════════════════════════════════════════════════════════

class _ProgressBar extends StatefulWidget {
  final BetterPlayerController controller;
  final Duration position;
  final Duration duration;
  final Duration buffered;

  const _ProgressBar({
    required this.controller,
    required this.position,
    required this.duration,
    required this.buffered,
  });

  @override
  State<_ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<_ProgressBar> {
  double? _dragValue;
  bool _isDragging = false;

  double get _progress {
    if (widget.duration.inMilliseconds == 0) return 0;
    if (_isDragging && _dragValue != null) return _dragValue!;
    return (widget.position.inMilliseconds / widget.duration.inMilliseconds)
        .clamp(0.0, 1.0);
  }

  double get _bufferedPct {
    if (widget.duration.inMilliseconds == 0) return 0;
    return (widget.buffered.inMilliseconds / widget.duration.inMilliseconds)
        .clamp(0.0, 1.0);
  }

  Duration get _displayPos {
    if (_isDragging && _dragValue != null) {
      return Duration(
          milliseconds:
              (_dragValue! * widget.duration.inMilliseconds).round());
    }
    return widget.position;
  }

  void _seekTo(double pct) {
    widget.controller.seekTo(Duration(
        milliseconds: (pct * widget.duration.inMilliseconds).round()));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Time display
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _TimeChip(_displayPos),
            _TimeChip(widget.duration),
          ],
        ),
        const SizedBox(height: 8),

        // Bar with 28px tap area
        LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final thumbPct = _progress.clamp(0.0, 1.0);
            final thumbOffset = (thumbPct * w - 8).clamp(0.0, w - 16);

            return GestureDetector(
              onTapDown: (d) {
                _seekTo((d.localPosition.dx / w).clamp(0.0, 1.0));
              },
              onHorizontalDragStart: (d) {
                setState(() {
                  _isDragging = true;
                  _dragValue =
                      (d.localPosition.dx / w).clamp(0.0, 1.0);
                });
              },
              onHorizontalDragUpdate: (d) {
                setState(() {
                  _dragValue =
                      (d.localPosition.dx / w).clamp(0.0, 1.0);
                });
              },
              onHorizontalDragEnd: (_) {
                if (_dragValue != null) _seekTo(_dragValue!);
                setState(() {
                  _isDragging = false;
                  _dragValue = null;
                });
              },
              child: SizedBox(
                height: 28,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.centerLeft,
                  children: [
                    // Track background
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 11,
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    // Buffered
                    Positioned(
                      left: 0,
                      top: 11,
                      child: Container(
                        width: _bufferedPct * w,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _purple.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    // Played — purple→blue gradient
                    Positioned(
                      left: 0,
                      top: 11,
                      child: Container(
                        width: thumbPct * w,
                        height: 6,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [_purple, _blue]),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    // Thumb circle
                    Positioned(
                      left: thumbOffset,
                      top: 4,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 100),
                        width: _isDragging ? 20 : 16,
                        height: _isDragging ? 20 : 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: _purple.withOpacity(0.65),
                              blurRadius: 10,
                              spreadRadius: 1,
                            )
                          ],
                        ),
                      ),
                    ),
                    // Time preview while dragging
                    if (_isDragging && _dragValue != null)
                      Positioned(
                        left:
                            (_dragValue! * w - 28).clamp(0.0, w - 58),
                        bottom: 22,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xE0000000),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: _purple.withOpacity(0.6)),
                          ),
                          child: Text(
                            _fmt(_displayPos),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _TimeChip extends StatelessWidget {
  final Duration duration;
  const _TimeChip(this.duration);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _fmt(duration),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Reusable small widgets
// ══════════════════════════════════════════════════════════════════════════════

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String? label;
  final String? tooltip;
  final VoidCallback onTap;

  const _IconBtn({
    required this.icon,
    required this.onTap,
    this.color = Colors.white,
    this.label,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final child = Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              if (label != null) ...[
                const SizedBox(width: 4),
                Text(label!,
                    style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
            ],
          ),
        ),
      ),
    );
    if (tooltip != null) return Tooltip(message: tooltip!, child: child);
    return child;
  }
}

class _CtrlButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;

  const _CtrlButton(
      {required this.icon, required this.size, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size + 20,
        height: size + 20,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0x55000000),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: Colors.white, size: size),
      ),
    );
  }
}

class _SideIndicator extends StatelessWidget {
  final double value;
  final IconData icon;
  final Color color;
  const _SideIndicator(
      {required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 11),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.65),
        borderRadius: BorderRadius.circular(23),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          // Vertical bar track
          Container(
            width: 4,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: value.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(value * 100).round()}%',
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Toast
// ══════════════════════════════════════════════════════════════════════════════

class _ToastWidget extends StatefulWidget {
  final String message;
  final VoidCallback onDismissed;
  const _ToastWidget({required this.message, required this.onDismissed});

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        duration: const Duration(milliseconds: 300), vsync: this);
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _slide = Tween<Offset>(
            begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));
    _anim.forward();

    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        _anim.reverse().then((_) {
          if (mounted) widget.onDismissed();
        });
      }
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: const Alignment(0, 0.65),
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [_purple, _blue],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                      color: _purple.withOpacity(0.45),
                      blurRadius: 20,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.dns_rounded,
                      color: Colors.white, size: 15),
                  const SizedBox(width: 8),
                  Text(
                    widget.message,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Server Panel
// ══════════════════════════════════════════════════════════════════════════════

class _ServerPanel extends StatelessWidget {
  final List<VideoServer> servers;
  final List<VideoServer> filteredServers;
  final VideoServer? currentServer;
  final List<String> idiomas;
  final List<String> calidades;
  final String selectedIdioma;
  final String selectedCalidad;
  final void Function(String) onIdiomaChanged;
  final void Function(String) onCalidadChanged;
  final void Function(VideoServer) onServerTap;
  final VoidCallback onClose;

  const _ServerPanel({
    required this.servers,
    required this.filteredServers,
    required this.currentServer,
    required this.idiomas,
    required this.calidades,
    required this.selectedIdioma,
    required this.selectedCalidad,
    required this.onIdiomaChanged,
    required this.onCalidadChanged,
    required this.onServerTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 230,
      decoration: BoxDecoration(
        color: const Color(0xF0080810),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: const Border(top: BorderSide(color: Color(0xFF2a2a3a))),
        boxShadow: [
          BoxShadow(
              color: _purple.withOpacity(0.15),
              blurRadius: 20,
              spreadRadius: 2)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
            child: Row(
              children: [
                ShaderMask(
                  shaderCallback: (b) => const LinearGradient(
                          colors: [_purple, _blue])
                      .createShader(b),
                  child: const Text(
                    'Servidores',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                ),
                const SizedBox(width: 12),
                _FilterDrop(
                    value: selectedIdioma,
                    items: idiomas,
                    onChanged: onIdiomaChanged),
                const SizedBox(width: 8),
                _FilterDrop(
                    value: selectedCalidad,
                    items: calidades,
                    onChanged: onCalidadChanged),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white54, size: 18),
                  onPressed: onClose,
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF1e1e2e), height: 1),
          // Server chips
          Expanded(
            child: filteredServers.isEmpty
                ? const Center(
                    child: Text('Sin servidores',
                        style:
                            TextStyle(color: Colors.grey, fontSize: 12)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    scrollDirection: Axis.horizontal,
                    itemCount: filteredServers.length,
                    itemBuilder: (_, i) {
                      final s = filteredServers[i];
                      final isActive = currentServer?.url == s.url;
                      return _ServerChip(
                        server: s,
                        isActive: isActive,
                        onTap: () => onServerTap(s),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ServerChip extends StatelessWidget {
  final VideoServer server;
  final bool isActive;
  final VoidCallback onTap;
  const _ServerChip(
      {required this.server,
      required this.isActive,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 10, top: 2, bottom: 2),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: isActive
              ? const LinearGradient(colors: [_purple, _blue])
              : null,
          color: isActive ? null : const Color(0xFF111122),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isActive
                  ? Colors.transparent
                  : const Color(0xFF2a2a3e)),
          boxShadow: isActive
              ? [
                  BoxShadow(
                      color: _purple.withOpacity(0.5),
                      blurRadius: 12,
                      offset: const Offset(0, 3))
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isActive
                      ? Icons.check_circle_rounded
                      : Icons.play_circle_outline_rounded,
                  size: 13,
                  color: isActive ? Colors.white : Colors.grey,
                ),
                const SizedBox(width: 6),
                Text(
                  server.nombre.isNotEmpty
                      ? server.nombre
                      : 'Servidor ${server.idioma}',
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.grey,
                    fontWeight: isActive
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${server.idioma} · ${server.calidad}',
              style: TextStyle(
                color: isActive
                    ? Colors.white70
                    : Colors.grey.shade700,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterDrop extends StatelessWidget {
  final String value;
  final List<String> items;
  final void Function(String) onChanged;
  const _FilterDrop(
      {required this.value,
      required this.items,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      value: value,
      dropdownColor: const Color(0xFF1a1a2e),
      style: const TextStyle(color: Colors.white, fontSize: 12),
      underline: const SizedBox.shrink(),
      isDense: true,
      icon: const Icon(Icons.keyboard_arrow_down_rounded,
          color: Colors.grey, size: 14),
      items: items
          .map((i) => DropdownMenuItem(
              value: i,
              child: Text(i,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 12))))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}
