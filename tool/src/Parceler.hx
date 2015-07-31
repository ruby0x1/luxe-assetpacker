import luxe.Input;
import luxe.Color;

import luxe.resource.Resource;
import luxe.resource.Resource.BytesResource;
import mint.types.Types;
import mint.Control;
import mint.render.luxe.LuxeMintRender;
import mint.render.luxe.Convert;

import phoenix.Texture;
import snow.api.buffers.Uint8Array;

import Pack;
import Undoer;

import snow.api.Promise;

typedef FileInfo = { parcel_name:String, full_path:String };

//teardown/reopen

@:allow(Quickview)
class Parceler extends luxe.Game {

    public static var canvas : mint.Canvas;
    public static var render : LuxeMintRender;

    public static var selectview : mint.List;
    public static var hoverinfo : mint.Label;
    public static var selectinfo : mint.Label;
    public static var selectlist : Array<FileInfo>;

    public static var logl : mint.Label;
    public static var pathr : mint.render.luxe.Label;

    override function ready() {

        render = new LuxeMintRender();

        canvas = new mint.Canvas({
            w:Luxe.screen.w, h:Luxe.screen.h,
            rendering: render
        });

        create_right_menu();
        create_left_menu();
        create_select_view();
        Quickview.create(canvas);

    } //ready

    function normalize(path:String) {
        path = haxe.io.Path.normalize(path);
        path = StringTools.replace(path, '\\','/');
        path = StringTools.replace(path, '\\\\','/');
        return path;
    }


    function create_left_menu() {
        var left_w = Luxe.screen.w / 4;
        var left_l = 16;

        new mint.Label({
            parent: canvas,
            name: 'open_folder',
            x:left_l,y:8,w:left_w,h:22,
            text: 'open folder',
            align: TextAlign.left,
            text_size: 20,
            onclick: click_open_folder
        });

        new mint.Label({
            parent: canvas,
            name: 'open_pack',
            x:left_l,y:30,w:left_w,h:22,
            text: 'open packed parcel',
            align: TextAlign.left,
            text_size: 20,
            onclick: click_open_pack
        });

        new mint.Label({
            parent: canvas,
            name: 'label_select',
            x:left_l,y:64,w:left_w,h:16,
            text: 'select all',
            align: TextAlign.left,
            text_size: 16,
            onclick: click_select_all
        });

        new mint.Label({
            parent: canvas,
            name: 'label_selectnone',
            x:left_l,y:80,w:left_w,h:16,
            text: 'select none',
            align: TextAlign.left,
            text_size: 16,
            onclick: click_select_none
        });

        var zipcheck = new mint.Checkbox({
            parent: canvas,
            name: 'check_zip',
            x:left_l,y:112,w:16,h:16,
            onchange: click_toggle_zip,
            state: true,
        });


        new mint.Label({
            parent: canvas,
            name: 'label_checkzip',
            x:left_l+22,y:92+16,w:left_w,h:16,
            text: 'use zip',
            align: TextAlign.left,
            text_size: 16,
            mouse_input: true,
            onclick: function(_,_){
                zipcheck.state = !zipcheck.state;
            }
        });

    }

    function selectbutton( button:mint.Button, ?state:Null<Bool>, ?ignore_undo:Bool=false ) {

        var selected : mint.Image = cast button.children[1];

        var prestate = selected.visible;

        if(state == null) {
            selected.visible = !selected.visible;
            state = selected.visible;
        } else {
            selected.visible = state;
        }

        var path_info = selector_info.get(button);
        if(state) {
            selectlist.push(path_info);
        } else {
            selectlist.remove(path_info);
        }

        selectinfo.text = 'selected ${selectlist.length} / ${filelist.length}';

        if(!ignore_undo) Undoer.action([{ button:button, after:state, before:prestate }]);

        return { after:state, before:prestate };
    }

    function click_select_all(_,_) {

        if(selectors == null) return;
        if(selectors.length == 0) return;

        var actions = [];

        var idx = 0;
        for(b in selectors) {
            var sel = selectbutton(b, true, true);
            actions.push({ button:b, after:true, before:sel.before });
            idx++;
        }

        Undoer.action(actions);
        trace('actions:' + actions.length);

    } //click_select_all

    function click_select_none(_,_) {

        if(selectors == null) return;
        if(selectors.length == 0) return;

        var actions = [];
        for(b in selectors) {
            var sel = selectbutton(b, false, true);
            actions.push({ button:b, after:false, before:sel.before });
        }

        Undoer.action(actions);
        trace('actions:' + actions.length);
    }

    function click_toggle_zip(now:Bool, prev:Bool) {
        Packer.use_zip = now;
    } //click_toggle_zip

