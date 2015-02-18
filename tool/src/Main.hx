
import luxe.Input;
import luxe.Color;

import mint.Types;
import mint.Control;
import mint.render.LuxeMintRender;
import mint.render.Convert;
import snow.io.typedarray.Uint8Array;

typedef AssetItem = { id:UInt, data:Uint8Array };

typedef AssetPack = {
    var id: String;
    var list: Array<String>;
    var items: Array<AssetItem>;
}

@:enum abstract ActionType(Int) from Int to Int {
    var undo = 0;
    var redo = 1;
}

typedef UndoState = { button:mint.Button, before:Bool, after:Bool };
typedef FileInfo = { parcel_name:String, full_path:String };

//total count per section
//teardown/reopen

class Main extends luxe.Game {

    public static var canvas : mint.Canvas;
    public static var render : mint.render.LuxeMintRender;

    public static var selectview : mint.List;
    public static var hoverinfo : mint.Label;
    public static var selectinfo : mint.Label;
    public static var selectlist : Array<FileInfo>;

    public static var logl : mint.Label;
    public static var pathr : mint.render.Label;

    override function ready() {

        app.app.assets.strict = false;

        render = new LuxeMintRender();

        canvas = new mint.Canvas({
            bounds: new Rect(0,0,Luxe.screen.w,Luxe.screen.h),
            renderer: render
        });

        create_right_menu();
        create_left_menu();
        create_select_view();
        create_quick_view();

    } //ready


    function create_quick_view() {

        var width = Luxe.screen.w * 0.7;
        var height = Luxe.screen.h * 0.9;

        quickviewpanel = new mint.ScrollArea({
            parent: canvas,
            bounds: new Rect(Luxe.screen.w * 0.15,Luxe.screen.h*0.05,width,height),
            visible: false
        });

        var quickviewr : mint.render.Scroll = cast render.renderers.get(quickviewpanel);
            quickviewr.visual.color.a = 0;
    }

