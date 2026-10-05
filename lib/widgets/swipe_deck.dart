import 'dart:ui' show ImageFilter, TileMode;
import 'package:flutter/material.dart';

enum SwipeDirection { left, right, up }

/// Controla un [SwipeDeck] desde afuera (p. ej. los botones de acción).
class SwipeDeckController extends ChangeNotifier {
  _SwipeDeckState? _state;

  void _attach(_SwipeDeckState state) => _state = state;

  void _detach(_SwipeDeckState state) {
    if (identical(_state, state)) _state = null;
  }

  bool get isAttached => _state != null;

  void swipeLeft() => _state?.programmaticSwipe(SwipeDirection.left);
  void swipeRight() => _state?.programmaticSwipe(SwipeDirection.right);

  /// Anima la tarjeta que vuelve (deshacer) entrando desde el lado indicado.
  void playEnter(SwipeDirection direction) => _state?.enterFrom(direction);
}

/// Pila de tarjetas con arrastre estilo Tinder: la de arriba se mueve y rota
/// siguiendo el dedo, las de atrás se ven apiladas y escaladas.
class SwipeDeck<T> extends StatefulWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item, bool isTop, double progress) itemBuilder;
  final void Function(T item, SwipeDirection direction) onSwipe;
  final SwipeDeckController? controller;
  final int visibleCards;
  final double swipeThreshold;
  final double rotationFactor;
  final Duration animationDuration;
  final Duration stackAnimationDuration;
  final Curve stackAnimationCurve;
  final Curve stackScaleCurve;
  final double backBlurSigma;
  final double backScrimOpacity;

  const SwipeDeck({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.onSwipe,
    this.controller,
    this.visibleCards = 3,
    this.swipeThreshold = 0.28,
    this.rotationFactor = 0.35,
    this.animationDuration = const Duration(milliseconds: 260),
    this.stackAnimationDuration = const Duration(milliseconds: 320),
    this.stackAnimationCurve = Curves.easeOutCubic,
    this.stackScaleCurve = Curves.easeOutBack,
    this.backBlurSigma = 6.0,
    this.backScrimOpacity = 0.35,
  });

  @override
  State<SwipeDeck<T>> createState() => _SwipeDeckState<T>();
}

class _SwipeDeckState<T> extends State<SwipeDeck<T>> with SingleTickerProviderStateMixin {
  Offset _drag = Offset.zero;
  Size _cardSize = Size.zero;
  bool _flyingOut = false;
  SwipeDirection? _pendingEnterDirection;
  T? _lastTop;

