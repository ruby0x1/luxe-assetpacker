
//lib
import luxe.Log.*;
import luxe.Input;
import luxe.Color;
import phoenix.Texture;
import luxe.resource.Resource;
import luxe.resource.Resource.BytesResource;

import snow.api.Promise;
import snow.api.buffers.Uint8Array;

//ui
import mint.Control;
import mint.types.Types;
import mint.render.luxe.Convert;
import mint.layout.margins.Margins;

//tools
import Pack;
import Undoer;
import Session;


typedef FileInfo = { parcel_name:String, full_path:String, selected : Bool };
typedef Node = { button:mint.Button, info:FileInfo };

@:allow(Quickview)
@:allow(Session)
class Parceler extends luxe.Game {

    public static var canvas : mint.Canvas;
    public static var layout : Margins;

    public static var selectview : mint.List;
    public static var hoverinfo : mint.Label;
    public static var selectinfo : mint.Label;
    public static var selectlist : Array<FileInfo>;

    override function config(config:luxe.AppConfig) {

        var _r = def(config.runtime, {});
        var _ext = def(_r.extensions, {});

        ext_textures = def(_ext.textures, ext_textures);
        ext_sounds = def(_ext.sounds, ext_sounds);
        ext_texts = def(_ext.texts, ext_texts);
        ext_jsons = def(_ext.jsons, ext_jsons);
        ext_bytes = def(_ext.bytes, ext_bytes);

        return config;

    } //config

    override function ready() {

        layout = new Margins();
        canvas = new mint.Canvas({
            w:Luxe.screen.w, h:Luxe.screen.h,
            rendering: new mint.render.luxe.LuxeMintRender()
        });

        extensions = extensions.concat(ext_jsons);
        extensions = extensions.concat(ext_bytes);
        extensions = extensions.concat(ext_texts);
        extensions = extensions.concat(ext_textures);
        extensions = extensions.concat(ext_sounds);

        //order matters

        create_log();

        Session.init();

        create_right_menu();
        create_top_menu();
        create_select_view();
        Quickview.create(canvas);


        if(Session.session.files.length > 0) {
            refresh_session();
        }

    } //ready

    static function normalize(path:String) {
        path = haxe.io.Path.normalize(path);
        path = StringTools.replace(path, '\\','/');
        path = StringTools.replace(path, '\\\\','/');
        return path;
    }


    function hover_image(img:mint.Image, tip:String) {

        inline function handler(h:Bool) {
            var r:mint.render.luxe.Image = cast img.renderer;
            var c = h ? 0xf6007b : 0xffffff;
            r.visual.color.rgb(c);
        }

        img.onmouseleave.listen(function(_,_){ handler(false); menu_label.text = ''; });
        img.onmouseenter.listen(function(_,_){ handler(true); menu_label.text = tip; });

    } //hover_image

    var menu_label : mint.Label;

    function create_top_menu() {

        var left_w = Luxe.screen.w / 4;
        var left_l = 16;

        var _load = new mint.Image({
            parent: canvas,
            name: 'load_session',
            x:16+(48*0),y:16,w:32,h:32, mouse_input: true,
            path: 'assets/iconmonstr-folder-2-icon-32.png',
        });

        var _save = new mint.Image({
            parent: canvas,
            name: 'save_session',
            x:16+(48*1),y:16,w:30,h:30,mouse_input: true,
            path: 'assets/iconmonstr-save-3-icon-32.png',
        });

        var _refresh = new mint.Image({
            parent: canvas,
            name: 'refresh_session',
            x:16+(48*2),y:16,w:34,h:34,mouse_input: true,
            path: 'assets/iconmonstr-refresh-3-icon-32.png',
        });

        var _reset = new mint.Image({
            parent: canvas,
            name: 'reset_session',
            x:16+(48*3),y:16,w:30,h:30,mouse_input: true,
            path: 'assets/iconmonstr-refresh-2-icon-32.png',
        });

        var _folder = new mint.Image({
            parent: canvas,
            name: 'open_folder',
            x:16+(48*5),y:16,w:32,h:32,mouse_input: true,
            path: 'assets/iconmonstr-add-folder-2-icon-32.png',
        });

        var _selectall = new mint.Image({
            parent: canvas,
            name: 'select_all',
            x:16+(48*7),y:20,w:24,h:24,mouse_input: true,
            path: 'assets/iconmonstr-selection-10-icon-32.png',
        });

        var _selectnone = new mint.Image({
            parent: canvas,
            name: 'select_none',
            x:16+(48*8),y:20,w:24,h:24,mouse_input: true,
            path: 'assets/iconmonstr-selection-11-icon-32.png',
        });

        var _build = new mint.Image({
            parent: canvas,
            name: 'build',
            x:16+(48*10),y:20,w:24,h:24,mouse_input: true,
            path: 'assets/iconmonstr-shipping-box-9-icon-32.png',
        });

        menu_label = new mint.Label({
            parent: canvas,
            text: '...',
            align: TextAlign.right,
            x:16, y:20, w:Luxe.screen.w*0.75, h:24,
            text_size: 24,
        });

        _load.onmouseup.listen(function(_,_){ Session.load(); });
        _save.onmouseup.listen(function(_,_){ Session.save(shiftdown); });
        _refresh.onmouseup.listen(click_refresh_session);
        _reset.onmouseup.listen(click_reset_session);
        _folder.onmouseup.listen(click_open_folder);
        _selectall.onmouseup.listen(click_select_all);
        _selectnone.onmouseup.listen(click_select_none);
        _build.onmouseup.listen(build);

        hover_image(_load, 'load session');
        hover_image(_save, 'save session');
        hover_image(_refresh, 'refresh session');
        hover_image(_reset, 'reset session');
        hover_image(_folder, 'add folder');
        hover_image(_selectall, 'select all');
        hover_image(_selectnone, 'select none');
        hover_image(_build, 'build');

    } //create_top_menu

