package;


import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.Sprite;
import openfl.display.Shape;
import openfl.Assets;
import openfl.geom.Matrix;
import openfl.events.*;
import openfl.media.*;

import openfl.text.*;

import haxe.ds.*;

class Main extends Sprite {
	
  public static var t:Float = 0;

  public static var isKey:Int->Bool;
  public static var game:Game;

  public static var message:String->Void;

  public static var lives:Int = 3;
  public static var map_id:Int = 0;
  public static var map_data:Array<Dynamic> = [
    {
      mx0:173,
      my0:290,
      r0:0
    },
    {
      mx0:68,
      my0:286,
      r0:0
    },
    {
      mx0:259,
      my0:300,
      r0:0
    },
    {
      mx0:180,
      my0:180,
      r0:0
    }
                                               ];

	public function new () {

		super ();

    var W=180.0;
    var H=120.0;
    var W2=W/2;
    var H2=H/2;
    var SC=4.0;

		var map = Assets.getBitmapData("assets/map_"+Main.map_id+".png");

    var ambient:Sound = Assets.getSound("assets/underwater.ogg");
    ambient.play(0, 9999);

    var grid = new Sprite();
    grid.alpha = 0.03;
    grid.graphics.lineStyle(1, 0xffffff);
    grid.graphics.drawRect(0, 0, W*SC, H*SC);
    for (xx in 0...Std.int(W)) {
      grid.graphics.lineStyle(1, 0xffffff);
      grid.graphics.moveTo(xx*SC,0);
			grid.graphics.lineTo(xx*SC,H*SC);
      grid.graphics.lineStyle(1, 0x0);
      grid.graphics.moveTo(xx*SC+1,0);
			grid.graphics.lineTo(xx*SC+1,H*SC);
    }
    for (yy in 0...Std.int(H)) {
      grid.graphics.lineStyle(1, 0xffffff);
			grid.graphics.moveTo(0, yy*SC);
			grid.graphics.lineTo(W*SC, yy*SC);
      grid.graphics.lineStyle(1, 0x0);
			grid.graphics.moveTo(0, yy*SC+1);
			grid.graphics.lineTo(W*SC, yy*SC+1);
    }
    stage.addChild(grid);
    grid.x = stage.stageWidth/2-W2*SC;
		grid.y = stage.stageHeight/2-H2*SC;

    var overlay = new Sprite();
    overlay.x = stage.stageWidth/2-W2*SC;
		overlay.y = stage.stageHeight/2-H2*SC;
    overlay.alpha = 0;
    stage.addChild(overlay);

		var bd = new BitmapData(Std.int(W), Std.int(H), true, 0xff111111);
		var bitmap = new Bitmap (bd);
		addChild (bitmap);

		this.scaleX = SC;
		this.scaleY = SC;
    bitmap.x = -W2;
    bitmap.y = -H2;

    // bd.setPixel32(0,  0,  0xffff0000);
    // bd.setPixel32(W-1,0,  0xffff0000);
    // bd.setPixel32(0,  H-1,0xffff0000);
    // bd.setPixel32(W-1,H-1,0xffff0000);

    var clear:Shape = new Shape();

		this.x = stage.stageWidth/2;
    this.y = stage.stageHeight/2;

    message = function(s:String):Void {
      var l = TextUtil.make_label(s);
      l.x = stage.stageWidth/2 - l.textWidth/2;
      l.y = stage.stageHeight/2 - l.textHeight/2;
      var a = 4.;
      function hide(e) {
        a -= 0.1;
        if (a<=1) l.alpha = a;
        if (l.alpha<=0) {
          stage.removeEventListener(Event.ENTER_FRAME, hide);
        }
      }
      if (s.indexOf("win")<0) { // don't hide "you win"
				stage.addEventListener(Event.ENTER_FRAME, hide);
			}
      stage.addChild(l);
    }

    var keys = new IntMap<Bool>();
    stage.addEventListener(KeyboardEvent.KEY_UP, function(e:KeyboardEvent) {
			keys.set(e.keyCode, false);
		});
    stage.addEventListener(KeyboardEvent.KEY_DOWN, function(e:KeyboardEvent) {
        keys.set(e.keyCode, true);
		});
    isKey = function(code:Int):Bool
    {
      return keys.exists(code) && keys.get(code);
    }

    game = new Game(clear, overlay, bd, W, W2, H, H2, SC, map);

    stage.addEventListener(Event.ENTER_FRAME, function(e) { t+=2; if (game!=null) game.update(); });

  }