  late final AnimationController _animationController;
  Animation<Offset>? _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: widget.animationDuration)
      ..addListener(() {
        final anim = _offsetAnimation;
        if (anim != null) {
          setState(() => _drag = anim.value);
        }
      });
    _lastTop = widget.items.isNotEmpty ? widget.items.first : null;
    widget.controller?._attach(this);
  }

  @override
  void didUpdateWidget(covariant SwipeDeck<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }

    // Ojo: `items` suele ser la misma lista mutable, así que comparamos por
    // identidad del objeto de arriba (no por la referencia de la lista).
    final T? newTop = widget.items.isEmpty ? null : widget.items.first;
    if (!identical(_lastTop, newTop)) {
      _lastTop = newTop;
      final SwipeDirection? enter = _pendingEnterDirection;
      _pendingEnterDirection = null;
      _offsetAnimation = null;
      _flyingOut = false;
      _animationController.stop();
      _animationController.value = 0;

      if (enter != null) {
        // Deshacer: la tarjeta entra deslizándose (y rotando) desde el lado.
        final double width = _cardSize.width == 0 ? 400.0 : _cardSize.width;
        final double startX = enter == SwipeDirection.right ? width * 1.2 : -width * 1.2;
        _drag = Offset(startX, 0);
        _offsetAnimation = Tween<Offset>(begin: _drag, end: Offset.zero)
            .animate(CurvedAnimation(parent: _animationController, curve: widget.stackAnimationCurve));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _animationController.forward(from: 0);
        });
      } else {
        _drag = Offset.zero;
      }
    }
  }

  /// Prepara la animación de entrada para la próxima tarjeta que aparezca.
  void enterFrom(SwipeDirection direction) {
    if (widget.items.isEmpty) return;
    setState(() => _pendingEnterDirection = direction);
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _animationController.dispose();
    super.dispose();
  }

  bool get _isAnimating => _animationController.isAnimating;

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (_isAnimating || _flyingOut || widget.items.isEmpty) return;
    // Solo se mueve en el eje horizontal (rumbo predefinido); no arrastre libre.
    setState(() => _drag = Offset(_drag.dx + details.delta.dx, 0));
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_isAnimating || _flyingOut || widget.items.isEmpty) return;
    final double velocityX = details.velocity.pixelsPerSecond.dx;
    final double threshold = _cardSize.width * widget.swipeThreshold;
    final bool wantRight = _drag.dx > threshold || velocityX > 900;
    final bool wantLeft = _drag.dx < -threshold || velocityX < -900;
    if (wantRight) {
      _flyOut(SwipeDirection.right);
    } else if (wantLeft) {
      _flyOut(SwipeDirection.left);
    } else {
      _snapBack();
    }
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (_isAnimating || _flyingOut || widget.items.isEmpty) return;
    // Solo eje vertical (hacia arriba = mover a álbum).
    setState(() => _drag = Offset(0, _drag.dy + details.delta.dy));
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_isAnimating || _flyingOut || widget.items.isEmpty) return;
    final double velocityY = details.velocity.pixelsPerSecond.dy;
    final double threshold = _cardSize.height * widget.swipeThreshold;
    if (_drag.dy < -threshold || velocityY < -900) {
      _flyOut(SwipeDirection.up);
    } else {
      _snapBack();
    }
  }

  void _snapBack() {
    _offsetAnimation = Tween<Offset>(begin: _drag, end: Offset.zero)
        .animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));
    _animationController.forward(from: 0);
  }

  void _flyOut(SwipeDirection direction) {
    if (_flyingOut) return;
    _flyingOut = true;
    final double width = _cardSize.width == 0 ? 400.0 : _cardSize.width;
    final double height = _cardSize.height == 0 ? 600.0 : _cardSize.height;
    late final Offset end;
    if (direction == SwipeDirection.right) {
      end = Offset(width * 1.8, _drag.dy);
    } else if (direction == SwipeDirection.left) {
      end = Offset(-width * 1.8, _drag.dy);
    } else {
      end = Offset(_drag.dx, -height * 1.8);
    }
    _offsetAnimation = Tween<Offset>(begin: _drag, end: end)
        .animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));
    _animationController.forward(from: 0).whenComplete(() {
      if (!mounted) return;
      final T? item = widget.items.isNotEmpty ? widget.items.first : null;
      // Importante: anular la animación ANTES de resetear el controller, si no
      // el listener vuelve a escribir el `_drag` viejo y la siguiente tarjeta
      // aparece rotada.
      _offsetAnimation = null;
      _animationController.value = 0;
      setState(() {
        _drag = Offset.zero;
        _flyingOut = false;
      });
      if (item != null) {
        widget.onSwipe(item, direction);
      }
    });
  }

  void programmaticSwipe(SwipeDirection direction) {
    if (widget.items.isEmpty || _isAnimating || _flyingOut) return;
    _flyOut(direction);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _cardSize = Size(constraints.maxWidth, constraints.maxHeight);
        final items = widget.items.take(widget.visibleCards).toList();
        if (items.isEmpty) return const SizedBox.shrink();

        final double progress =
            _cardSize.width == 0 ? 0.0 : (_drag.dx / _cardSize.width).clamp(-1.0, 1.0);
        final double cardHeight = _cardSize.height == 0 ? 1.0 : _cardSize.height;
        final List<Widget> children = [];

        for (int i = items.length - 1; i >= 0; i--) {
          final bool isTop = i == 0;
          final int depth = i;

          // Las de atrás se encogen (crecen "de la nada" al pasar al frente).
          final double stackScale = 1 - depth * 0.15;
          final Offset stackSlide = Offset(0, (depth * 16) / cardHeight);

          Widget card = widget.itemBuilder(context, items[i], isTop, isTop ? progress : 0.0);

          // Difuminado + velo oscuro animados (sin fade a transparente) para que
          // no se distinga la foto de atrás.
          card = TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: depth.toDouble()),
            duration: widget.stackAnimationDuration,
            curve: widget.stackAnimationCurve,
            builder: (context, d, child) {
              final double sigma = d * widget.backBlurSigma;
              final double scrim = (d * widget.backScrimOpacity).clamp(0.0, 0.85);
              Widget content = child!;
              if (sigma > 0.01) {
                content = ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.decal),
                  child: content,
                );
              }
              return Stack(
                fit: StackFit.expand,
                children: [
                  content,
                  if (scrim > 0.01)
                    IgnorePointer(child: Container(color: Colors.black.withValues(alpha: scrim))),
                ],
              );
            },
            child: card,
          );

          card = AnimatedScale(
            scale: stackScale,
            duration: widget.stackAnimationDuration,
            curve: widget.stackScaleCurve,
            child: AnimatedSlide(
              offset: stackSlide,
              duration: widget.stackAnimationDuration,
              curve: widget.stackAnimationCurve,
              child: card,
            ),
          );

          // El Transform se deja SIEMPRE (identidad para las de atrás) para no
          // romper el árbol de widgets; si no, la promoción salta en vez de animar.
          final Offset dragOffset = isTop ? _drag : Offset.zero;
          final double angle = isTop ? progress * widget.rotationFactor : 0.0;
          card = Transform.translate(
            offset: dragOffset,
            child: Transform.rotate(angle: angle, child: card),
          );

          children.add(Positioned.fill(
            key: ObjectKey(items[i]),
            child: IgnorePointer(ignoring: !isTop, child: card),
          ));
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: _onHorizontalDragUpdate,
          onHorizontalDragEnd: _onHorizontalDragEnd,
          onVerticalDragUpdate: _onVerticalDragUpdate,
          onVerticalDragEnd: _onVerticalDragEnd,
          child: Stack(clipBehavior: Clip.none, children: children),
        );
      },
    );
  }
}
