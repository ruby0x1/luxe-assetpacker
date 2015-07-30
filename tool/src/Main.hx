
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
import snow.api.Promise;

@:enum abstract ActionType(Int) from Int to Int {
    var undo = 0;
    var redo = 1;
}

typedef UndoState = { button:mint.Button, before:Bool, after:Bool };
typedef FileInfo = { parcel_name:String, full_path:String };

//teardown/reopen

class Main extends luxe.Game {

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
        create_quick_view();

    } //ready

    function normalize(path:String) {
        path = haxe.io.Path.normalize(path);
        path = StringTools.replace(path, '\\','/');
        path = StringTools.replace(path, '\\\\','/');
        return path;
    }


    function create_quick_view() {

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

        var quickviewr : mint.render.luxe.Scroll = cast quickviewpanel.renderer;
            quickviewr.visual.color.a = 0;
        var quickviewor : mint.render.luxe.Panel = cast quickviewoverlay.renderer;
            quickviewor.visual.color.a = 0;
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

    var undo_stack:Array< Array<UndoState> >;
    var redo_stack:Array< Array<UndoState> >;

    function action( ?act:Array<UndoState>, ?type:ActionType) {

        if(undo_stack == null) undo_stack = [];
        if(redo_stack == null) redo_stack = [];

        if(act != null) {
            undo_stack.push(act);
            if(undo_stack.length > 1000) {
                undo_stack.shift();
            }

            redo_stack = [];

        } else if(type != null) {
            switch(type) {

                case undo: {
                    var lastact = undo_stack.pop();
                    if(lastact != null) {
                        for(inst in lastact) {
                            selectbutton( inst.button, inst.before, true );
                        }

                        redo_stack.push(lastact);
                        if(redo_stack.length > 1000) redo_stack.shift();
                    }
                } //undo

                case redo: {
                    var lastundo = redo_stack.pop();
                    if(lastundo != null) {

                        for(inst in lastundo) {
                            selectbutton( inst.button, inst.after, true );
                        }

                        undo_stack.push(lastundo);
                        if(undo_stack.length > 1000) undo_stack.shift();
                    }
                } //redo

            } //switch type
        } //type != null

        trace('undos: ${undo_stack.length} / redos: ${redo_stack.length}');

    } //action

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

        if(!ignore_undo) action([{ button:button, after:state, before:prestate }]);

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

        action(actions);
        trace('actions:' + actions.length);
    }

    function click_select_none(_,_) {

        if(selectors == null) return;
        if(selectors.length == 0) return;

        var actions = [];
        for(b in selectors) {
            var sel = selectbutton(b, false, true);
            actions.push({ button:b, after:false, before:sel.before });
        }

        action(actions);
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
            onclick: click_path
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

    public function _log( v:Dynamic ) {
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

    var focus = false;

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
                    hoveredinfo = path;
                    hoveredbutton = button;
                });

                button.onmouseleave.listen(function(_,_){
                    if(!selected.visible) if(image != null) image.visible = false;
                    hoverinfo.text = '';
                    hoveredinfo = null;
                    hoveredbutton = null;
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

        var exts = ['json', 'csv', 'txt', 'fnt', 'png', 'jpg', 'wav', 'ogg', 'pcm'];
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

    function click_path(_, _) {

        if(!focus) {
            focus = true;
            pathr.text.add( new TextEdit() );
            pathr.color_hover = pathr.color = new Color().rgb(0xe2f44d);
            pathr.text.color.rgb(0xe2f44d);
        }

    }

    override function onmousemove(e) {
        if(canvas!=null) canvas.mousemove( Convert.mouse_event(e) );
    }

    override function onmousewheel(e) {
        if(canvas!=null) canvas.mousewheel( Convert.mouse_event(e) );
    }

    override function onmouseup(e) {
        if(canvas!=null) canvas.mouseup( Convert.mouse_event(e) );
    }

    override function onmousedown(e) {
        if(canvas!=null) canvas.mousedown( Convert.mouse_event(e) );
    }

    function defocus() {
        focus = false;
        pathr.text.remove('text_edit');
        pathr.color_hover.rgb(0xf6007b);
        pathr.color.rgb(0xffffff);
        pathr.text.color.rgb(0xffffff);
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
                    //redo
                    trace('redo');
                    action(ActionType.redo);
                } else {
                    //undo
                    trace('undo');
                    action(ActionType.undo);
                }
            }
        }
    }

    var quickview = false;
    var hoveredinfo : Null<String>;
    var hoveredbutton : mint.Button;
    var quickviewpanel : mint.Scroll;
    var quickviewoverlay : mint.Panel;

    function toggle_quickview() {

        var quickviewr : mint.render.luxe.Scroll = cast quickviewpanel.renderer;
        var quickviewor : mint.render.luxe.Panel = cast quickviewoverlay.renderer;

        if(quickview) { //hide

            if(Luxe.audio.exists('$playing_sound')) {
                var s = Luxe.audio.get('$playing_sound');
                    if(s != null && s.playing) s.stop();
            }

            //remove the children from the view
            for(c in quickviewpanel.container.children) {
                c.destroy();
            }

            quickviewor.visual.color.tween(0.05, {a:0});
            quickviewr.visual.color.tween(0.1, {a:0}).onComplete(function(){
                quickviewpanel.visible = false;
                quickviewoverlay.visible = false;
                quickview = false;
                canvas.modal = null;
                hoveredinfo = null;
                hoveredbutton = null;
                // canvas.find_focus();
            });

        } else { //show

            if(hoveredinfo != null) {
                quickview = true;
                var ext = haxe.io.Path.extension(hoveredinfo);
                switch(ext) {
                    case 'json','txt','csv','fnt':

                        quickviewpanel.x=Luxe.screen.w*0.15;
                        quickviewpanel.y=Luxe.screen.h*0.05;
                        quickviewpanel.w=Luxe.screen.w*0.7;
                        quickviewpanel.h=Luxe.screen.h*0.9;

                        //load the json string
                        var p = Luxe.resources.load_text(hoveredinfo);
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
                                lr.text.color.rgb(0x121212);

                        });

                    case 'png','jpg':

                        var get = Luxe.resources.load_texture(hoveredinfo);
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

                        Luxe.audio.stop('$playing_sound');

                        playing_sound = Luxe.utils.hash(hoveredinfo);

                        if(!Luxe.audio.exists('$playing_sound')) {
                            Luxe.audio.create(hoveredinfo, '$playing_sound', false);
                        }

                        Luxe.audio.on('$playing_sound', 'load', _onaudioload);
                        Luxe.audio.on('$playing_sound', 'end', _onaudioend);

                    case _: _log('quickview / unknown extension $ext');
                }

                quickviewpanel.visible = true;
                quickviewoverlay.visible = true;
                quickviewor.visual.color.tween(0.15, {a:0.9});
                quickviewr.visual.color.tween(0.3, {a:1});
                canvas.reset_focus(hoveredbutton);
                canvas.modal = quickviewpanel;
                // @:privateAccess canvas.find_focus(null);
            }

        } //show

    } //toggle_quickview

    function _onaudioload(_) { Luxe.audio.play('$playing_sound'); Luxe.audio.off('$playing_sound', 'load', _onaudioload); }
    function _onaudioend(_) { toggle_quickview(); Luxe.audio.off('$playing_sound', 'end', _onaudioend); }

    var playing_sound:UInt = 0;

    override function onkeyup( e:luxe.KeyEvent ) {

        if(e.keycode == Key.lctrl || e.keycode == Key.rctrl) ctrldown = false;
        if(e.keycode == Key.lalt || e.keycode == Key.ralt) altdown = false;
        if(e.keycode == Key.lmeta || e.keycode == Key.rmeta) metadown = false;
        if(e.keycode == Key.lshift || e.keycode == Key.rshift) shiftdown = false;

        if(e.keycode == Key.key_d && !focus) {
            debug = !debug;
        }

        if(e.keycode == Key.enter && focus) {
            defocus();
        }

        if(e.keycode == Key.space) {
            toggle_quickview();
        }

        if(e.keycode == Key.escape) {
            if(!focus) {
                Luxe.shutdown();
            } else {
               defocus();
            }
        }

    } //onkeyup

    var debug : Bool = false;
    override function update(dt:Float) {

        if(canvas!=null) canvas.update(dt);

        if(debug) {
            for(c in canvas.children) {
                drawc(c);
            }
        }


    } //update


    function drawc(control:Control) {

        if(!control.visible) return;

        Luxe.draw.rectangle({
            depth: 1000,
            x: control.x,
            y: control.y,
            w: control.w,
            h: control.h,
            color: new Color(1,0,0,0.5),
            immediate: true
        });

        for(c in control.children) {
            drawc(c);
        }

    } //drawc


} //Main