  public static function blend(c0:Int, c1:Int, amt:Float):Int
  {
    if (amt>1) amt = 1;
    if (amt<0) amt = 0;
    var b0:Int = c0 & 0xff;
    var b1:Int = c1 & 0xff;
    var g0:Int = (c0 >> 8)&0xff;
		var g1:Int = (c1 >> 8)&0xff;
    var r0:Int = (c0 >> 16)&0xff;
		var r1:Int = (c1 >> 16)&0xff;
    return Std.int((b1*amt + b0*(1-amt))) |
           Std.int((g1*amt + g0*(1-amt)))<<8 |
           Std.int((r1*amt + r0*(1-amt)))<<16;
  }
}

class Game
{
  public var update:Void->Void;

  public function new(clear:Shape, overlay:Sprite, bd:BitmapData, W:Float, W2:Float, H:Float, H2:Float, SC:Float, map:BitmapData)
  {
    Main.t = 0;
    Main.message("Level "+(Main.map_id+1));

    var bubbles:Sound = Assets.getSound("assets/bubbles.ogg");
    var death:Sound = Assets.getSound("assets/death.ogg");
    var squeek:Sound = Assets.getSound("assets/squeek.ogg");
    var success:Sound = Assets.getSound("assets/success.ogg");

    map = map.clone();

    overlay.alpha = 0;
    clear.graphics.clear();
    clear.graphics.beginFill(0x0, 0.7);
    clear.graphics.drawRect(0,0,W,H);

    var p = new Player();

    var px_screen = W2;
    var py_screen = H2;

    var init = Main.map_data[Main.map_id];
    var map_x = init.mx0;
		var map_y = init.my0;

    var sparks:Array<Spark>;
    sparks = [];
    for (i in 0...50) {
      sparks.push(new Spark());
    }

    var powerups = new Array<PowerUp>();
    for (y in 0...map.height) {
      for (x in 0...map.width) {
        if (map.getPixel(x, y)==0xff0000) {
          powerups.push(new PowerUp());
          powerups[powerups.length-1].x = x+W2;
          powerups[powerups.length-1].y = y+H2;
          map.setPixel32(x, y, 0);
        }
      }
    }

    var m:Matrix = new Matrix();
    var rotate:Float = init.r0;
    var acc:Float = 0.0;
    var gravity = 3.0;
    var dr = 0.0;
    var tap_state:Int = 0;
    var cont = new Sprite();
    var growth = 0;
    var dead = false;
    var win = false;

    var bmx:Array<Float> = [];
    var bmy:Array<Float> = [];
    var bmr:Array<Float> = [];
    for (i in 0...200) { bmr.push(0); bmx.push(map_x); bmy.push(map_y); }

    this.update = function() {
      acc = Main.t < 50 ? 0 : 0.7*acc + 0.3*1;
      dr = dr*0.8;
      if (Main.isKey(90) && Main.isKey(67)) { // z
        //acc = 0.7*acc + 0.3*1;
        //tap_state++;
      } else if (Main.isKey(90)) { // z
        dr = 0.7*dr + 0.3*( -0.15+0.02*Math.sin(Main.t/20) );
        tap_state = 0;
      } else if (Main.isKey(67)) { // c
        dr = 0.7*dr + 0.3*(  0.15+0.02*Math.sin(Main.t/20) );
        tap_state = 0;
      } else {
        //if (tap_state>0 && tap_state<4) {
        //  rotate -= Math.PI;
        //  acc = 1;
        //}
        tap_state = 0;
      }
      if (dead || win) dr = 0;

      rotate += dr;
      p.update(acc);

      // Clear
      bd.draw(clear);
      
      // Draw children
      bmx.unshift(map_x);
      bmy.unshift(map_y);
      bmr.unshift(rotate);
      bmx.pop(); bmy.pop();
      var c = growth*2;
      for (i in 0...200) {
        if (i>9 && (i%5==0)) {
          if ((c--)==0) break;
          m.identity();
          m.rotate(bmr[i]);
          m.scale(0.5, 0.5);
          m.translate(W2-(map_x-bmx[i]), H2-(map_y-bmy[i]));
          bd.draw(p, m);
        }
      }

      // m.identity();
      // m.rotate(rotate);
      // m.translate(map_x, map_y);
      // map.draw(p, m);

      // Draw map
      m.identity();
      m.translate(W2-map_x, H2-map_y);
      bd.draw(map, m);

      // Check collision
      inline function check(xx:Int, yy:Int):Int {
        if (win || true) return 0;
        var c:Int = bd.getPixel32(xx, yy);
        var alpha:Int = c >> 24 & 0xff;
        var blue:Int = c & 0xff;
        var green:Int = c >> 8 & 0xff;
        //if (green>200) return 2;
        return (blue > 30) ? 1 : 0;
      }
      var collision = Math.max( Math.max(
          check(Std.int(px_screen+12*Math.cos(rotate-Math.PI/2)),
                Std.int(py_screen+12*Math.sin(rotate-Math.PI/2))),
          check(Std.int(px_screen+10*Math.cos(rotate-Math.PI/2+Math.PI/10)),
                Std.int(py_screen+10*Math.sin(rotate-Math.PI/2+Math.PI/10))) ),
          check(Std.int(px_screen+10*Math.cos(rotate-Math.PI/2-Math.PI/10)),
                Std.int(py_screen+10*Math.sin(rotate-Math.PI/2-Math.PI/10))) );
      if (collision==1 && !dead && !win && Main.t>10) { // death
        clear.graphics.beginFill(0xff0000, 1);
        clear.graphics.drawRect(0,0,W,H);
        dead = true;
        overlay.graphics.beginFill(0xff0000, 1);
        overlay.graphics.drawRect(0,0,W*SC,H*SC);
        death.play();
      }

      var min_d = 99999.0;
      var min_i = 0;
      var tip_dx = 5*Math.cos(rotate-Math.PI/2);
      var tip_dy = 5*Math.sin(rotate-Math.PI/2);
      for (i in 0...powerups.length) {
        var d = Math.sqrt(Math.pow(powerups[i].x-map_x-W2-tip_dx, 2)+Math.pow(powerups[i].y-map_y-H2-tip_dy, 2));
        if (d<min_d) {
          min_d = d;
          min_i = i;
        }
      }
      if (min_d < 7) {
        powerups.remove(powerups[min_i]);
        growth++;
        bubbles.play();
        squeek.play();

        if (powerups.length==0) {
          win = true;
          success.play();
          clear.graphics.beginFill(0xeefff3, 1);
          clear.graphics.drawRect(0,0,W,H);
          overlay.graphics.beginFill(0xeefff3, 1);
          overlay.graphics.drawRect(0,0,W*SC,H*SC);
        }
      }

      for (i in 0...powerups.length) {
        m.identity();
        m.translate(powerups[i].x-map_x, powerups[i].y-map_y);
        //m.copyFrom(powerups[i].transform.matrix);
        //m.translate(map_x, map_y);
        bd.draw(powerups[i], m);
        powerups[i].update();
      }

      if (dead || win) {
        overlay.alpha += 0.06;
      }
      if (overlay.alpha>=1) {
        // reset
        if (dead) Main.lives--;
        if (win) {
          Main.map_id++;
          if (Main.map_id >= Main.map_data.length) {
            Main.message("Excellent, you win!");
            Main.game = null;
            return;
          }
        }
        if (Main.lives==0) {
          // Start screen?
          if (Main.map_id>0) Main.map_id--;
          Main.lives = 3;
        }
        var map = Assets.getBitmapData("assets/map_"+Main.map_id+".png");
        Main.game = new Game(clear, overlay, bd, W, W2, H, H2, SC, map);
      }

      // Draw player
      m.identity();
      m.rotate(rotate);
			m.translate(px_screen, py_screen);
			bd.draw(p, m);

      var dmap_x =  Math.sin(rotate)*acc*3;
			var dmap_y = -Math.cos(rotate)*acc*3;
      acc = acc*0.8;
      //dmap_y += gravity*(0.1+0.1*Math.sin(Main.t/4));

      if (dead || win) {
        dmap_x = 0;
        dmap_y = 0;
      }

      map_x += dmap_x;
      map_y += dmap_y;

      for (i in 0...sparks.length) {
        sparks[i].x -= dmap_x;
        sparks[i].y -= dmap_y;
        sparks[i].update();
        if (sparks[i].alpha<0) {
          sparks[i].reset();
          if (i<10) {
            sparks[i].x = px_screen-3+6*Math.random();
            sparks[i].y = py_screen-3+6*Math.random();
          } else {
            sparks[i].x = px_screen-40+80*Math.random();
            sparks[i].y = py_screen-30+60*Math.random();
          }
        }
        while (cont.numChildren>0) cont.removeChildAt(0);
        cont.addChild(sparks[i]);
        bd.draw(cont); //sparks[i], sparks[i].transform.matrix);
      }

      for (y in 0...Std.int(H)) {
        for (x in 0...Std.int(W)) {
          var dx = x-px_screen;
          var dy = y-(py_screen-4);
          var d = Math.sqrt(dx*dx+dy*dy);
          var c = bd.getPixel(x, y);
          c = Main.blend(c, 0x000000, Math.max(-0.1, (d-20)/70)+Math.random()/10);
          bd.setPixel(x, y, c);
        }
      }

      for (i in 0...powerups.length) {
        m.identity();
        m.scale(0.3, 0.3);
        m.translate(6*(i+1), H-10);
        bd.draw(powerups[i], m);
      }

      for (i in 0...Main.lives) {
        m.identity();
        m.scale(0.3, 0.3);
        m.translate(W-6*(i+1), H-10);
        bd.draw(p, m);
      }

		}
	}
}