    function create_right_menu() {

        var right_w = Luxe.screen.w / 4;
        var right_l = Luxe.screen.w - right_w - 16;

        new mint.Label({
            parent: canvas,
            name: 'version',
            x:right_l,y:16,w:right_w,h:16,
            text: 'simple asset packer 0.1.0',
            align: TextAlign.right,
            text_size: 16
        });

        new mint.Label({
            parent: canvas,
            name: 'label_path_d',
            x:right_l,y:32,w:right_w,h:16,
            text: 'base assets path:',
            align: TextAlign.right,
            text_size: 16,
        });

        var _pathl = new mint.Label({
            parent: canvas,
            name: 'label_path',
            x:right_l,y:64,w:right_w,h:16,
            text: 'assets/',
            align: TextAlign.right,
            text_size: 16,
        });

        pathr = cast _pathl.renderer;

        logl = new mint.Label({
            parent: canvas,
            name: 'log',
            x:right_l, y:128, w:right_w, h:Luxe.screen.h - 128,
            text: 'log / initialized',
            align: TextAlign.right,
            text_size: 12
        });

        var _r:mint.render.luxe.Label = cast logl.renderer;
            _r.text.color.rgb(0x444444);

    }


    function build(_,_) {

        var items : Map<String,haxe.io.Bytes> = new Map();
        var wait : Array<snow.api.Promise> = [];

        for(l in selectlist) {
            var _id = l.parcel_name;

            trace('\t storing item id ' + _id);

            var p = Luxe.snow.assets.bytes(l.full_path);

                p.then(function(b:snow.system.assets.Asset.AssetBytes) {
                    items.set(_id, b.bytes.toBytes());
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

        var left_w = Luxe.screen.w / 4;

        selectview = new mint.List({
            parent: canvas,
            x:left_w, y:80, w:left_w*2, h:Luxe.screen.h - 96
        });

        hoverinfo = new mint.Label({
            parent: canvas,
            text: '...',
            x:left_w, y:78-16, w:(left_w*2)-96-16, h:16,
            text_size: 14,
        });

        selectinfo = new mint.Label({
            parent: canvas,
            text: 'open a folder to begin',
            x:left_w, y:78-32, w:(left_w*2)-96-16, h:16,
            text_size: 14,
        });

        selectlist = [];
        new mint.Button({
            parent: canvas,
            text: 'build ...',
            text_size: 16,
            x:selectview.right - 96, y:80-34, w:96, h:32,
            onclick: build
        });

    }

    static function _log( v:Dynamic ) {
        var t = logl.text;
        t = Std.string(v) +'\n'+ t;
        logl.text = t;
    }

    function click_open_pack(_,_) {

        var open_path = Luxe.core.app.io.module.dialog_open('select parcel to open', [{ extension:'parcel' }]);
        if(open_path.length > 0) {
            _log('action / open parcel selected\n$open_path');
            show_parcel_list( open_path );
        } else {
            _log('action / cancelled open parcel');
        }

    }

    function click_open_folder(_,_) {

        var open_path = Luxe.core.app.io.module.dialog_folder('select assets folder to show');
        if(open_path.length > 0) {
            _log('action / open dialog selected\n$open_path');
            show_folder_list( open_path );
        } else {
            _log('action / cancelled open dialog');
        }

    }


    function get_file_list( path:String, exts:Array<String>, recursive:Bool=true, ?into:Array<String> ) {

        if(into == null) into = [];

            var nodes = sys.FileSystem.readDirectory(path);
            for(node in nodes) {
                node = haxe.io.Path.join([path, node]);
                var is_dir = sys.FileSystem.exists(node) && sys.FileSystem.isDirectory(node);
                if(!is_dir) {

                    var ext = haxe.io.Path.extension(node);
                    if(exts.indexOf(ext) != -1) {
                        into.push(node);
                    }

                } else {
                    if(recursive) into = get_file_list(node, exts, into);
                }
            }

        return into;

    } //get_file_list

    function show_selector( title:String, filter:String, items:Array<String> ) {

        // trace('show $filter on ${items.length} ');

        var itemc = items.length;
        var per_row = 6;
        var itemw = Math.floor(selectview.w/per_row) - 4;
        var rows = Math.ceil(itemc / per_row);
        var height = (rows * (itemw+4))+32+16;

        var window = new mint.Window({
            name:'$filter.selector',
            parent: selectview,
            title:'$title ($itemc items)',
            x:0, y:0, w:selectview.w+1,h:height,
            closable: false,
            moveable: false,
            focusable: false
        });

        var rootidx = 0;
        for(row in 0 ... rows) {
            for(idx in 0 ... per_row) {

                if(rootidx >= itemc) continue;

               var path = normalize(items[rootidx]);
                var asset_base_path = pathr.text.text;
                var path_without_open_path = StringTools.replace(path, open_path, '');

                trace('base path: $asset_base_path');
                trace('open path: $open_path');
                trace('without open path: $path_without_open_path');

                var display_path = haxe.io.Path.join([ asset_base_path, path_without_open_path ]);
                    display_path = normalize(display_path);

                var path_info = { parcel_name:display_path, full_path:path };

                var fname = haxe.io.Path.withoutDirectory(path);
                    fname = haxe.io.Path.withoutExtension(fname);

                var button = new mint.Button({
                    parent: window,
                    text: fname,
                    text_size: 10,
                    x:4+(idx*(itemw+4)),y:32+(row*(itemw+4)), w:itemw, h:itemw
                });

                var image = null;
                var selected = new mint.Image({
                    parent: button,
                    path: 'assets/selected.png',
                    visible: false,
                    x:0,y:0, w:itemw, h:itemw,
                });

                trace('path: $path');

                if(filter == 'png' || filter == 'jpg') {
                    image = new mint.Image({
                        parent: button,
                        path: path,
                        visible:false,
                        x:4,y:4, w:itemw-8, h:itemw-8
                    });
                }

                button.onmouseenter.listen(function(_,e){
                    if(!selected.visible) {
                        if(image != null) image.visible = true;
                    }
                    hoverinfo.text = display_path;
                    Quickview.hoveredinfo = path;
                    Quickview.hoveredbutton = button;
                });

                button.onmouseleave.listen(function(_,_){
                    if(!selected.visible) if(image != null) image.visible = false;
                    hoverinfo.text = '';
                    Quickview.hoveredinfo = null;
                    Quickview.hoveredbutton = null;
                });

                button.onmousedown.listen(function(_,_){
                    selectbutton(button);
                });

                selectors.push(button);
                selector_info.set(button, path_info);

                rootidx++;
            }
        }

        selectview.add_item(window);

    }

    function show_parcel_list( path:String ) {

        open_path = normalize(path);

        new Pack(path, function(parcel:Pack) {

            trace(parcel);
            trace(parcel.pack);
            trace(parcel.pack.items);

            trace('loaded ${parcel.pack.id}, it contains ${Lambda.count(parcel.pack.items)} assets');

            selectinfo.text = 'loaded ${parcel.pack.id}, contains ${Lambda.count(parcel.pack.items)} assets';
            selectors = [];
            selector_info = new Map();

            var s = new luxe.Sprite({
                centered: false,
                texture: Luxe.resources.texture('assets/textures/packs/desk.png'),
                size: new luxe.Vector(128,128),
                depth:99
            });

            Luxe.audio.play('red_line_long');

            Luxe.timer.schedule(4, s.destroy.bind(false));

        });

    } //show_parcel_list

    var selectors : Array<mint.Button>;
    var selector_info : Map<mint.Button, FileInfo>;

    var open_path : String = '';
    var filelist : Array<String>;

    function show_folder_list( path:String ) {

        open_path = normalize(path);

        var exts = ['json', 'csv', 'txt', 'glsl', 'fnt', 'png', 'jpg', 'wav', 'ogg', 'pcm'];
        filelist = get_file_list(path, exts, true);
        selectinfo.text = 'found ${filelist.length} assets matching $exts, select files and hit build';
        selectors = [];
        selector_info = new Map();

        _log('open folder / found ${filelist.length}');
        _log('open folder / when matching ' + exts);

        for(ext in exts) {
            var items = filelist.filter(function(_s) return ext == haxe.io.Path.extension(_s) );
            if(items.length > 0) show_selector( '$ext files', ext, items );
        }

    } //show_folder_list


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
                    trace('redo');
                    Undoer.action(ActionType.redo, selectbutton);
                } else {
                    trace('undo');
                    Undoer.action(ActionType.undo, selectbutton);
                }
            }
        }
    }

    override function onkeyup( e:luxe.KeyEvent ) {

        if(e.keycode == Key.lctrl || e.keycode == Key.rctrl) ctrldown = false;
        if(e.keycode == Key.lalt || e.keycode == Key.ralt) altdown = false;
        if(e.keycode == Key.lmeta || e.keycode == Key.rmeta) metadown = false;
        if(e.keycode == Key.lshift || e.keycode == Key.rshift) shiftdown = false;

        if(e.keycode == Key.space) {
            Quickview.toggle();
        }

        if(e.keycode == Key.escape) {
            Luxe.shutdown();
        }

    } //onkeyup

    override function update(dt:Float) {
        canvas.update(dt);
    } //update


} //Main

