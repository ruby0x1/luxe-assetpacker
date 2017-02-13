
import luxe.Audio;
import mint.types.Types.TextAlign;
import phoenix.Texture;
import luxe.resource.Resource;

@:allow(AssetPacker)
class Quickview {

    static var quickview = false;
    static var playing_sound: AudioHandle;
    static var quickviewpanel : mint.Scroll;
    static var quickviewoverlay : mint.Panel;

    static var quickviewr : mint.render.luxe.Scroll;
    static var quickviewor : mint.render.luxe.Panel;
    static var canvas : mint.Canvas;

    static function toggle() {

        if(quickview) { //hide

            Luxe.audio.stop(playing_sound);

            quickviewpanel.container.destroy_children();

            quickviewor.visual.color.tween(0.05, {a:0});
            quickviewr.visual.color.tween(0.1, {a:0}).onComplete(function(){
                quickviewpanel.visible = false;
                quickviewoverlay.visible = false;
                quickview = false;
                canvas.captured = null;
                AssetPacker.hovered = null;
                // canvas.find_focus();
            });

        } else { //show

            if(AssetPacker.hovered != null) {
                quickview = true;
                var ext = haxe.io.Path.extension(AssetPacker.hovered.info.full_path);
                switch(ext) {
                    case 'json','txt','glsl','csv','fnt':

                        quickviewpanel.x=Luxe.screen.w*0.15;
                        quickviewpanel.y=Luxe.screen.h*0.05;
                        quickviewpanel.w=Luxe.screen.w*0.7;
                        quickviewpanel.h=Luxe.screen.h*0.9;

                        //load the json string
                        var p = Luxe.resources.load_text(AssetPacker.hovered.info.full_path);
                        p.then(function(txt:TextResource) {

                            var dim = new luxe.Vector();
                            var disptext = txt.asset.text.substr(0, 1024);
                            if(disptext.length == 1024) disptext += '\n\n ... preview ...';

                            Luxe.renderer.font.dimensions_of(disptext, 14, dim);
                            //create the label to display it
                            var l = new mint.Label({
                                parent: quickviewpanel,
                                x:4,y:4,w:dim.x+8, h:dim.y+8,
                                text_size: 14,
                                align: TextAlign.left,
                                text:disptext,
                                mouse_input:false,
                            });

                            var lr : mint.render.luxe.Label = cast l.renderer;
                                lr.text.color.rgb(0xffffff);

                        });

                    case 'png','jpg':

                        var get = Luxe.resources.load_texture(AssetPacker.hovered.info.full_path);
                        get.then(function(t:Texture){

                            var tw = t.width;
                            var th = t.height;
                            var bw = Math.min(tw, Luxe.screen.w*0.7 );
                            var bh = Math.min(th, Luxe.screen.h*0.9 );
                            var bx = Luxe.screen.mid.x - (bw/2);
                            var by = Luxe.screen.mid.y - (bh/2);
                            quickviewpanel.x = bx;
                            quickviewpanel.y = by;
                            quickviewpanel.w = bw;
                            quickviewpanel.h = bh;
                            var i = new mint.Image({
                                parent: quickviewpanel,
                                path: t.id,
                                x:0,y:0,w:tw,h:th
                            });

                        });

                    case 'wav','ogg','pcm':

                        var i = new mint.Image({
                            parent: quickviewpanel,
                            path: 'assets/iconmonstr-sound-wave-icon-128.png',
                            x:2,y:2,w:64,h:64
                        });

                        quickviewpanel.x=Luxe.screen.mid.x-34;
                        quickviewpanel.y=Luxe.screen.mid.y-34;
                        quickviewpanel.w=68;
                        quickviewpanel.h=68;

                        Luxe.audio.stop(playing_sound);
                        var audio_path = AssetPacker.hovered.info.full_path;
                        Luxe.resources.load_audio(audio_path).then(function(sound:AudioResource){
                            if(sound != null) {
                                playing_sound = Luxe.audio.play(sound.source);
                            }
                        });

                    case _: AssetPacker._log('quickview / unknown extension $ext');
                }

                quickviewpanel.visible = true;
                quickviewoverlay.visible = true;
                quickviewor.visual.color.tween(0.15, {a:0.9});
                quickviewr.visual.color.tween(0.3, {a:1});
                canvas.captured = quickviewpanel;
            }

        } //show

    } //toggle

    static function create(_canvas) {

        canvas = _canvas;

        var width = Luxe.screen.w * 0.7;
        var height = Luxe.screen.h * 0.9;

        quickviewoverlay = new mint.Panel({
            parent: canvas,
            x:0,y:0,w:Luxe.screen.w,h:Luxe.screen.h,
            visible: false
        });

        quickviewpanel = new mint.Scroll({
            parent: canvas,
            x:Luxe.screen.w * 0.15,y:Luxe.screen.h*0.05,w:width,h:height,
            visible: false
        });

        quickviewr = cast quickviewpanel.renderer;
        quickviewor = cast quickviewoverlay.renderer;

        quickviewr.visual.color.a = 0;
        quickviewor.visual.color.a = 0;
        
        Luxe.audio.on(AudioEvent.ae_end, function(handle:AudioHandle) {
            if(handle == playing_sound) {
                toggle();
            }
        });

    } //create

} //Quickview