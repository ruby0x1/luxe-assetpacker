
//lib
import luxe.Log.*;
import luxe.Input;
import luxe.Color;
import phoenix.Texture;
import luxe.Parcel;
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

enum AssetType {
    bytes;
    text;
    json;
    texture;
    sound;
    font;
    shader;
}

typedef FileInfo = { parcel_name:String, full_path:String, selected : Bool };
typedef Node = { button:mint.Button, selector:mint.Image, info:FileInfo, type:AssetType };

@:allow(Quickview)
@:allow(Session)
class Parceler extends luxe.Game {

    public static var canvas : mint.Canvas;
    public static var layout : Margins;

    public static var selectview : mint.List;
    // public static var metaview : mint.List;
    public static var selectinfo : mint.Label;
    public static var flag_zip : mint.Checkbox;

    public static var selected : Array<Node>;
    public static var hovered : Node;
    public static var editing : Node;

    override function config(config:luxe.AppConfig) {

        config.preload.textures.push({ id:'assets/selected.png', filter_min:nearest, filter_mag:nearest });

        var _r = def(config.runtime, {});
        var _ext = def(_r.extensions, {});

        ext_textures = def(_ext.textures, ext_textures);
        ext_sounds = def(_ext.sounds, ext_sounds);
        ext_texts = def(_ext.texts, ext_texts);
        ext_jsons = def(_ext.jsons, ext_jsons);
        ext_shaders = def(_ext.shaders, ext_shaders);
        ext_fonts = def(_ext.fonts, ext_fonts);
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
        extensions = extensions.concat(ext_fonts);
        extensions = extensions.concat(ext_shaders);

        //order matters

        create_log();

        Session.init();

        create_right_menu();
        create_top_menu();
        create_select_view();
        // create_meta_view();
        Quickview.create(canvas);

        refresh_session();

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
            name:Luxe.utils.uniqueid(),
            parent: canvas,
            text: '...',
            align: TextAlign.right,
            x:16, y:20, w:Luxe.screen.w*0.75, h:24,
            text_size: 24,
        });

        _load.onmouseup.listen(function(_,_){ Session.load(); refresh_session(); });
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

        // trace('select ' + node.info.parcel_name + ': ' + state);

        var prestate = node.info.selected;

        if(state == null) {
            node.info.selected = !node.info.selected;
        } else {
            node.info.selected = state;
        }

        node.selector.visible = node.info.selected;

        if(node.info.selected) {
            if(selected.indexOf(node) == -1) selected.push(node);
        } else {
            selected.remove(node);
        }

        selectinfo.text = 'selected ${selected.length} / ${Session.session.files.length}';

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

        selectinfo = new mint.Label({
            name:Luxe.utils.uniqueid(),
            parent: canvas,
            text: 'add a folder to begin',
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

        flag_zip = new mint.Checkbox({
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
                flag_zip.state = !flag_zip.state;
            }
        });

    }

    function build(_,_) {

        var wait : Array<snow.api.Promise> = [];
        var pack : AssetPack = {
            id: 'parcel', //:todo:
            bytes: new Map(),
            texts: new Map(),
            jsons: new Map(),
            textures: new Map(),
            shaders: new Map(),
            fonts: new Map(),
            sounds: new Map(),
        };

        for(node in selected) {

            var _id = node.info.parcel_name;

            var p = Luxe.snow.assets.bytes(node.info.full_path);

            p.then(function(b:snow.system.assets.Asset.AssetBytes) {
                
                trace('\t storing item id ' + _id);

                var _item = { id:_id, bytes:b.bytes.toBytes() };
                switch(node.type) {
                    case AssetType.bytes: pack.bytes.set(_id, _item);
                    case AssetType.text: pack.texts.set(_id, _item);
                    case AssetType.json: pack.jsons.set(_id, _item);
                    case AssetType.texture: pack.textures.set(_id, _item);
                    case AssetType.shader: pack.shaders.set(_id, _item);
                    case AssetType.font: pack.fonts.set(_id, _item);
                    case AssetType.sound: pack.sounds.set(_id, _item);
                }

            });

            wait.push( p );

        }

        _log('build / selected items: ${selected.length}, in queue: ${wait.length}');

            //wait for them all
        Promise.all(wait).then(function(_){

            var packed = Packer.compress_pack(pack);

            var size = Luxe.utils.bytes_to_string(packed.length);
            _log('build / built pack from ${selected.length} items, parcel is $size');

            var save_path = Luxe.core.app.io.module.dialog_save('select parcel file to save to', { extension:'parcel' });
            if(save_path.length > 0) {
                writebytes(save_path, packed);
            }

        }).error(function(e){

            _log('build / failed!!');
            _log('build / failed!!');
            _log('build / failed!!');

            _log(e);

        }); //wait

    }

    function writebytes(path:String, bytes:haxe.io.Bytes) {

        Luxe.snow.io.data_save(path, Uint8Array.fromBytes(bytes));

    } //writebytes

