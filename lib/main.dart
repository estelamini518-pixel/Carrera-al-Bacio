import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const CarreraApp());
}

class CarreraApp extends StatelessWidget {
  const CarreraApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false, title: 'Carrera al Vacío',
    theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: const Color(0xFF030611)),
    home: const GameScreen());
}

enum ObjectType { asteroid, energy }
class SpaceObject {
  SpaceObject(this.x, this.y, this.type, this.size);
  double x, y, size;
  ObjectType type;
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final random = math.Random();
  Timer? timer;
  double shipY = .5, shadow = .08, rival = .72, fuel = 1;
  int level = 1, points = 0, lives = 3;
  bool turbo = false, shield = false, paused = false, gameOver = false, victory = false;
  String message = 'IRIS: ¡Motores listos, Nova!';
  final objects = <SpaceObject>[];
  final stars = List<double>.generate(100, (_) => math.Random().nextDouble());
  final names = ['Estación Base', 'Campo de Asteroides', 'Nebulosa Roja', 'Nave Fantasma', 'Zona Muda'];
  bool get holeReady => shadow > .66;

  @override
  void initState() { super.initState(); makeObjects(); timer = Timer.periodic(const Duration(milliseconds: 45), (_) => tick()); }
  @override
  void dispose() { timer?.cancel(); super.dispose(); }

  void makeObjects() {
    objects
      ..clear()
      ..addAll(List.generate(9, (_) => SpaceObject(.55 + random.nextDouble()*.7, .12 + random.nextDouble()*.76,
        random.nextInt(10) < 6 ? ObjectType.asteroid : ObjectType.energy, .018 + random.nextDouble()*.025)));
  }

  void tick() {
    if (!mounted || paused || gameOver || victory) return;
    setState(() {
      final pace = (turbo ? .014 : .008) + level*.0012;
      fuel = (fuel - (turbo ? .003 : .0006)).clamp(0, 1);
      if (fuel == 0) turbo = false;
      for (final o in objects) {
        o.x -= pace * (o.type == ObjectType.asteroid ? 1 : .8);
        if (o.x < -.05) { o.x = 1.05 + random.nextDouble()*.4; o.y = .12 + random.nextDouble()*.76; o.type = random.nextInt(10) < 6 ? ObjectType.asteroid : ObjectType.energy; }
        if ((o.x-.18).abs() < .035 && (o.y-shipY).abs() < o.size+.04) {
          if (o.type == ObjectType.energy) { fuel = (fuel+.28).clamp(0,1); points += 100; message = '¡Energía recogida! +100 puntos'; }
          else if (!shield) { lives--; message = '¡Impacto de asteroide!'; if (lives <= 0) gameOver = true; }
          else { points += 50; message = 'Escudo activado: +50 puntos'; }
          o.x = 1.1 + random.nextDouble()*.3; o.y = .12 + random.nextDouble()*.76;
        }
      }
      rival -= pace*.6; if (rival < -.1) rival = 1.1;
      shadow += (level >= 3 ? .0032 : .0021) + (fuel == 0 ? .001 : 0);
      if (shadow > .96) { lives--; shadow = .38; message = '¡La Sombra te alcanzó! Perdiste una vida.'; if (lives <= 0) gameOver = true; }
      if (random.nextDouble() < .035) points++;
    });
  }

