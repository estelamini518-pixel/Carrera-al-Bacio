import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
  );

  runApp(const CarreraApp());
}

// ============================================================
// APLICACIÓN PRINCIPAL
// ============================================================

class CarreraApp extends StatelessWidget {
  const CarreraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Carrera al Vacío',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF030611),
      ),
      home: const GameScreen(),
    );
  }
}

// ============================================================
// OBJETOS DEL JUEGO
// ============================================================

enum ObjectType {
  asteroid,
  energy,
}

class SpaceObject {
  SpaceObject(this.x, this.y, this.type, this.size);

  double x;
  double y;
  double size;

  ObjectType type;
}

// ============================================================
// PANTALLA DEL VIDEOJUEGO
// ============================================================

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final math.Random random = math.Random();

  Timer? timer;

  double shipY = 0.5;
  double shadow = 0.08;
  double rival = 0.72;
  double fuel = 1.0;

  int level = 1;
  int points = 0;
  int lives = 3;

  bool turbo = false;
  bool shield = false;
  bool paused = false;
  bool gameOver = false;
  bool victory = false;

  String message = 'IRIS: ¡Motores listos, Nova!';

  final List<SpaceObject> objects = <SpaceObject>[];

  final List<double> stars = List<double>.generate(
    100,
    (_) => math.Random().nextDouble(),
  );

  final List<String> names = [
    'Estación Base',
    'Campo de Asteroides',
    'Nebulosa Roja',
    'Nave Fantasma',
    'Zona Muda',
  ];

  bool get holeReady => shadow > 0.66;

  // ==========================================================
  // INICIALIZACIÓN
  // ==========================================================

  @override
  void initState() {
    super.initState();

    makeObjects();

    timer = Timer.periodic(
      const Duration(milliseconds: 45),
      (_) => tick(),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  // ==========================================================
  // CREAR ASTEROIDES Y ENERGÍA
  // ==========================================================

  void makeObjects() {
    objects
      ..clear()
      ..addAll(
        List<SpaceObject>.generate(
          9,
          (_) => SpaceObject(
            0.55 + random.nextDouble() * 0.7,
            0.12 + random.nextDouble() * 0.76,
            random.nextInt(10) < 6
                ? ObjectType.asteroid
                : ObjectType.energy,
            0.018 + random.nextDouble() * 0.025,
          ),
        ),
      );
  }

  // ==========================================================
  // ACTUALIZACIÓN DEL JUEGO
  // ==========================================================

  void tick() {
    if (!mounted || paused || gameOver || victory) {
      return;
    }

    setState(() {
      final double pace =
          (turbo ? 0.014 : 0.008) + level * 0.0012;

      fuel = (fuel - (turbo ? 0.003 : 0.0006))
          .clamp(0.0, 1.0)
          .toDouble();

      if (fuel == 0) {
        turbo = false;
      }

      for (final SpaceObject o in objects) {
        o.x -= pace *
            (o.type == ObjectType.asteroid ? 1.0 : 0.8);

        if (o.x < -0.05) {
          o.x = 1.05 + random.nextDouble() * 0.4;
          o.y = 0.12 + random.nextDouble() * 0.76;

          o.type = random.nextInt(10) < 6
              ? ObjectType.asteroid
              : ObjectType.energy;
        }

        final bool collisionX = (o.x - 0.18).abs() < 0.035;
        final bool collisionY =
            (o.y - shipY).abs() < o.size + 0.04;

        if (collisionX && collisionY) {
          if (o.type == ObjectType.energy) {
            fuel = (fuel + 0.28).clamp(0.0, 1.0).toDouble();

            points += 100;
            message = '¡Energía recogida! +100 puntos';
          } else if (!shield) {
            lives--;

            message = '¡Impacto de asteroide!';

            if (lives <= 0) {
              gameOver = true;
            }
          } else {
            points += 50;
            message = 'Escudo activado: +50 puntos';
          }

          o.x = 1.1 + random.nextDouble() * 0.3;
          o.y = 0.12 + random.nextDouble() * 0.76;
        }
      }

      // Nave rival
      rival -= pace * 0.6;

      if (rival < -0.1) {
        rival = 1.1;
      }

      // La Sombra persigue a Nova.
      shadow += (level >= 3 ? 0.0032 : 0.0021) +
          (fuel == 0 ? 0.001 : 0.0);

      if (shadow > 0.96) {
        lives--;
        shadow = 0.38;

        message = '¡La Sombra te alcanzó! Perdiste una vida.';

        if (lives <= 0) {
          gameOver = true;
        }
      }

      // Puntos extra durante la carrera.
      if (random.nextDouble() < 0.035) {
        points++;
      }
    });
  }

  // ==========================================================
  // CONTROLES DE MOVIMIENTO
  // ==========================================================

  void move(double dy) {
    if (paused || gameOver || victory) {
      return;
    }

    setState(() {
      shipY = (shipY + dy).clamp(0.12, 0.88).toDouble();
    });
  }

  // ==========================================================
  // TURBO
  // ==========================================================

  void useTurbo() {
    if (fuel < 0.08 || paused || gameOver || victory) {
      setState(() {
        message = 'IRIS: No hay combustible suficiente.';
      });

      return;
    }

    setState(() {
      turbo = true;
      points += 10;
      message = '¡TURBO! +10 puntos';
    });

    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() {
          turbo = false;
        });
      }
    });
  }

  // ==========================================================
  // ESCUDO DE ENERGÍA
  // ==========================================================

  void useShield() {
    if (paused || gameOver || victory) {
      return;
    }

    setState(() {
      shield = true;
      points += 25;
      message = 'Escudo de energía: +25 puntos';
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          shield = false;
        });
      }
    });
  }

  // ==========================================================
  // PULSO ELECTROMAGNÉTICO
  // ==========================================================

  void emp() {
    if (paused || gameOver || victory) {
      return;
    }

    setState(() {
      shadow = (shadow - 0.18).clamp(0.04, 0.92).toDouble();

      points += 30;

      message = 'Pulso EMP: La Sombra retrocede. +30';
    });
  }

  // ==========================================================
  // AGUJERO NEGRO Y CAMBIO DE NIVEL
  // ==========================================================

  void blackHole() {
    if (!holeReady || paused || gameOver || victory) {
      return;
    }

    setState(() {
      points += 500;

      if (level == 5) {
        victory = true;
        message = '¡Has escapado de la Zona Muda!';
      } else {
        level++;

        shadow = 0.12;
        rival = 0.7;

        fuel = (fuel + 0.45).clamp(0.0, 1.0).toDouble();

        shipY = 0.5;

        makeObjects();

        message =
            '¡Salto cuántico! +500. ${names[level - 1]}';
      }
    });
  }

  // ==========================================================
  // REINICIAR PARTIDA
  // ==========================================================

  void reset() {
    setState(() {
      shipY = 0.5;
      shadow = 0.08;
      rival = 0.72;
      fuel = 1.0;

      level = 1;
      points = 0;
      lives = 3;

      turbo = false;
      shield = false;
      paused = false;
      gameOver = false;
      victory = false;

      message = 'IRIS: ¡Motores listos, Nova!';

      makeObjects();
    });
  }

  // ==========================================================
  // INTERFAZ PRINCIPAL
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: SpacePainter(
                level,
                shipY,
                shadow,
                rival,
                objects,
                stars,
                turbo,
                shield,
                holeReady,
              ),
            ),
          ),

          // Panel de información
          Positioned(
            left: 12,
            top: 10,
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: const Color(0xDD081226),
                border: Border.all(
                  color: const Color(0xFF3A8EA9),
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: DefaultTextStyle(
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CARRERA AL VACÍO • NIVEL $level/5',
                      style: const TextStyle(
                        color: Color(0xFF62EAFF),
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    Text(names[level - 1]),

                    Text(
                      'PUNTOS: $points   VIDAS: ${'♥ ' * lives}',
                    ),

                    Row(
                      children: [
                        const Text('COMBUSTIBLE '),

                        SizedBox(
                          width: 85,
                          child: LinearProgressIndicator(
                            value: fuel,
                            minHeight: 7,
                            valueColor:
                                const AlwaysStoppedAnimation<Color>(
                              Color(0xFFFFB34F),
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(
                      width: 235,
                      child: Text(
                        message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFB5D5F4),
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Botón de pausa
          Positioned(
            top: 8,
            right: 12,
            child: IconButton.filledTonal(
              onPressed: () {
                setState(() {
                  if (!gameOver && !victory) {
                    paused = !paused;
                  }
                });
              },
              icon: Icon(
                paused ? Icons.play_arrow : Icons.pause,
              ),
            ),
          ),

          // Controles del jugador
          Positioned(
            left: 12,
            right: 12,
            bottom: 10,
            child: Row(
              children: [
                control('▲', () => move(-0.09)),
                const SizedBox(width: 6),

                control('▼', () => move(0.09)),

                const Spacer(),

                action(
                  'TURBO',
                  useTurbo,
                  const Color(0xFFFFA43B),
                ),

                const SizedBox(width: 6),

                action(
                  'ESCUDO',
                  useShield,
                  const Color(0xFF45D8FF),
                ),

                const SizedBox(width: 6),

                action(
                  'PULSO EMP',
                  emp,
                  const Color(0xFFB69BFF),
                ),

                if (holeReady) ...[
                  const SizedBox(width: 6),

                  action(
                    'AGUJERO NEGRO',
                    blackHole,
                    const Color(0xFFFF4FD8),
                    wide: true,
                  ),
                ],
              ],
            ),
          ),

          // Pantalla de pausa, derrota o victoria
          if (paused || gameOver || victory)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.8),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        victory
                            ? '¡CARRERA COMPLETADA!'
                            : gameOver
                                ? 'LA SOMBRA TE ALCANZÓ'
                                : 'PAUSA',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF61F2FF),
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        'Puntuación: $points • Nivel: $level/5',
                      ),

                      const SizedBox(height: 12),

                      ElevatedButton.icon(
                        onPressed: gameOver || victory
                            ? reset
                            : () {
                                setState(() {
                                  paused = false;
                                });
                              },
                        icon: Icon(
                          gameOver || victory
                              ? Icons.replay
                              : Icons.play_arrow,
                        ),
                        label: Text(
                          gameOver || victory
                              ? 'JUGAR OTRA VEZ'
                              : 'CONTINUAR',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ==========================================================
  // BOTONES REUTILIZABLES
  // ==========================================================

  Widget control(String t, VoidCallback cb) {
    return SizedBox(
      width: 44,
      height: 42,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: const Color(0xCC142B4C),
        ),
        onPressed: cb,
        child: Text(
          t,
          style: const TextStyle(fontSize: 20),
        ),
      ),
    );
  }

  Widget action(
    String t,
    VoidCallback cb,
    Color c, {
    bool wide = false,
  }) {
    return SizedBox(
      height: 42,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.withValues(alpha: 0.2),
          foregroundColor: c,
          side: BorderSide(color: c),
          padding: EdgeInsets.symmetric(
            horizontal: wide ? 14 : 11,
          ),
        ),
        onPressed: cb,
        child: Text(
          t,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// DIBUJO DEL ESPACIO Y LA NAVE
// ============================================================

class SpacePainter extends CustomPainter {
  SpacePainter(
    this.level,
    this.shipY,
    this.shadow,
    this.rival,
    this.objects,
    this.stars,
    this.turbo,
    this.shield,
    this.hole,
  );

  final int level;

  final double shipY;
  final double shadow;
  final double rival;

  final List<SpaceObject> objects;
  final List<double> stars;

  final bool turbo;
  final bool shield;
  final bool hole;

  final List<Color> colors = [
    const Color(0xFF4ADFFF),
    const Color(0xFFFFB34F),
    const Color(0xFFFF526D),
    const Color(0xFFB79BFF),
    const Color(0xFFEA5BFF),
  ];

  @override
  void paint(Canvas c, Size s) {
    final Color accent = colors[level - 1];

    // Fondo espacial
    final List<Color> backgrounds = [
      const Color(0xFF101E3B),
      const Color(0xFF332015),
      const Color(0xFF3D0B2C),
      const Color(0xFF11112E),
      const Color(0xFF070313),
    ];

    c.drawRect(
      Offset.zero & s,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF05091A),
            backgrounds[level - 1],
            const Color(0xFF02040B),
          ],
        ).createShader(Offset.zero & s),
    );

    // Estrellas
    for (int i = 0; i < stars.length; i++) {
      final double x =
          (stars[i] * s.width + i * 7) % s.width;

      final double y =
          (stars[(i * 7) % stars.length] * s.height +
                  i * 13) %
              s.height;

      final double radius = i % 9 == 0 ? 1.8 : 0.7;
      final double opacity = i % 3 == 0 ? 0.8 : 0.35;

      c.drawCircle(
        Offset(x, y),
        radius,
        Paint()
          ..color = Colors.white.withValues(
            alpha: opacity,
          ),
      );
    }

    // Líneas de velocidad
    final Paint lane = Paint()
      ..color = accent.withValues(alpha: 0.17)
      ..strokeWidth = 1;

    for (int i = 1; i < 6; i++) {
      final double y = s.height * i / 6;

      c.drawLine(
        Offset(0, y),
        Offset(s.width, y),
        lane,
      );
    }

    for (int i = 0; i < 8; i++) {
      final double x = s.width * i / 8;

      c.drawLine(
        Offset(x, s.height * 0.08),
        Offset(x - s.width * 0.12, s.height),
        lane,
      );
    }

    // La Sombra
    final double sx = s.width * (0.02 + shadow * 0.22);
    final double sy = s.height * 0.5;

    for (int i = 5; i >= 1; i--) {
      c.drawCircle(
        Offset(sx + i * 5, sy),
        s.height * (0.09 + i * 0.025),
        Paint()
          ..color = const Color(0xFF8B1AFF).withValues(
            alpha: 0.04 + shadow * 0.025,
          ),
      );
    }

    c.drawCircle(
      Offset(sx, sy),
      s.height * 0.22,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF2A064B).withValues(alpha: 0.95),
            const Color(0xFF05030D).withValues(alpha: 0.8),
            Colors.transparent,
          ],
        ).createShader(
          Rect.fromCircle(
            center: Offset(sx, sy),
            radius: s.height * 0.22,
          ),
        ),
    );

    c.drawCircle(
      Offset(sx + 20, sy - 10),
      3,
      Paint()..color = const Color(0xFFFF326B),
    );

    c.drawCircle(
      Offset(sx + 20, sy + 10),
      3,
      Paint()..color = const Color(0xFFFF326B),
    );

    // Nave rival
    drawShip(
      c,
      Offset(s.width * rival, s.height * 0.28),
      s,
      const Color(0xFFFF9B48),
      0.68,
      true,
    );

    // Asteroides y energía
    for (final SpaceObject o in objects) {
      final Offset p = Offset(
        s.width * o.x,
        s.height * o.y,
      );

      final double r = s.height * o.size;

      if (o.type == ObjectType.asteroid) {
        c.drawCircle(
          p,
          r,
          Paint()..color = const Color(0xFF6C6D80),
        );

        c.drawCircle(
          p.translate(-r * 0.25, -r * 0.2),
          r * 0.45,
          Paint()
            ..color = const Color(0xFFB1B4C5).withValues(
              alpha: 0.55,
            ),
        );

        c.drawCircle(
          p,
          r,
          Paint()
            ..color = const Color(0xFFFF8C61)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
      } else {
        c.drawCircle(
          p,
          s.height * 0.025,
          Paint()
            ..color = const Color(0xFF39E9FF).withValues(
              alpha: 0.18,
            ),
        );

        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: p,
              width: s.height * 0.025,
              height: s.height * 0.05,
            ),
            const Radius.circular(4),
          ),
          Paint()..color = const Color(0xFF43F4FF),
        );
      }
    }

    // Agujero negro
    if (hole) {
      final Offset p = Offset(
        s.width * 0.72,
        s.height * 0.5,
      );

      c.drawCircle(
        p,
        s.height * 0.12,
        Paint()
          ..color = const Color(0xFF9D32FF).withValues(
            alpha: 0.13,
          ),
      );

      c.drawCircle(
        p,
        s.height * 0.085,
        Paint()
          ..color = const Color(0xFF6E2BFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5,
      );

      c.drawOval(
        Rect.fromCenter(
          center: p,
          width: s.height * 0.11,
          height: s.height * 0.035,
        ),
        Paint()
          ..color = const Color(0xFFEC71FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );

      text(
        c,
        '¡SALTO!',
        p.translate(-25, s.height * 0.13),
        12,
        const Color(0xFFFFB7FA),
      );
    }

    // Nave del jugador
    drawShip(
      c,
      Offset(s.width * 0.18, s.height * shipY),
      s,
      const Color(0xFF50E9FF),
      1,
      false,
      turbo,
      shield,
    );

    text(
      c,
      'NOVA',
      Offset(
        s.width * 0.13,
        s.height * shipY + s.height * 0.085,
      ),
      9,
      Colors.white70,
    );
  }

  // ==========================================================
  // DIBUJAR LA NAVE ESPACIAL
  // ==========================================================

  void drawShip(
    Canvas c,
    Offset p,
    Size s,
    Color color,
    double scale,
    bool rival, [
    bool turbo = false,
    bool shield = false,
  ]) {
    c.save();

    c.translate(p.dx, p.dy);
    c.scale(scale);

    final double h = s.height;

    // Propulsor
    final Path flame = Path()
      ..moveTo(-h * 0.045, -h * 0.012)
      ..lineTo(
        -h * (turbo ? 0.13 : 0.075),
        0,
      )
      ..lineTo(-h * 0.045, h * 0.012)
      ..close();

    c.drawPath(
      flame,
      Paint()
        ..color = turbo
            ? const Color(0xFFFFE76A)
            : const Color(0xFFFF8B46),
    );

    // Alas
    final Path wings = Path()
      ..moveTo(-h * 0.035, -h * 0.012)
      ..lineTo(h * 0.005, -h * 0.06)
      ..lineTo(h * 0.045, -h * 0.042)
      ..lineTo(h * 0.035, -h * 0.009)
      ..lineTo(h * 0.035, h * 0.009)
      ..lineTo(h * 0.045, h * 0.042)
      ..lineTo(h * 0.005, h * 0.06)
      ..lineTo(-h * 0.035, h * 0.012)
      ..close();

    c.drawPath(
      wings,
      Paint()
        ..color = rival
            ? const Color(0xFF8B4254)
            : const Color(0xFF315A86),
    );

    c.drawPath(
      wings,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );

    // Cuerpo de la nave
    final Path body = Path()
      ..moveTo(h * 0.075, 0)
      ..lineTo(h * 0.018, -h * 0.025)
      ..lineTo(-h * 0.045, -h * 0.016)
      ..lineTo(-h * 0.058, 0)
      ..lineTo(-h * 0.045, h * 0.016)
      ..lineTo(h * 0.018, h * 0.025)
      ..close();

    c.drawPath(
      body,
      Paint()
        ..color = rival
            ? const Color(0xFFB5B8C8)
            : const Color(0xFFD7F8FF),
    );

    c.drawPath(
      body,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Cabina
    c.drawOval(
      Rect.fromCenter(
        center: Offset(h * 0.018, 0),
        width: h * 0.035,
        height: h * 0.018,
      ),
      Paint()
        ..color = rival
            ? const Color(0xFFFFB078)
            : const Color(0xFF087DAF),
    );

    // Escudo visual
    if (shield) {
      c.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: h * 0.17,
          height: h * 0.13,
        ),
        Paint()
          ..color = const Color(0xFF4ADFFF).withValues(
            alpha: 0.3,
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }

    c.restore();
  }

  // ==========================================================
  // TEXTO DIBUJADO EN EL ESCENARIO
  // ==========================================================

  void text(
    Canvas c,
    String t,
    Offset p,
    double size,
    Color color,
  ) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: t,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(c, p);
  }

  @override
  bool shouldRepaint(covariant SpacePainter oldDelegate) {
    return true;
  }
}