/*
    function create_meta_view() {

        var w = (Luxe.screen.w/4)-48;
        var x = (Luxe.screen.w*0.75)+32;

        metaview = new mint.List({
            parent: canvas,
            x:x, y:128, w:w, h:320
        });

    } //create_meta_view
*/

    function create_select_view() {

        var left_w = 16;
        var mid_w = Luxe.screen.w - (Luxe.screen.w/4);

        selectview = new mint.List({
            parent: canvas,
            x:left_w, y:64, w:mid_w, h:Luxe.screen.h - 80
        });

        selected = [];

    } //create_select_view

    static var logl : mint.Label;
    function create_log() {

        var right_w = Luxe.screen.w / 4;
        var right_l = Luxe.screen.w - right_w;

        logl = new mint.Label({
            parent: canvas,
            name: 'log',
            x:right_l+24, y:128+320+16, w:right_w-32, h:320,
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
        trace(v);
    }

    function refresh_session() {
        if(Session.session.files.length > 0) {
            selectview.clear();
            assetviews = null;
            show_files();
        }
    } //refresh_session

    function click_refresh_session(_,_) {

        refresh_session();

    } //refresh

    function click_reset_session(_,_) {

        Session.reset_session();

        //reset view state
        // metaview.clear();
        selectview.clear();
        selected = [];

        //reset ui
        flag_zip.state = Session.session.flag_zip;
        selectinfo.text = 'add a folder to begin';

    } //click_reset_session

/*
    function meta_for(_node:Node) {

        metaview.clear();

        if(_node == null) return;

        inline function section(_title:String) {
            var _section = new mint.Panel({
                name:'section.$_title',
                parent:canvas,
                w:metaview.w,h:1,
                options:{color:new Color()}
            });
            var _label = new mint.Label({
                name:'title.$_title',
                parent:canvas, w:metaview.w,h:18,text_size:16,
                text:'$_title meta' , align:TextAlign.right
            });
            var _desc = new mint.Label({
                name:'file.$_title',
                parent:canvas, w:metaview.w,h:24,text_size:11, bounds_wrap:true,
                text:'${_node.info.parcel_name}' , align:TextAlign.right, align_vertical:TextAlign.top
            });
            metaview.add_item(_section,0,4);
            metaview.add_item(_label,0,4);
            metaview.add_item(_desc,0,2);
        }//section

        section(type_name(_node.type));

        switch(_node.type) {
            case AssetType.texture:
                // var _panel = new mint.Panel({
                //     parent:canvas,
                //     options: { color:new Color().rgb(0x343434) },
                //     x:1, y:1, w:metaview.w-2, h:128
                // });
                // var _pre = new mint.Checkbox({
                //     parent: _panel,
                //     name: 'texture_pre',
                //     options: { color:new Color().rgb(0xffffff) },
                //     x:metaview.w-6-24, y:4, w: 24, h: 24
                // });
                // new mint.Label({
                //     parent: _panel,
                //     name:'texture_pre.label',
                //     align: TextAlign.right,
                //     x:0, w:metaview.w-2-32-4, h:32, text_size:11,
                //     text:'load premultiplied',
                //     onclick: function(_,_) { _pre.state = !_pre.state; }
                // });
                // metaview.add_item(_panel,0,4);
            case _:
        }

    } //meta_for
*/

    function type_for_ext(f:String) {
        if(is_bytes(f)) return AssetType.bytes;
        if(is_text(f)) return AssetType.text;
        if(is_json(f)) return AssetType.json;
        if(is_texture(f)) return AssetType.texture;
        if(is_sound(f)) return AssetType.sound;
        if(is_font(f)) return AssetType.font;
        if(is_shader(f)) return AssetType.shader;
        return AssetType.bytes;
    }

    function type_name_for_ext(f:String) {
        if(is_bytes(f)) return 'bytes';
        if(is_text(f)) return 'text';
        if(is_json(f)) return 'json';
        if(is_texture(f)) return 'texture';
        if(is_sound(f)) return 'sound';
        if(is_font(f)) return 'font';
        if(is_shader(f)) return 'shader';
        return 'unknown';
    }

    function type_name(f:AssetType) {
        switch(f) {
            case AssetType.bytes: return 'bytes';
            case AssetType.text: return 'text';
            case AssetType.json: return 'json';
            case AssetType.texture: return 'texture';
            case AssetType.sound: return 'sound';
            case AssetType.font: return 'font';
            case AssetType.shader: return 'shader';
        }
        return 'unknown';
    }

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

    var assetviews:Map<String,mint.Window>;
    function get_asset_view(_type:String, _count:Int, _height:Int) {

        if(assetviews == null) assetviews = new Map();
        if(assetviews.exists(_type)) return assetviews.get(_type);

        var _window = new mint.Window({
            name:'$_type.selector',
            parent: selectview,
            title:'$_type assets ($_count items)',
            w: selectview.w-8, h: _height,
            options: { color_titlebar:new Color().rgb(0x202020), color:new Color().rgb(0x121212) },
            closable: false, moveable: false, focusable: false, collapsible: true
        });

        assetviews.set(_type, _window);

        return _window;

    } //get_asset_views

    var prev_window:mint.Window = null;
    function show_selector( title:String, assettype:String, items:Array<FileInfo> ) {

        // trace('show $assettype on ${items.length} ');

        var isvisual = assettype == 'texture';
        var itemc = items.length;
        var per_row = isvisual ? 4 : 4;
        var itemw = Math.floor(selectview.w/per_row) - 7;
        var rows = Math.ceil(itemc / per_row);
        var itemh = isvisual ? itemw+4 : 24;
        var height = (rows * (itemh+4))+38;

        var window = get_asset_view(assettype, itemc, height);

        var rootidx = 0;
        for(row in 0 ... rows) {
            for(idx in 0 ... per_row) {

                if(rootidx >= itemc) continue;

                var file = items[rootidx];

                var fname = StringTools.replace(file.parcel_name, Session.session.path_base, '');
                var ext = haxe.io.Path.extension(file.full_path);

                //controls

                    var button = new mint.Button({
                        name:Luxe.utils.uniqueid(),
                        parent: window,
                        text: isvisual ? '' : fname,
                        align: (isvisual ? TextAlign.center : TextAlign.left),
                        text_size: 11,
                        x:4+(idx*(itemw+4)),y:32+(row*(itemh+4)), w:itemw, h:itemh
                    });

                    var image = null;
                    if(is_texture(ext)) {
                        image = new mint.Image({
                            name:Luxe.utils.uniqueid(),
                            parent: button,
                            path: file.full_path,
                            visible: true,
                            options: {
                                sizing:'cover'
                            },
                            x:4,y:4, w:itemw-8, h:itemw-8,
                        });
                        var _p = new mint.Panel({
                            name:Luxe.utils.uniqueid(),
                            parent:button,
                            y:(itemw/2)-12, w:itemw, h:24,
                            options:{color:new Color(0,0,0,0.5)}
                        });
                        new mint.Label({
                            name:Luxe.utils.uniqueid(),
                            parent: _p,
                            text: fname,
                            text_size:12,
                            w:itemw, h:24
                        });
                    }

                    var _found = sys.FileSystem.exists(file.full_path);
                    var _selector_image = isvisual ? 'assets/selected.png' : 'assets/selecteds.png';
                    var _selector_color = new Color();
                    if(!_found) {
                        trace('!! missing file in session! ${file.parcel_name} || ${file.full_path}');
                        _selector_color.rgb(0xff0000);
                        _selector_color.tween(0.2, {r:0.5}).delay(0.1+(0.2+Math.random())).repeat().reflect();
                    }

                    var _selector = new mint.Image({
                        parent: button,
                        name:Luxe.utils.uniqueid()+'.select',
                        options: { color: _selector_color },
                        path: _selector_image,
                        visible: file.selected,
                        w:itemw, h:itemh,
                    });

                    var node = {
                        button:button,
                        selector: _selector,
                        info:file,
                        type:type_for_ext(ext)
                    };

                //interaction

                    button.onmouseenter.listen(function(_,e){
                        hovered = node;
                        // if(editing == null) meta_for(node);
                    });

                    button.onmouseleave.listen(function(_,_){
                        hovered = null;
                        // if(editing == null) meta_for(null);
                    });

                    button.onmousedown.listen(function(e:mint.types.Types.MouseEvent,_){
                        if(e.button == left) {
                            selectnode(node);
                        } else if(e.button == right) {
                            if(editing != node) {
                                editing = node;
                            } else {
                                editing = null;
                            }
                        }
                    });

                selectors.push(node);

                if(file.selected) {
                    selectnode(node, true, true);
                }

                rootidx++;

            } //each row

        } //each rows

        selectview.add_item(window);

        if(prev_window != null) {
            // layout.anchor(window, prev_window, top, bottom);
        }

        window.oncollapse.listen(function(_){
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

        for(_type in assettypes) {

            var items = Session.session.files.filter(
                function(_f) {
                    var _ext = haxe.io.Path.extension(_f.full_path);
                    var _typematch = type_name_for_ext(_ext) == _type;
                    var _ignored = is_ignored(_f.parcel_name);
                    return _typematch && !_ignored;
                }
            );

            if(items.length > 0) show_selector('$_type files', _type, items);
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

    static var assettypes = ['texture', 'bytes', 'text', 'json', 'font', 'shader', 'sound'];
    static var extensions = [];
    static var ext_textures = ['jpg', 'png', 'tga', 'psd', 'bmp', 'gif', 'parcel-textures-meta'];
    static var ext_sounds = ['wav','pcm','ogg', 'parcel-sounds-meta'];
    static var ext_texts = ['csv', 'txt'];
    static var ext_shaders = ['glsl','parcel-shaders-meta'];
    static var ext_fonts = ['fnt'];
    static var ext_jsons = ['json'];
    static var ext_bytes = [];

    function is_ignored(_parcel_name:String) {
        var _list = Session.session.paths_ignore;
        var _found = false;

        for(_path in _list) {
            if(StringTools.startsWith(_parcel_name, _path)) {
                _found = true;
                break;
            }
        }

        return _found;
    }

    function is_texture(ext:String) return ext_textures.indexOf(ext) != -1;
    function is_sound(ext:String)   return ext_sounds.indexOf(ext) != -1;
    function is_shader(ext:String)  return ext_shaders.indexOf(ext) != -1;
    function is_font(ext:String)    return ext_fonts.indexOf(ext) != -1;
    function is_text(ext:String)    return ext_texts.indexOf(ext) != -1;
    function is_json(ext:String)    return ext_jsons.indexOf(ext) != -1;
    function is_bytes(ext:String)   return ext_bytes.indexOf(ext) != -1;

} //Main