class Player extends Sprite
{
  var left_legs:Array<Sprite>;
  var right_legs:Array<Sprite>;

  var speed:Float = 20;
  var stiff = 0.30;
  var t:Float = 0;

  var num_legs = 8;

  public function new()
  {
    left_legs = [];
    right_legs = [];

    super();
    draw_body();

    for (i in 0...num_legs) {
      left_legs.push(new Sprite());
      right_legs.push(new Sprite());
      left_legs[i].graphics.beginFill(0x112233);
      left_legs[i].graphics.drawCircle(0,0,1.4-0.1*i);
      right_legs[i].graphics.beginFill(0x112233);
			right_legs[i].graphics.drawCircle(0,0,1.4-0.1*i);

      left_legs[i].graphics.beginFill(0x223344);
      left_legs[i].graphics.drawCircle(0,0,1-0.1*i);
      right_legs[i].graphics.beginFill(0x223344);
			right_legs[i].graphics.drawCircle(0,0,1-0.1*i);

      left_legs[i].x = -5 - 0.2*i;
      right_legs[i].x = 5 + 0.2*i;
      left_legs[i].y = 
        right_legs[i].y = 1 + 1.2*i;
      addChild(left_legs[i]);
      addChild(right_legs[i]);
    }
  }

  function draw_body()
  {
    var g = graphics;
    g.clear();
    g.beginFill(0x223344);
    //g.drawRect(-5, -5, 10, 5);
    g.moveTo(-5-0.5*Math.sin(t/(speed*2)),-5);
    g.lineTo(-4-0.5*Math.sin(t/(speed*2)),0);
    g.lineTo(0,1+0.5*Math.sin(t/(speed*2)));
    g.lineTo(4+0.5*Math.sin(t/(speed*2)),0);
    g.lineTo(5+0.5*Math.sin(t/(speed*2)),-5);
    g.beginFill(0x223344);
    g.drawCircle(0, -6, 4.5+0.5*Math.sin(t/(speed*2)));
    g.endFill();

    g.lineStyle(1, 0x112233);
		g.moveTo(-5,0);
		g.curveTo(0,-5, 5,0);

    g.lineStyle(0, 0, 0);
    g.beginFill(0x112233, 0.6);
    g.drawCircle(-2, -6, 1);
    g.drawCircle(2, -6, 1);
    g.drawCircle(0, -9, 1);

    g.beginFill(0x223344, 0.75);
		g.drawCircle(-2, -6, 0.6+0.4*Math.sin(t/20));
		g.drawCircle(2, -6, 0.6+0.4*Math.sin(t/20));
		g.drawCircle(0, -9, 0.6+0.4*Math.sin(t/20));
  }