    function selectnode( node:Node, ?state:Null<Bool>, ?ignore_undo:Bool=false ) {

        trace('select ' + node.info.parcel_name + ': ' + state);

        var selected : mint.Image = cast node.button.children[1];

        var prestate = selected.visible;

        if(state == null) {
            selected.visible = !selected.visible;
            state = selected.visible;
        } else {
            selected.visible = state;
        }

        node.info.selected = state;

        if(state) {
            selectlist.push(node.info);
        } else {
            selectlist.remove(node.info);
        }

        selectinfo.text = 'selected ${selectlist.length} / ${Session.session.files.length}';

        if(!ignore_undo) Undoer.action([{ node:node, after:state, before:prestate }]);

        return { after:state, before:prestate };

    } //selectnode

    function click_select_all(_,_) {

        if(selectors == null) return;
        if(selectors.length == 0) return;

        var actions = [];

        var idx = 0;
        for(n in selectors) {
            var sel = selectnode(n, true, true);
            actions.push({ node:n, after:true, before:sel.before });
            idx++;
        }

        Undoer.action(actions);
        trace('actions:' + actions.length);

    } //click_select_all

    function click_select_none(_,_) {

        if(selectors == null) return;
        if(selectors.length == 0) return;

        var actions = [];
        for(n in selectors) {
            var sel = selectnode(n, false, true);
            actions.push({ node:n, after:false, before:sel.before });
        }

        Undoer.action(actions);
        trace('actions:' + actions.length);
    }

    function click_toggle_zip(now:Bool, prev:Bool) {
        Packer.use_zip = now;
        Session.session.flag_zip = now;
    } //click_toggle_zip

    function create_right_menu() {

        var right_w = Luxe.screen.w / 4;
        var right_l = Luxe.screen.w - right_w - 16;

        new mint.Label({
            parent: canvas,
            name: 'version',
            x:right_l,y:16,w:right_w,h:16,
            text: 'simple asset packer 0.2.0',
            align: TextAlign.right,
            text_size: 16
        });

        hoverinfo = new mint.Label({
            parent: canvas,
            text: '...',
            align: TextAlign.right,
            x:right_l, y:64, w:right_w, h:16,
            text_size: 10,
        });

        selectinfo = new mint.Label({
            parent: canvas,
            text: 'open a folder to begin',
            align: TextAlign.right,
            x:right_l, y:48, w:right_w, h:16,
            text_size: 14,
        });

        // new mint.Label({
        //     parent: canvas,
        //     name: 'label_path_d',
        //     x:right_l,y:32,w:right_w,h:16,
        //     text: 'base assets path:',
        //     align: TextAlign.right,
        //     text_size: 16,
        // });

        // var _pathl = new mint.Label({
        //     parent: canvas,
        //     name: 'label_path',
        //     x:right_l,y:64,w:right_w,h:16,
        //     text: 'assets/',
        //     align: TextAlign.right,
        //     text_size: 16,
        // });

        var zipcheck = new mint.Checkbox({
            parent: canvas,
            name: 'check_zip',
            x:Luxe.screen.w-32,y:96,w:16,h:16,
            onchange: click_toggle_zip,
            state: Session.session.flag_zip
        });

        new mint.Label({
            parent: canvas,
            name: 'label_checkzip',
            x:Luxe.screen.w-32-64-8,y:96-2,w:64,h:16,
            text: 'use zip',
            align: TextAlign.right,
            text_size: 16,
            mouse_input: true,
            onclick: function(_,_){
                zipcheck.state = !zipcheck.state;
            }
        });

    }


