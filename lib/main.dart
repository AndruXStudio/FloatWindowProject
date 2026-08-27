import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'widgets/morph_switch.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const FloatWindowApp());
}

/// 系统悬浮窗入口（必须与插件约定的名字一致）
@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: OverlayPanel(),
    ),
  );
}

class FloatWindowApp extends StatefulWidget {
  const FloatWindowApp({super.key});

  @override
  State<FloatWindowApp> createState() => _FloatWindowAppState();
}

class _FloatWindowAppState extends State<FloatWindowApp> {
  final _scaffoldKey = GlobalKey<ScaffoldMessengerState>();
  ThemeMode _themeMode = ThemeMode.system;
  bool _haptics = true;
  bool _overlayRunning = false;
  bool _busy = false;
  String _status = '未启动';

  @override
  void initState() {
    super.initState();
    _load();
    _refreshOverlayState();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final t = p.getString('theme') ?? 'system';
    setState(() {
      _themeMode = switch (t) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      _haptics = p.getBool('haptics') ?? true;
    });
  }

  void _toast(String msg) {
    _scaffoldKey.currentState?.showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _refreshOverlayState() async {
    try {
      final active = await FlutterOverlayWindow.isActive();
      if (mounted) {
        setState(() {
          _overlayRunning = active;
          _status = active ? '运行中' : '未启动';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _status = '状态读取失败');
    }
  }

  Future<void> _setTheme(ThemeMode m) async {
    setState(() => _themeMode = m);
    final p = await SharedPreferences.getInstance();
    await p.setString(
      'theme',
      m == ThemeMode.light
          ? 'light'
          : m == ThemeMode.dark
              ? 'dark'
              : 'system',
    );
  }

  Future<bool> _ensurePermission() async {
    try {
      if (await FlutterOverlayWindow.isPermissionGranted()) return true;
    } catch (_) {}

    // requestPermission 在部分机型上可能不返回，设置超时
    try {
      await FlutterOverlayWindow.requestPermission().timeout(
        const Duration(seconds: 2),
        onTimeout: () => false,
      );
    } catch (_) {}

    try {
      if (await FlutterOverlayWindow.isPermissionGranted()) return true;
    } catch (_) {}

    // 仍无权限则打开系统设置页
    await openAppSettings();
    await Future.delayed(const Duration(milliseconds: 600));
    try {
      return await FlutterOverlayWindow.isPermissionGranted();
    } catch (_) {
      return false;
    }
  }

  Future<void> _startOverlay() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = '正在启动…';
    });
    if (_haptics) HapticFeedback.mediumImpact();

    try {
      final ok = await _ensurePermission();
      if (!ok) {
        _toast('请开启「显示在其他应用上层」权限后重试');
        setState(() => _status = '缺少权限');
        return;
      }

      if (await FlutterOverlayWindow.isActive()) {
        await FlutterOverlayWindow.closeOverlay();
        await Future.delayed(const Duration(milliseconds: 300));
      }

      await FlutterOverlayWindow.showOverlay(
        height: 520,
        width: 340,
        alignment: OverlayAlignment.center,
        flag: OverlayFlag.defaultFlag,
        enableDrag: true,
        positionGravity: PositionGravity.none,
        overlayTitle: '悬浮窗项目',
        overlayContent: 'Material 悬浮窗运行中',
      );

      await Future.delayed(const Duration(milliseconds: 500));
      final active = await FlutterOverlayWindow.isActive();
      setState(() {
        _overlayRunning = active;
        _status = active ? '运行中' : '已调用显示（若未见请检查权限/通知）';
      });

      if (!active) {
        _toast('未能确认悬浮窗。请确认权限已开，并允许通知/前台服务。');
      } else {
        _toast('悬浮窗已启动，可切换到其他应用查看');
      }
    } catch (e, st) {
      debugPrint('start overlay error: $e\n$st');
      setState(() => _status = '错误');
      _toast('启动失败: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stopOverlay() async {
    if (_haptics) HapticFeedback.lightImpact();
    try {
      await FlutterOverlayWindow.closeOverlay();
    } catch (e) {
      _toast('关闭异常: $e');
    }
    await _refreshOverlayState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '悬浮窗项目',
      scaffoldMessengerKey: _scaffoldKey,
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD0BCFF),
          brightness: Brightness.dark,
        ),
      ),
      home: Builder(
        builder: (context) {
          final cs = Theme.of(context).colorScheme;
          return Scaffold(
            appBar: AppBar(
              title: const Text('悬浮窗项目'),
              centerTitle: true,
            ),
            body: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  elevation: 0,
                  color: cs.primaryContainer.withValues(alpha: 0.5),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(Icons.layers_rounded, size: 56, color: cs.primary),
                        const SizedBox(height: 12),
                        Text(
                          '系统级外部悬浮窗',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '可叠在其他应用上方 · Material 3',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: (_busy || _overlayRunning) ? null : _startOverlay,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.open_in_new_rounded),
                  label: Text(_busy ? '启动中…' : '启动悬浮窗'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _overlayRunning ? _stopOverlay : null,
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('关闭悬浮窗'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    '状态：$_status',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: _overlayRunning ? cs.primary : cs.outline,
                        ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _refreshOverlayState,
                  child: const Text('刷新状态'),
                ),
                const SizedBox(height: 20),
                Text('外观', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('系统'),
                      icon: Icon(Icons.brightness_auto),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text('浅色'),
                      icon: Icon(Icons.light_mode),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text('深色'),
                      icon: Icon(Icons.dark_mode),
                    ),
                  ],
                  selected: {_themeMode},
                  onSelectionChanged: (s) => _setTheme(s.first),
                ),
                const SizedBox(height: 20),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.vibration),
                  title: const Text('触感反馈'),
                  trailing: MorphSwitch(
                    value: _haptics,
                    onChanged: (v) async {
                      setState(() => _haptics = v);
                      final p = await SharedPreferences.getInstance();
                      await p.setBool('haptics', v);
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '若点击无反应：请到系统设置 → 应用 → 悬浮窗项目 → 允许「显示在其他应用上层」，并允许通知。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class OverlayPanel extends StatefulWidget {
  const OverlayPanel({super.key});

  @override
  State<OverlayPanel> createState() => _OverlayPanelState();
}

class _OverlayPanelState extends State<OverlayPanel>
    with TickerProviderStateMixin {
  late final AnimationController _launch = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
  )..forward();
  late final AnimationController _expand = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
    value: 1,
  );

  int _page = 0;
  bool _optA = true;
  bool _optB = false;
  bool _optC = true;
  double _w = 320;
  double _h = 460;
  static const _minW = 260.0;
  static const _minH = 280.0;

  @override
  void dispose() {
    _launch.dispose();
    _expand.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    HapticFeedback.lightImpact();
    if (_expand.value > 0.5) {
      _expand.reverse();
    } else {
      _expand.forward();
    }
  }

  Future<void> _close() async {
    HapticFeedback.lightImpact();
    await _launch.reverse();
    await FlutterOverlayWindow.closeOverlay();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFD0BCFF),
        brightness: Brightness.dark,
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: AnimatedBuilder(
          animation: Listenable.merge([_launch, _expand]),
          builder: (context, _) {
            final scale = Curves.easeOutBack.transform(_launch.value);
            final fade = Curves.easeOut.transform(_launch.value.clamp(0.0, 1.0));
            final expandT = Curves.easeOutCubic.transform(_expand.value);

            return Opacity(
              opacity: fade,
              child: Transform.scale(
                scale: 0.88 + scale * 0.12,
                child: Align(
                  child: Material(
                    elevation: 10,
                    borderRadius: BorderRadius.circular(20),
                    color: theme.colorScheme.surfaceContainerHigh,
                    clipBehavior: Clip.antiAlias,
                    child: SizedBox(
                      width: _w.clamp(_minW, 420),
                      height: (_minH + (_h - _minH) * expandT)
                          .clamp(_minH * 0.35, 640),
                      child: Column(
                        children: [
                          Container(
                            height: 48,
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: Row(
                              children: [
                                IconButton(
                                  icon: AnimatedRotation(
                                    turns: expandT > 0.5 ? 0 : 0.5,
                                    duration: const Duration(milliseconds: 250),
                                    child: const Icon(Icons.expand_more_rounded),
                                  ),
                                  onPressed: _toggleExpand,
                                ),
                                Expanded(
                                  child: Text(
                                    '悬浮窗项目',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close_rounded),
                                  onPressed: _close,
                                ),
                              ],
                            ),
                          ),
                          if (expandT > 0.05)
                            Expanded(
                              child: Opacity(
                                opacity: expandT.clamp(0.0, 1.0),
                                child: Row(
                                  children: [
                                    NavigationRail(
                                      selectedIndex: _page,
                                      onDestinationSelected: (i) {
                                        HapticFeedback.selectionClick();
                                        setState(() => _page = i);
                                      },
                                      labelType:
                                          NavigationRailLabelType.selected,
                                      destinations: const [
                                        NavigationRailDestination(
                                          icon: Icon(Icons.home_outlined),
                                          selectedIcon: Icon(Icons.home_rounded),
                                          label: Text('主页'),
                                        ),
                                        NavigationRailDestination(
                                          icon: Icon(Icons.tune_outlined),
                                          selectedIcon: Icon(Icons.tune),
                                          label: Text('选项'),
                                        ),
                                        NavigationRailDestination(
                                          icon: Icon(Icons.info_outline),
                                          selectedIcon: Icon(Icons.info_rounded),
                                          label: Text('关于'),
                                        ),
                                      ],
                                    ),
                                    VerticalDivider(
                                      width: 1,
                                      color: theme.colorScheme.outlineVariant,
                                    ),
                                    Expanded(
                                      child: AnimatedSwitcher(
                                        duration:
                                            const Duration(milliseconds: 260),
                                        child: KeyedSubtree(
                                          key: ValueKey(_page),
                                          child: _body(theme),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (expandT > 0.5)
                            GestureDetector(
                              onHorizontalDragUpdate: (d) {
                                setState(() {
                                  _w = (_w + d.delta.dx).clamp(_minW, 420);
                                });
                              },
                              onVerticalDragUpdate: (d) {
                                setState(() {
                                  _h = (_h + d.delta.dy).clamp(_minH, 640);
                                });
                              },
                              child: Container(
                                height: 28,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 10),
                                child: Icon(
                                  Icons.drag_handle,
                                  size: 20,
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _body(ThemeData theme) {
    switch (_page) {
      case 0:
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Text('快速操作', style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in [
                  (Icons.public, '网页'),
                  (Icons.notes_rounded, '笔记'),
                  (Icons.timer_outlined, '计时'),
                  (Icons.calculate_outlined, '计算'),
                ])
                  ActionChip(
                    avatar: Icon(e.$1, size: 18),
                    label: Text(e.$2),
                    onPressed: () => HapticFeedback.selectionClick(),
                  ),
              ],
            ),
          ],
        );
      case 1:
        return ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('通知'),
              trailing: MorphSwitch(
                value: _optA,
                onChanged: (v) => setState(() => _optA = v),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dark_mode_outlined),
              title: const Text('深色面板'),
              trailing: MorphSwitch(
                value: _optB,
                onChanged: (v) => setState(() => _optB = v),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.push_pin_outlined),
              title: const Text('保持前置'),
              trailing: MorphSwitch(
                value: _optC,
                onChanged: (v) => setState(() => _optC = v),
              ),
            ),
          ],
        );
      default:
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Icon(Icons.layers_rounded,
                size: 40, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            Text('悬浮窗项目', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('系统叠加层 · Material 3', style: theme.textTheme.bodySmall),
          ],
        );
    }
  }
}