  public function update(acc:Float) {
    t = Main.t;
    speed = 20-17*acc;
    stiff = 0.3 + acc*0.2;

    draw_body();

    left_legs[0].x = 0 + (3+stiff)*Math.cos(t/speed);
    right_legs[0].x = 0 - (3+stiff)*Math.cos(t/speed);
    for (i in 1...num_legs) {
      left_legs[i].x = (1-stiff)*left_legs[i].x + (stiff)*left_legs[i-1].x;
      right_legs[i].x = (1-stiff)*right_legs[i].x + (stiff)*right_legs[i-1].x;

      left_legs[i].y = 
        right_legs[i].y = left_legs[i].y*0.9 + 0.1*(1 + 4*i*stiff);

    }
  }
}


class PowerUp extends Sprite
{
  var t:Float = 0;
  public function new()
  {
    super();
    draw_body();
  }

  function draw_body()
  {
    var g = graphics;
    g.clear();
    g.beginFill(0x336644);
    g.drawCircle(0,0,3+Math.sin(t/15));
    for (i in 0...10) {
      g.drawCircle((8+i/3)*Math.sin((t*3+i*116)/30),
                   (8+i/3)*Math.cos((t*3+i*116)/30),
                   0.2*i);
    }
  }

  public function update() {
    t = Main.t;

    draw_body();
  }
}