    function build(_,_) {

        var items : Map<String,AssetItem> = new Map();
        var wait : Array<snow.api.Promise> = [];

        for(l in selectlist) {
            var _id = l.parcel_name;

            trace('\t storing item id ' + _id);

            var p = Luxe.snow.assets.bytes(l.full_path);

                p.then(function(b:snow.system.assets.Asset.AssetBytes) {
                    items.set(_id, { bytes:b.bytes.toBytes(), meta:{id:_id} });
                });

            wait.push( p );

        }

            //wait for them all
        Promise.all(wait).then(function(_){

            var packed = Packer.compress_pack({
                id: 'assets.parcel',
                items : items
            });

            var size = Luxe.utils.bytes_to_string(packed.length);
            _log('build / built pack from ${selectlist.length} items, parcel is $size');

            var save_path = Luxe.core.app.io.module.dialog_save('select parcel file to save to', { extension:'parcel' });
            if(save_path.length > 0) {
                writebytes(save_path, packed);
            }

        }); //wait

    }

    function writebytes(path:String, bytes:haxe.io.Bytes) {

        Luxe.snow.io.data_save(path, Uint8Array.fromBytes(bytes));

    } //writebytes

    function create_select_view() {

        var left_w = 16;
        var mid_w = Luxe.screen.w - (Luxe.screen.w/4);

        selectview = new mint.List({
            parent: canvas,
            x:left_w, y:64, w:mid_w, h:Luxe.screen.h - 80
        });

        selectlist = [];

    } //create_select_view

    static var logl : mint.Label;
    function create_log() {

        var right_w = Luxe.screen.w / 4;
        var right_l = Luxe.screen.w - right_w;

        logl = new mint.Label({
            parent: canvas,
            name: 'log',
            x:right_l+24, y:128, w:right_w-32, h:Luxe.screen.h - 128,
            text: 'log / initialized',
            align: TextAlign.right,
            align_vertical: TextAlign.top,
            bounds_wrap: true,
            options: { color:new Color().rgb(0x444444) },
            text_size: 11
        });

    } //create_log

    static function _log( v:Dynamic ) {
        var t = logl.text;
        t = Std.string(v) +'\n'+ t;
        var m = 1024;
        if(t.length > m) {
            t = t.substr(0, m);
        }
        logl.text = t;
    }

    function refresh_session() {
        selectview.clear();
        show_files();
    } //refresh_session

    function click_refresh_session(_,_) {
        refresh_session();
    } //refresh

    function click_reset_session(_,_) {
        selectview.clear();
        Session.reset_session();
    } //reset

    function click_open_folder(_,_) {

        var _path = Luxe.core.app.io.module.dialog_folder('select assets folder to show');
        if(_path.length > 0) {
            _log('action / open dialog selected\n$_path');
            Session.add_path(_path);
            refresh_session();
        } else {
            _log('action / cancelled open dialog');
        }

    } //click_open_folder

    var prev_window:mint.Window = null;
    function show_selector( title:String, filter:String, items:Array<FileInfo> ) {

        // trace('show $filter on ${items.length} ');

        var itemc = items.length;
        var per_row = 6;
        var itemw = Math.floor(selectview.w/per_row) - 6;
        var rows = Math.ceil(itemc / per_row);
        var height = (rows * (itemw+4))+32+16;

        var window = new mint.Window({
            name:'$filter.selector',
            parent: selectview,
            title:'$title ($itemc items)',
            x:0, y:0, w:selectview.w-8,h:height,
            closable: false,
            moveable: false,
            focusable: false,
            collapsible: true
        });

        var rootidx = 0;
        for(row in 0 ... rows) {
            for(idx in 0 ... per_row) {

                if(rootidx >= itemc) continue;

                var path_info = items[rootidx];

                trace(path_info);

                var fname = haxe.io.Path.withoutDirectory(path_info.full_path);
                    fname = haxe.io.Path.withoutExtension(fname);

                var button = new mint.Button({
                    parent: window,
                    text: fname,
                    text_size: 10,
                    x:4+(idx*(itemw+4)),y:32+(row*(itemw+4)), w:itemw, h:itemw
                });

                var node = { button:button, info:path_info };

                    //this has to come first atm, selected.children[1]
                var selected = new mint.Image({
                    parent: button,
                    path: 'assets/selected.png',
                    visible: path_info.selected,
                    x:0,y:0, w:itemw, h:itemw,
                });

                var image = null;
                if(is_texture(filter)) {
                    image = new mint.Image({
                        parent: button,
                        path: path_info.full_path,
                        visible: false,
                        x:4,y:4, w:itemw-8, h:itemw-8
                    });
                }

                button.onmouseenter.listen(function(_,e){
                    if(!selected.visible) {
                        if(image != null) image.visible = true;
                    }
                    hoverinfo.text = path_info.parcel_name;
                    Quickview.hoveredinfo = path_info.full_path;
                    Quickview.hoveredbutton = button;
                });

                button.onmouseleave.listen(function(_,_){
                    if(!selected.visible) if(image != null) image.visible = false;
                    hoverinfo.text = '';
                    Quickview.hoveredinfo = null;
                    Quickview.hoveredbutton = null;
                });

                button.onmousedown.listen(function(_,_){
                    selectnode(node);
                });

                selectors.push(node);

                if(path_info.selected) {
                    image.visible = true;
                    selectnode(node, true, true);
                }

                rootidx++;
            }
        }

        selectview.add_item(window);

        if(prev_window != null) {
            // layout.anchor(window, prev_window, top, bottom);
        }

        window.oncollapse.listen(function(_){
            trace('collapse ' + window.name);
            selectview.view.refresh_scroll();
        });

        prev_window = window;

    } //show_selector