  void move(double dy) { if (!paused && !gameOver && !victory) setState(() => shipY = (shipY+dy).clamp(.12,.88)); }
  void useTurbo() {
    if (fuel < .08 || paused || gameOver || victory) { setState(() => message = 'IRIS: No hay combustible suficiente.'); return; }
    setState(() { turbo = true; points += 10; message = '¡TURBO! +10 puntos'; });
    Future.delayed(const Duration(milliseconds: 1400), () { if (mounted) setState(() => turbo = false); });
  }
  void useShield() {
    if (paused || gameOver || victory) return;
    setState(() { shield = true; points += 25; message = 'Escudo de energía: +25 puntos'; });
    Future.delayed(const Duration(seconds: 2), () { if (mounted) setState(() => shield = false); });
  }
  void emp() { if (paused || gameOver || victory) return; setState(() { shadow = (shadow-.18).clamp(.04,.92); points += 30; message = 'Pulso EMP: La Sombra retrocede. +30'; }); }
  void blackHole() {
    if (!holeReady || paused || gameOver || victory) return;
    setState(() {
      points += 500;
      if (level == 5) { victory = true; message = '¡Has escapado de la Zona Muda!'; }
      else { level++; shadow = .12; rival = .7; fuel = (fuel+.45).clamp(0,1); shipY = .5; makeObjects(); message = '¡Salto cuántico! +500. ${names[level-1]}'; }
    });
  }
  void reset() => setState(() {
    shipY=.5; shadow=.08; rival=.72; fuel=1; level=1; points=0; lives=3;
    turbo=shield=paused=gameOver=victory=false; message='IRIS: ¡Motores listos, Nova!'; makeObjects();
  });

  @override
  Widget build(BuildContext context) => Scaffold(body: Stack(children: [
    Positioned.fill(child: CustomPaint(painter: SpacePainter(level, shipY, shadow, rival, objects, stars, turbo, shield, holeReady))),
    Positioned(left:12, top:10, child: Container(padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(color: const Color(0xDD081226), border: Border.all(color: const Color(0xFF3A8EA9)), borderRadius: BorderRadius.circular(10)),
      child: DefaultTextStyle(style: const TextStyle(fontSize:11, color:Colors.white), child: Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
        Text('CARRERA AL VACÍO • NIVEL $level/5', style: const TextStyle(color:Color(0xFF62EAFF),fontWeight:FontWeight.w900)),
        Text(names[level-1]), Text('PUNTOS: $points   VIDAS: ${'♥ ' * lives}'),
        Row(children:[const Text('COMBUSTIBLE '), SizedBox(width:85, child:LinearProgressIndicator(value:fuel,minHeight:7, valueColor:const AlwaysStoppedAnimation(Color(0xFFFFB34F))))]),
        SizedBox(width:235, child:Text(message,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Color(0xFFB5D5F4),fontSize:10))),
      ])))),
    Positioned(top:8,right:12,child:IconButton.filledTonal(onPressed:()=>setState(()=>paused=!paused),icon:Icon(paused?Icons.play_arrow:Icons.pause))),
    Positioned(left:12,right:12,bottom:10,child:Row(children:[
      control('▲',()=>move(-.09)), const SizedBox(width:6), control('▼',()=>move(.09)), const Spacer(),
      action('TURBO',useTurbo,const Color(0xFFFFA43B)), const SizedBox(width:6),
      action('ESCUDO',useShield,const Color(0xFF45D8FF)), const SizedBox(width:6),
      action('PULSO EMP',emp,const Color(0xFFB69BFF)), if(holeReady) ...[const SizedBox(width:6),action('AGUJERO NEGRO',blackHole,const Color(0xFFFF4FD8),wide:true)],
    ])),
    if(paused||gameOver||victory) Positioned.fill(child:Container(color:Colors.black.withOpacity(.8),child:Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
      Text(victory?'¡CARRERA COMPLETADA!':gameOver?'LA SOMBRA TE ALCANZÓ':'PAUSA',style:const TextStyle(fontSize:26,fontWeight:FontWeight.w900,color:Color(0xFF61F2FF))),
      const SizedBox(height:8), Text('Puntuación: $points • Nivel: $level/5'),
      const SizedBox(height:12), ElevatedButton.icon(onPressed:gameOver||victory?reset:()=>setState(()=>paused=false),icon:Icon(gameOver||victory?Icons.replay:Icons.play_arrow),label:Text(gameOver||victory?'JUGAR OTRA VEZ':'CONTINUAR')),
    ])))),
  ]));

  Widget control(String t, VoidCallback cb) => SizedBox(width:44,height:42,child:ElevatedButton(style:ElevatedButton.styleFrom(padding:EdgeInsets.zero,backgroundColor:const Color(0xCC142B4C)),onPressed:cb,child:Text(t,style:const TextStyle(fontSize:20))));
  Widget action(String t, VoidCallback cb, Color c,{bool wide=false}) => SizedBox(height:42,child:ElevatedButton(style:ElevatedButton.styleFrom(backgroundColor:c.withOpacity(.2),foregroundColor:c,side:BorderSide(color:c),padding:EdgeInsets.symmetric(horizontal:wide?14:11)),onPressed:cb,child:Text(t,style:const TextStyle(fontSize:10,fontWeight:FontWeight.w900))));
}