class Spark extends Sprite
{
  public var dx:Float = 0;
  public var dy:Float = 0;
  public var dr:Float = 0;
  public var max_a:Float = 0.0;
  public var up:Bool = true;

  public function new() {
    super();
    reset();
  }

  public function update()
  {
    this.x += dx;
    this.y += dy;
    this.rotation += dr;
    if (up) {
      this.alpha = alpha + 0.03*Math.random();
      if (this.alpha>max_a) up = false;
    } else {
      this.alpha = alpha - 0.03*Math.random();
    }
  }

  public function reset()
  {
    dx = Math.random()-0.5;
    dy = Math.random()-0.5;
    dr = Math.random()*0.1;
    up = true;
    max_a = 0.25+Math.random()*0.3;
  
    this.x = -2 + 4*Math.random();
    this.y = -2 + 4*Math.random();
    this.alpha = 0.001;

    graphics.clear();
    var c:Int = 0x223344;
    c = Main.blend(c, 0xffffff, Math.random()*0.3);
    c = Main.blend(c, 0x0, Math.random()*0.3);
    c = Main.blend(c, 0x00ff00, Math.random()*0.2);
    c = Main.blend(c, 0x0000ff, Math.random()*0.2);
    graphics.beginFill(c);
    graphics.drawCircle(-3+6*Math.random(),
                        -3+6*Math.random(),
                        1.5*Math.random());
  }
}

class TextUtil {

  private static var fonts:StringMap<Font> = new StringMap<Font>();

  public static function text_format(size:Int=11,
                                     color:Int=0xaaaaaa,
                                     font_file:String="8bit16.ttf"):TextFormat
  {
    if (!fonts.exists(font_file)) fonts.set(font_file, Assets.getFont("assets/"+font_file));

    var format = new TextFormat(fonts.get(font_file).fontName, size, color);
    return format;
  }

  public static function make_label(text:String,
                                    size:Int=40,
                                    color:Int=0xaaaaaa,
                                    width:Int=-1,
                                    font_file:String="8bit16.ttf")
  {
    var format = text_format(size, color, font_file);
    var textField = new TextField();

    textField.defaultTextFormat = format;
    textField.embedFonts = true;
    textField.selectable = false;

    textField.text = text;
    textField.width = (width >= 0) ? width : textField.textWidth+4;
    textField.height = textField.textHeight+4;

    return textField;
  }

}
