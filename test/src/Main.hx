
import luxe.Input;
import luxe.Sprite;
import luxe.Vector;

import Pack;

class Main extends luxe.Game {

    override function config(config:luxe.AppConfig) {

        config.preload.bytes.push({ id:'assets/assets.parcel' });

        return config;

    } //config

    override function ready() {

        var pack = new Pack('assets/assets.parcel');
        pack.preload().then(onload);

    } //ready

    function onload(pack:Pack) {
        trace('ready - loading test items');
        create_texture();
    }

    function create_texture() {
        var t = Luxe.resources.texture('assets/texture1.png');
        t.filter_mag = t.filter_min = nearest;
        var s = new Sprite({
            name:'test-sprite-texture1',
            size: new Vector(t.width*0.8,t.height*0.8),
            centered: false,
            texture: t
        });

        trace(t);
        trace(s.size);
        trace(s.pos);
    }

    override function onkeyup( e:KeyEvent ) {

        if(e.keycode == Key.escape) {
            Luxe.shutdown();
        }

    } //onkeyup

    override function update(dt:Float) {

    } //update


} //Main