class SpacePainter extends CustomPainter {
  SpacePainter(this.level,this.shipY,this.shadow,this.rival,this.objects,this.stars,this.turbo,this.shield,this.hole);
  final int level; final double shipY,shadow,rival; final List<SpaceObject> objects; final List<double> stars; final bool turbo,shield,hole;
  final colors=[const Color(0xFF4ADFFF),const Color(0xFFFFB34F),const Color(0xFFFF526D),const Color(0xFFB79BFF),const Color(0xFFEA5BFF)];
  @override
  void paint(Canvas c,Size s) {
    final accent=colors[level-1];
    c.drawRect(Offset.zero&s,Paint()..shader=LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[const Color(0xFF05091A),[const Color(0xFF101E3B),const Color(0xFF332015),const Color(0xFF3D0B2C),const Color(0xFF11112E),const Color(0xFF070313)][level-1],const Color(0xFF02040B)]).createShader(Offset.zero&s));
    for(int i=0;i<stars.length;i++){final x=(stars[i]*s.width+i*7)%s.width;final y=(stars[(i*7)%stars.length]*s.height+i*13)%s.height;c.drawCircle(Offset(x,y),i%9==0?1.8:.7,Paint()..color=Colors.white.withOpacity(i%3==0?.8:.35));}
    final lane=Paint()..color=accent.withOpacity(.17)..strokeWidth=1;
    for(int i=1;i<6;i++){final y=s.height*i/6;c.drawLine(Offset(0,y),Offset(s.width,y),lane);}
    for(int i=0;i<8;i++){final x=s.width*i/8;c.drawLine(Offset(x,s.height*.08),Offset(x-s.width*.12,s.height),lane);}
    final sx=s.width*(.02+shadow*.22), sy=s.height*.5;
    for(int i=5;i>=1;i--){c.drawCircle(Offset(sx+i*5,sy),s.height*(.09+i*.025),Paint()..color=const Color(0xFF8B1AFF).withOpacity(.04+shadow*.025));}
    c.drawCircle(Offset(sx,sy),s.height*.22,Paint()..shader=RadialGradient(colors:[const Color(0xFF2A064B).withOpacity(.95),const Color(0xFF05030D).withOpacity(.8),Colors.transparent]).createShader(Rect.fromCircle(center:Offset(sx,sy),radius:s.height*.22)));
    c.drawCircle(Offset(sx+20,sy-10),3,Paint()..color=const Color(0xFFFF326B));c.drawCircle(Offset(sx+20,sy+10),3,Paint()..color=const Color(0xFFFF326B));
    drawShip(c,Offset(s.width*rival,s.height*.28),s,const Color(0xFFFF9B48),.68,true);
    for(final o in objects){final p=Offset(s.width*o.x,s.height*o.y);final r=s.height*o.size;
      if(o.type==ObjectType.asteroid){c.drawCircle(p,r,Paint()..color=const Color(0xFF6C6D80));c.drawCircle(p.translate(-r*.25,-r*.2),r*.45,Paint()..color=const Color(0xFFB1B4C5).withOpacity(.55));c.drawCircle(p,r,Paint()..color=const Color(0xFFFF8C61)..style=PaintingStyle.stroke..strokeWidth=1.4);}
      else {c.drawCircle(p,s.height*.025,Paint()..color=const Color(0xFF39E9FF).withOpacity(.18));c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center:p,width:s.height*.025,height:s.height*.05),const Radius.circular(4)),Paint()..color=const Color(0xFF43F4FF));}
    }
    if(hole){final p=Offset(s.width*.72,s.height*.5);c.drawCircle(p,s.height*.12,Paint()..color=const Color(0xFF9D32FF).withOpacity(.13));c.drawCircle(p,s.height*.085,Paint()..color=const Color(0xFF6E2BFF)..style=PaintingStyle.stroke..strokeWidth=5);c.drawOval(Rect.fromCenter(center:p,width:s.height*.11,height:s.height*.035),Paint()..color=const Color(0xFFEC71FF)..style=PaintingStyle.stroke..strokeWidth=3);text(c,'¡SALTO!',p.translate(-25,s.height*.13),12,const Color(0xFFFFB7FA));}
    drawShip(c,Offset(s.width*.18,s.height*shipY),s,const Color(0xFF50E9FF),1,false,turbo,shield);
    text(c,'NOVA',Offset(s.width*.13,s.height*shipY+s.height*.085),9,Colors.white70);
  }
  void drawShip(Canvas c,Offset p,Size s,Color color,double scale,bool rival,[bool turbo=false,bool shield=false]){
    c.save();c.translate(p.dx,p.dy);c.scale(scale);final h=s.height;
    final flame=Path()..moveTo(-h*.045,-h*.012)..lineTo(-h*(turbo?.13:.075),0)..lineTo(-h*.045,h*.012)..close();
    c.drawPath(flame,Paint()..color=turbo?const Color(0xFFFFE76A):const Color(0xFFFF8B46));
    final wings=Path()..moveTo(-h*.035,-h*.012)..lineTo(h*.005,-h*.06)..lineTo(h*.045,-h*.042)..lineTo(h*.035,-h*.009)..lineTo(h*.035,h*.009)..lineTo(h*.045,h*.042)..lineTo(h*.005,h*.06)..lineTo(-h*.035,h*.012)..close();
    c.drawPath(wings,Paint()..color=rival?const Color(0xFF8B4254):const Color(0xFF315A86));c.drawPath(wings,Paint()..color=color..style=PaintingStyle.stroke..strokeWidth=1.8);
    final body=Path()..moveTo(h*.075,0)..lineTo(h*.018,-h*.025)..lineTo(-h*.045,-h*.016)..lineTo(-h*.058,0)..lineTo(-h*.045,h*.016)..lineTo(h*.018,h*.025)..close();
    c.drawPath(body,Paint()..color=rival?const Color(0xFFB5B8C8):const Color(0xFFD7F8FF));c.drawPath(body,Paint()..color=color..style=PaintingStyle.stroke..strokeWidth=1.5);
    c.drawOval(Rect.fromCenter(center:Offset(h*.018,0),width:h*.035,height:h*.018),Paint()..color=rival?const Color(0xFFFFB078):const Color(0xFF087DAF));
    if(shield)c.drawOval(Rect.fromCenter(center:Offset.zero,width:h*.17,height:h*.13),Paint()..color=const Color(0xFF4ADFFF).withOpacity(.3)..style=PaintingStyle.stroke..strokeWidth=3);
    c.restore();
  }
  void text(Canvas c,String t,Offset p,double size,Color color){final tp=TextPainter(text:TextSpan(text:t,style:TextStyle(color:color,fontSize:size,fontWeight:FontWeight.w900)),textDirection:TextDirection.ltr)..layout();tp.paint(c,p);}
  @override bool shouldRepaint(covariant SpacePainter oldDelegate)=>true;
}