    function create_left_menu() {
        var left_w = Luxe.screen.w / 4;
        var left_l = 16;

        new mint.Label({
            parent: canvas,
            name: 'open_folder',
            bounds: new Rect(left_l,16,left_w,22),
            text: 'open folder',
            align: TextAlign.left,
            point_size: 20,
            onclick: click_open_folder
        });

        new mint.Label({
            parent: canvas,
            name: 'label_select',
            bounds: new Rect(left_l,48,left_w,16),
            text: 'select all',
            align: TextAlign.left,
            point_size: 16,
            onclick: click_select_all
        });

        new mint.Label({
            parent: canvas,
            name: 'label_selectnone',
            bounds: new Rect(left_l,64,left_w,16),
            text: 'select none',
            align: TextAlign.left,
            point_size: 16,
            onclick: click_select_none
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

    function create_right_menu() {

        var right_w = Luxe.screen.w / 4;
        var right_l = Luxe.screen.w - right_w - 16;

        new mint.Label({
            parent: canvas,
            name: 'version',
            bounds: new Rect(right_l,16,right_w,16),
            text: 'simple asset packer 0.1.0',
            align: TextAlign.right,
            point_size: 16
        });

        new mint.Label({
            parent: canvas,
            name: 'label_path_d',
            bounds: new Rect(right_l,32,right_w,16),
            text: 'base assets path:',
            align: TextAlign.right,
            point_size: 16,
        });

        var _pathl = new mint.Label({
            parent: canvas,
            name: 'label_path',
            bounds: new Rect(right_l,64,right_w,16),
            text: 'assets/',
            align: TextAlign.right,
            point_size: 16,
            onclick: click_path
        });

        pathr = cast render.renderers.get(_pathl);

        logl = new mint.Label({
            parent: canvas,
            name: 'log',
            bounds: new Rect(right_l, 128, right_w, Luxe.screen.h - 128),
            text: 'log / initialized',
            align: TextAlign.right,
            point_size: 12
        });

        var _r:mint.render.Label = cast render.renderers.get(logl);
            _r.text.color.rgb(0x444444);

    }

    function compress_pack( pack:AssetPack ) : haxe.io.Bytes {

        var s = new haxe.Serializer();
            s.serialize( pack );

        var raw = s.toString();
        var rawbytes = haxe.io.Bytes.ofString(raw);
        var compbytes = haxe.io.Bytes.ofData(snow_lzma_encode(rawbytes.getData()));

        Sys.println('${pack.id}: compressed ${pack.items.length} items to ' + Luxe.utils.bytes_to_string(compbytes.length) + ' from ~' + Luxe.utils.bytes_to_string(rawbytes.length));

        return compbytes;

    } //compress_pack

    function uncompress_pack( bytes:haxe.io.Bytes ) : AssetPack {

        var ucompbytes = haxe.io.Bytes.ofData(snow_lzma_decode(bytes.getData()));
        var uraw = ucompbytes.toString();
        var u = new haxe.Unserializer(uraw);
        var pack : AssetPack = u.unserialize();

        Sys.println('${pack.id}: decompressed ${pack.items.length} items from ' + bytes.length + ' from ' + ucompbytes.length);

        return pack;

    } //uncompress_pack

    function build(_,_) {

        var list = [];
        var itemlist = [];

        for(l in selectlist) {
            list.push(l.parcel_name);
            var _id = Luxe.utils.hash(l.parcel_name);
            trace('\t storing item id ' + _id);
            var rawdata = Luxe.loadData(l.full_path);
            var filebytes : haxe.io.Bytes = rawdata.data;
            var filedata = new Uint8Array(filebytes);

            itemlist.push({
                id: _id,
                data: filedata
            });
        }

        var packed = compress_pack({
            id: 'assets.parcel',
            list : list,
            items : itemlist
        });

        var size = Luxe.utils.bytes_to_string(packed.length);
        _log('build / built pack from ${selectlist.length} items, parcel is $size');

        var save_path = Luxe.core.app.io.platform.dialog_save('select parcel file to save to', { extension:'parcel' });
        if(save_path.length > 0) {
            writebytes(save_path, packed, true);
        }


        // var unpacked = uncompress_pack(packed);

        //     for(item in unpacked.list) {
        //         trace('\t ${unpacked.id}: found ${item}');
        //     }

    }

    function writebytes(path:String, bytes:haxe.io.Bytes, binary:Bool=false) {
        var f = sys.io.File.write(path, binary);
            f.writeBytes(bytes, 0, bytes.length);
            f.flush();
            f.close();
    }

    function create_select_view() {

        var left_w = Luxe.screen.w / 4;

        selectview = new mint.List({
            parent: canvas,
            bounds: new Rect(left_w, 80, left_w*2, Luxe.screen.h - 96)
        });

        hoverinfo = new mint.Label({
            parent: canvas,
            text: '...',
            bounds: new Rect(left_w, 78-16, (left_w*2)-96-16, 16),
            point_size: 14,
        });

        selectinfo = new mint.Label({
            parent: canvas,
            text: 'open a folder to begin',
            bounds: new Rect(left_w, 78-32, (left_w*2)-96-16, 16),
            point_size: 14,
        });

        selectlist = [];
        new mint.Button({
            parent: canvas,
            text: 'build ...',
            point_size: 16,
            bounds: new Rect( selectview.right() - 96, 80-34, 96, 32),
            onclick: build
        });

    }

    public function _log( v:Dynamic ) {
        var t = logl.text;
        t = Std.string(v) +'\n'+ t;
        logl.text = t;
    }

    function click_open_folder(_,_) {

        var open_path = Luxe.core.app.io.platform.dialog_folder('select assets folder to show');
        if(open_path.length > 0) {
            _log('action / open dialog selected\n$open_path');
            show_select_list( open_path );
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
        var itemw = Math.floor(selectview.bounds.w/per_row) - 4;
        var rows = Math.ceil(itemc / per_row);
        var height = (rows * (itemw+4))+32+16;

        var window = new mint.Window({
            name:'$filter.selector',
            parent: selectview,
            title:'$title ($itemc items)',
            bounds: new Rect(0, 0, selectview.bounds.w+1, height ),
            closeable: false,
            moveable: false,
            focusable: false
        });

        var rootidx = 0;
        for(row in 0 ... rows) {
            for(idx in 0 ... per_row) {

                if(rootidx >= itemc) continue;

                var path = items[rootidx];
                var display_path = haxe.io.Path.join([pathr.text.text, StringTools.replace(path, open_path, '')]);
                var path_info = { parcel_name:display_path, full_path:path };

                var fname = haxe.io.Path.withoutDirectory(path);
                    fname = haxe.io.Path.withoutExtension(fname);

                var button = new mint.Button({
                    parent: window,
                    text: fname,
                    point_size: 10,
                    bounds: new Rect(4+(idx*(itemw+4)),32+(row*(itemw+4)), itemw, itemw)
                });

                var image = null;
                var selected = new mint.Image({
                    parent: button,
                    path: 'assets/selected.png',
                    visible: false,
                    bounds: new Rect(0,0, itemw, itemw),
                });

                trace('path: $path');

                if(filter == 'png' || filter == 'jpg') {
                    image = new mint.Image({
                        parent: button,
                        path: path,
                        visible:false,
                        bounds: new Rect(4,4, itemw-8, itemw-8)
                    });
                }

                button.mouseenter.listen(function(_,e){
                    if(!selected.visible) {
                        if(image != null) image.visible = true;
                    }
                    hoverinfo.text = display_path;
                    hoveredinfo = path;
                    hoveredbutton = button;
                });

                button.mouseleave.listen(function(_,_){
                    if(!selected.visible) if(image != null) image.visible = false;
                    hoverinfo.text = '';
                    hoveredinfo = null;
                    hoveredbutton = null;
                });

                button.mousedown.listen(function(_,_){
                    selectbutton(button);
                });

                selectors.push(button);
                selector_info.set(button, path_info);

                rootidx++;
            }
        }

        selectview.add_item(window);

    }

    var selectors : Array<mint.Button>;
    var selector_info : Map<mint.Button, FileInfo>;

    var open_path : String = '';
    var filelist : Array<String>;

    function show_select_list( path:String ) {

        open_path = path;

        var exts = ['json', 'csv', 'txt', 'png', 'jpg', 'wav'];
        filelist = get_file_list(path, exts, true);
        selectinfo.text = 'found ${filelist.length} assets matching $exts, select files and hit build';
        selectors = [];
        selector_info = new Map();

        _log('open folder / found ${filelist.length}');
        _log('open folder / when matching ' + exts);

        for(ext in exts) {
            var items = filelist.filter(function(_s) return ext == haxe.io.Path.extension(_s) );
            show_selector( '$ext files', ext, items );
        }

    }

    function click_path(_, _) {

        if(!focus) {
            focus = true;
            pathr.text.add( new TextEdit() );
            pathr.hover_color = pathr.normal_color = 0xe2f44d;
            pathr.text.color.rgb(pathr.hover_color);
        }

    }

    override function onmousemove(e) {
        if(canvas!=null) canvas.onmousemove( Convert.mouse_event(e) );
    }

    override function onmousewheel(e) {
        if(canvas!=null) canvas.onmousewheel( Convert.mouse_event(e) );
    }

    override function onmouseup(e) {
        if(canvas!=null) canvas.onmouseup( Convert.mouse_event(e) );
    }

    override function onmousedown(e) {
        if(canvas!=null) canvas.onmousedown( Convert.mouse_event(e) );
    }

    function defocus() {
        focus = false;
        pathr.text.remove('text_edit');
        pathr.hover_color = 0xf6007b;
        pathr.normal_color = 0xffffff;
        pathr.text.color.rgb(pathr.normal_color);
    }

    var ctrldown = false;
    var altdown = false;
    var metadown = false;
    var shiftdown = false;
    override function onkeydown( e:KeyEvent ) {

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
    var quickviewpanel : mint.ScrollArea;

    function toggle_quickview() {

        var quickviewr : mint.render.Scroll = cast render.renderers.get(quickviewpanel);
        if(quickview) { //hide

            //remove the children from the view
            for(c in quickviewpanel.children) {
                c.destroy();
            }

            quickviewr.visual.color.tween(0.1, {a:0}).onComplete(function(){
                quickviewpanel.visible = false;
                quickview = false;
                canvas.modal = null;
                hoveredinfo = null;
                hoveredbutton = null;
                canvas.find_focus();
            });

        } else { //show

            if(hoveredinfo != null) {
                quickview = true;
                var b = quickviewpanel.bounds;
                var ext = haxe.io.Path.extension(hoveredinfo);
                switch(ext) {
                    case 'json','txt','csv':

                        b = b.set(Luxe.screen.w*0.15, Luxe.screen.h*0.05,Luxe.screen.w*0.7,Luxe.screen.h*0.9);
                        quickviewpanel.bounds = b;

                        //load the json string
                        var txt = Luxe.loadText(hoveredinfo);
                        var dim = new luxe.Vector();
                        var disptext = txt.text.substr(0, 1024);
                        if(disptext.length == 1024) disptext += '\n\n ... preview ...';

                        Luxe.renderer.font.dimensions_of(disptext, 14, dim);
                        //create the label to display it
                        var l = new mint.Label({
                            parent: quickviewpanel,
                            bounds: new Rect(4,4,dim.x+8, dim.y+8),
                            point_size: 14,
                            align: TextAlign.left,
                            text:disptext,
                            mouse_enabled:false,
                        });

                        var lr : mint.render.Label = cast render.renderers.get(l);
                            lr.text.color.rgb(0x121212);


                    case 'png','jpg':

                        var t = Luxe.loadTexture(hoveredinfo);
                            t.filter = nearest;

                        t.onload = function(_){
                            var tw = t.width;
                            var th = t.height;
                            var bw = Math.min(tw, Luxe.screen.w*0.7 );
                            var bh = Math.min(th, Luxe.screen.h*0.9 );
                            var bx = Luxe.screen.mid.x - (bw/2);
                            var by = Luxe.screen.mid.y - (bh/2);
                            b = b.set(bx,by,bw,bh);
                            quickviewpanel.bounds = b;
                            var i = new mint.Image({
                                parent: quickviewpanel,
                                path: hoveredinfo,
                                bounds: new Rect(0,0,tw,th)
                            });
                        }


                    case _: _log('quickview / unknown extension $ext');
                }

                quickviewpanel.bounds = b;
                quickviewpanel.visible = true;
                quickviewr.visual.color.tween(0.3, {a:1});
                canvas.reset_focus(hoveredbutton);
                canvas.modal = quickviewpanel;
                canvas.find_focus();
            }

        } //show

    } //toggle_quickview

    override function onkeyup( e:KeyEvent ) {

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
            x: control.real_bounds.x,
            y: control.real_bounds.y,
            w: control.real_bounds.w,
            h: control.real_bounds.h,
            color: new Color(1,0,0,0.5),
            immediate: true
        });

        for(c in control.children) {
            drawc(c);
        }

    } //drawc


    static var snow_lzma_encode    = snow.utils.Libs.load("snow", "snow_lzma_encode", 1);
    static var snow_lzma_decode    = snow.utils.Libs.load("snow", "snow_lzma_decode", 1);

} //Main
