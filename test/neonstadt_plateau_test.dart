import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/pinball/pinball_table.dart';
import 'package:gluckspfennig/games/pinball/pinball_tables.dart';
void main(){
 for(final id in ['links_innen','rechts_innen']) {
  test('$id übergibt an eine andere Physikwelt',(){
   final t=PinballTable(rng:Random(1),spec:cityTable),r=cityTable.ramps.firstWhere((r)=>r.id==id);
   final lower=t.balls.first.body!.world;
   t.debugPlaceBall((r.a.x+r.b.x)/2,r.a.y+.4,0,-12);
   var upstairs=false;
   for(var i=0;i<300;i++){t.step(1/120);if(t.balls.any((b)=>b.onPlateau)){upstairs=true;break;}}
   expect(upstairs,isTrue);final b=t.balls.firstWhere((b)=>b.onPlateau);
   expect(identical(b.body!.world,lower),isFalse);
   expect(b.elevation,.85);
   expect(t.events.any((e)=>e.kind==PinballEventKind.target || e.kind==PinballEventKind.saucer),isFalse);
  });
 }
 for(final l in cityTable.lanes.where((l)=>l.group=='top')){
  test('Obere Gasse ${l.x} übergibt aufs Plateau',(){
   final t=PinballTable(rng:Random(2),spec:cityTable);t.debugPlaceBall(l.x,.55,0,2);t.step(1/120);
   expect(t.balls.first.onPlateau,isTrue);
   expect(identical(t.balls.first.body!.world,t.flippers.first.body.world),isFalse);
  });
 }
 test('Plateau hat nur seine Bumper und Ränder, keine Unterfeld-Körper',(){
   final t=PinballTable(rng:Random(2),spec:cityTable);t.debugPlacePlateauBall(5.0,2.45,0,0);
   final world=t.balls.first.body!.world;
   expect(identical(world,t.flippers.first.body.world),isFalse);
   final static=world.bodies.where((b)=>!identical(b,t.balls.first.body)).toList();
   expect(static.length,1);
   expect(static.single.fixtures.length,10); // 7 Randsegmente + 3 Bumper
 });
 test('240 Plateau-Verläufe verlassen es ausschließlich über beide Abfahrten',(){
  final exits=<String>{};
  for(var seed=0;seed<240;seed++){
   final rng=Random(seed),t=PinballTable(rng:Random(seed),spec:cityTable);
   t.debugPlacePlateauBall(3.65+rng.nextDouble()*3.15,.52+rng.nextDouble()*.25,(rng.nextDouble()-.5)*4,1+rng.nextDouble()*2);
   var exited=false;
   for(var i=0;i<7200;i++){
    t.step(1/120);final ball=t.balls.first;
    if(!ball.onPlateau){expect(ball.ramp?.spec.id,anyOf('_abfahrt_links','_abfahrt_rechts'));exits.add(ball.ramp!.spec.id);exited=true;break;}
    expect(ball.body!.position.y,lessThan(4.4));
    expect(t.events.any((e)=>e.kind==PinballEventKind.saucer || e.kind==PinballEventKind.target || e.kind==PinballEventKind.sling),isFalse);
   }
   if(!exited){print('FEST $seed ${t.ball!.x} ${t.ball!.y} ${t.ballSpeed} Bumper ${t.events.where((e)=>e.kind==PinballEventKind.bumper).length}');}
   expect(exited,isTrue,reason:'Plateau-Fall $seed nach 60 s');
  }
  expect(exits,{'_abfahrt_links','_abfahrt_rechts'});
 });
}