    var selectors : Array<Node>;

    function show_files() {

        selectinfo.text = 'found ${Session.session.files.length} assets';
        selectors = [];

        _log('open folder / found ${Session.session.files.length}');
        _log('open folder / when matching\n' + extensions);

        prev_window = null;

        for(ext in extensions) {
            var items = Session.session.files.filter(function(_f) return ext == haxe.io.Path.extension(_f.full_path) );
            if(items.length > 0) show_selector('$ext files', ext, items);
        }

    } //show_files

    override function onmousemove(e) {
        canvas.mousemove( Convert.mouse_event(e) );
    }

    override function onmousewheel(e) {
        canvas.mousewheel( Convert.mouse_event(e) );
    }

    override function onmouseup(e) {
        canvas.mouseup( Convert.mouse_event(e) );
    }

    override function onmousedown(e) {
        canvas.mousedown( Convert.mouse_event(e) );
    }

    var ctrldown = false;
    var altdown = false;
    var metadown = false;
    var shiftdown = false;
    override function onkeydown( e:luxe.KeyEvent ) {

        if(e.keycode == Key.lctrl || e.keycode == Key.rctrl) { ctrldown = true; }
        if(e.keycode == Key.lalt || e.keycode == Key.ralt) { altdown = true; }
        if(e.keycode == Key.lmeta || e.keycode == Key.rmeta) { metadown = true; }
        if(e.keycode == Key.lshift || e.keycode == Key.rshift) { shiftdown = true; }

            //undo
        if(e.keycode == Key.key_z) {
            if(ctrldown || metadown) {
                if(shiftdown) {
                    Undoer.action(ActionType.redo, selectnode);
                } else {
                    Undoer.action(ActionType.undo, selectnode);
                }
            }
        }

    } //onkeydown

    override function onkeyup( e:luxe.KeyEvent ) {

        if(e.keycode == Key.lctrl || e.keycode == Key.rctrl) ctrldown = false;
        if(e.keycode == Key.lalt || e.keycode == Key.ralt) altdown = false;
        if(e.keycode == Key.lmeta || e.keycode == Key.rmeta) metadown = false;
        if(e.keycode == Key.lshift || e.keycode == Key.rshift) shiftdown = false;

        if(e.keycode == Key.space) {
            Quickview.toggle();
        }

        if(e.keycode == Key.key_s && (ctrldown||metadown)) {
            Session.save(shiftdown);
        }

        if(e.keycode == Key.escape) {
            Luxe.shutdown();
        }

    } //onkeyup

    override function update(dt:Float) {
        canvas.update(dt);
    } //update

    static var extensions = [];
    static var ext_textures = ['jpg', 'png', 'tga', 'psd', 'bmp', 'gif'];
    static var ext_sounds = ['wav','pcm','ogg'];
    static var ext_texts = ['csv', 'txt', 'glsl', 'fnt'];
    static var ext_jsons = ['json'];
    static var ext_bytes = [];

    function is_texture(ext:String) return ext_textures.indexOf(ext) != -1;
    function is_sound(ext:String)   return ext_sounds.indexOf(ext) != -1;
    function is_text(ext:String)    return ext_texts.indexOf(ext) != -1;
    function is_json(ext:String)    return ext_jsons.indexOf(ext) != -1;
    function is_bytes(ext:String)   return ext_bytes.indexOf(ext) != -1;

} //Main

