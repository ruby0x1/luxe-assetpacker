
import haxe.io.Path;
import luxe.options.ResourceOptions;
import luxe.resource.Resource;
import luxe.Resources;
import snow.api.buffers.Uint8Array;
import luxe.resource.Resource;
import luxe.Parcel;
import phoenix.Texture;
import phoenix.BitmapFont.BitmapFont;
import snow.api.Promise;
import snow.system.assets.Asset;
import snow.types.Types.AudioFormatType;
import luxe.importers.bitmapfont.BitmapFontParser;
import luxe.Log.*;

typedef AssetItem = {
    var id: String;
    var bytes:haxe.io.Bytes;
}

typedef AssetPack = {
    var id:         String;
    var bytes:      Map<String, AssetItem>;
    var texts:      Map<String, AssetItem>;
    var jsons:      Map<String, AssetItem>;
    var textures:   Map<String, AssetItem>;
    var shaders:    Map<String, AssetItem>;
    var fonts:      Map<String, AssetItem>;
    var sounds:     Map<String, AssetItem>;
}

@:allow(Packer)
class Pack {

    public var id : String;
    public var pack : AssetPack;

    var silent:Bool;

    public function new( _id:String, _silent:Bool=false ) {
        id = _id;
        silent = _silent;
    } //new

    public function preload() : Promise {

        return new Promise(function(resolve, reject) {
            var get = Luxe.resources.load_bytes(id);
            get.then(function(res:BytesResource) {

                pack = Packer.uncompress_pack(res.asset.bytes.toBytes());

                doload().then(function(_){
                    resolve(pack);
                }).error(reject);

            }).error(reject);//then
        }); //promise

    } //preload

    static function count(_pack:AssetPack) {
        return
            Lambda.count(_pack.bytes) +
            Lambda.count(_pack.texts) +
            Lambda.count(_pack.jsons) +
            Lambda.count(_pack.textures) +
            Lambda.count(_pack.sounds) +
            Lambda.count(_pack.fonts) +
            Lambda.count(_pack.shaders);
    }

    function _log(v) if(!silent) trace(v);

    function doload() {

        return new Promise(function(resolve, reject){

            _log('queuing packed parcel: ' + pack.id);

                //first load the up front meta
            preprocess_sound_meta(pack.sounds);
            preprocess_texture_meta(pack.textures);

                //order matters, i.e fonts depend on textures
                //so the ones that don't have promises are first
            load(pack.bytes, create_bytes);
            load(pack.texts, create_text);
            load(pack.jsons, create_json);
            load(pack.sounds, create_sound);
            load(pack.shaders, create_shader);

                //then we load the textures, and then the rest
            load(pack.textures, create_texture).then(function(){

                load(pack.fonts, create_font);

                //one all item types are loaded, process the meta information

                process_shader_meta(pack.shaders);

                resolve();

            }).error(reject);

        }); //promise

    } //preload

    function preprocess_texture_meta(list:Map<String,AssetItem>) {}

    var meta_sound:Map<String, SoundInfo>;
    function preprocess_sound_meta(list:Map<String,AssetItem>) {

        meta_sound = new Map();
        var infos:Array<SoundInfo> = meta_content(pack.sounds, 'sound');
        for(info in infos) {
            meta_sound.set(info.id, info);
        }

    }

    function process_shader_meta(list:Map<String,AssetItem>) {

        if(!list.exists(meta_id('shader'))) {
            _log('     shaders: no meta information, no shaders will be created if any were packed');
            return;
        }

        var infos:Array<ShaderInfo> = meta_content(list, 'shader');

        _log('process_shader_meta: ' + infos.length);

        for(info in infos) {

            var shader = new phoenix.Shader({
                id:info.id,
                system:Luxe.resources,
                vert_id:info.vert_id,
                frag_id:info.frag_id
            });

            var vertsrc = switch(info.vert_id) {
                case 'default': Luxe.renderer.shaders.plain.source.vert;
                case _: Luxe.resources.text(info.vert_id).asset.text;
            }

            var fragsrc = switch(info.frag_id) {
                case 'default':  Luxe.renderer.shaders.plain.source.frag;
                case 'textured': Luxe.renderer.shaders.textured.source.frag;
                case _: Luxe.resources.text(info.frag_id).asset.text;
            }

            if(shader.from_string(vertsrc, fragsrc)) {
                Luxe.resources.add(shader);
                _log('      created shader ' + info.id + ' / ' + info.vert_id + ' / ' + info.frag_id);
            } else {
                _log('      failed to load shader ' + info.id);
            }

        } //each meta info

    } //process_shader_meta

    function load(map:Map<String,AssetItem>, callback:String->AssetItem->haxe.io.Bytes->Promise) {

        var _list:Array<Promise> = [];

        for(_id in map.keys()) {
            _log('   load $_id');
            var _item = map.get(_id);
            _list.push(callback(_id, _item, _item.bytes));
        } //load_list

        if(_list.length == 0) {
            return Promise.resolve();
        } else {
            return Promise.all(_list);
        }

    } //load

    function create_font( _id:String, _item:AssetItem, _bytes:haxe.io.Bytes ) {

        var string : String = _bytes.toString();

        var info = BitmapFontParser.parse(string);
        var texture_path = haxe.io.Path.directory(_id);
        var pages = [];

        for(page in info.pages) {
            var _path = haxe.io.Path.join([ texture_path, page.file ]);
            _log('      looking for font texture: $_path');
            var tex = Luxe.resources.texture(_path);
            assertnull(tex, 'font texture not found');
            pages.push(tex);
        }

        var opt : BitmapFontOptions = { id:_id, system:Luxe.resources };
            opt.font_data = string;
            opt.pages = pages;

        var fnt = new phoenix.BitmapFont(opt);
            fnt.state = loaded;

        Luxe.resources.add(fnt);

        _log('     created font $_id');

        return Promise.resolve();

    } //create_font

    function create_bytes( _id:String, _item:AssetItem, _bytes:haxe.io.Bytes ) {

        var opt : BytesResourceOptions = { id:_id, system:Luxe.resources };
            opt.asset = new AssetBytes(Luxe.snow.assets, _id, Uint8Array.fromBytes(_bytes));

        var res = new BytesResource(opt);
            res.state = loaded;

        Luxe.resources.add(res);

        _log('     created bytes $_id');

        return Promise.resolve();

    } //create_bytes

    function create_text( _id:String, _item:AssetItem, _bytes:haxe.io.Bytes ) {

        var string : String = _bytes.toString();

        var opt : TextResourceOptions = { id:_id, system:Luxe.resources };
            opt.asset = new AssetText(Luxe.snow.assets, _id, string);

        var txt = new TextResource(opt);
            txt.state = loaded;

        Luxe.resources.add(txt);

        _log('     created text $_id');

        return Promise.resolve();

    } //create_text

    function create_json( _id:String, _item:AssetItem, _bytes:haxe.io.Bytes ) {

        var string : String = _bytes.toString();
        var _json = haxe.Json.parse(string);

        var opt : JSONResourceOptions = { id:_id, system:Luxe.resources };
            opt.asset = new AssetJSON(Luxe.snow.assets, _id, _json);

        var json = new JSONResource(opt);
            json.state = loaded;

        Luxe.resources.add(json);

        _log('     created json $_id');

        return Promise.resolve();

    } //create_json

    function create_sound( _id:String, _item:AssetItem, _bytes:haxe.io.Bytes ) {

        if(is_meta('sound',_id)) {
            _log('   -- skip sound meta ' + _id);
            return Promise.resolve();
        }

        var meta = meta_sound.get(_id);
        var name = Path.withoutExtension(Path.withoutDirectory(_id));
        var  ext = haxe.io.Path.extension(_id);

        if(meta != null) {
            name = meta.name;
        }

        luxe.Log.log('create sound from $_id as $name');

        var _format: AudioFormatType = AudioFormatType.unknown;
        switch(ext) {
            case 'ogg': _format = AudioFormatType.ogg;
            case 'wav': _format = AudioFormatType.wav;
            case _:
        }

        var _arr:Uint8Array = Uint8Array.fromBytes(_bytes);

        Luxe.audio.create_from_bytes(name, _arr, _format);

        _log('     created sound $_id');

        return Promise.resolve();

    } //create_sound

    function create_texture( _id:String, _item:AssetItem, _bytes:haxe.io.Bytes ) {

        return new Promise(function(resolve, reject) {
            //create the texture ahead of time
            var tex = new Texture({ id:_id, system:Luxe.resources });
                tex.state = loading;

            Luxe.resources.add(tex);

            var _arr = Uint8Array.fromBytes(_bytes);
            var _load = Luxe.snow.assets.image_from_bytes(_id, _arr);

            _load.then(function(asset:AssetImage) {
                @:privateAccess tex.from_asset(asset);
                tex.state = loaded;
                _log('     created texture $_id');
                resolve();
            }).error(reject);

        }); //promise

    } //create_texture

    function create_shader(_id:String, _item:AssetItem, _bytes:haxe.io.Bytes) {

        if(is_meta('shader',_id)) {
            _log('   -- skip shader meta ' + _id);
            return Promise.resolve();
        }

        return create_text(_id , _item, _bytes);

    } //create_shader

    function is_meta(_type:String, _id:String) {
        return _id.indexOf(meta_id(_type)) != -1;
    }

    function meta_id(_type:String) {
        if(_type == 'bytes') _type = 'byte';
        return 'assets/${_type}s.parcel-${_type}s-meta';
    }

    function meta_content<T>(list:Map<String,AssetItem>, _type:String) : T {
        var _id = meta_id(_type);
        var _item = list.get(_id);
        if(_item == null) return cast [];
        return cast haxe.Json.parse(_item.bytes.toString());
    }


} //Pack


class Packer {

    public static var use_zip = true;

    public static function compress_pack( pack:AssetPack ) : haxe.io.Bytes {

        var s = new haxe.Serializer();
            s.serialize( pack );

        var raw = s.toString();
        var finalbytes = haxe.io.Bytes.ofString(raw);
        var presize = finalbytes.length;

        if(use_zip) {

            finalbytes = haxe.zip.Compress.run(finalbytes, 9);

        }

        var postsize = finalbytes.length;

        var presize_str = Luxe.utils.bytes_to_string(presize);
        var postsize_str = Luxe.utils.bytes_to_string(postsize);

        trace('${pack.id}: packed ${Pack.count(pack)} items / before:$presize_str / after:$postsize_str');

        return finalbytes;

    } //compress_pack

    public static function uncompress_pack( bytes:haxe.io.Bytes ) : AssetPack {

        var inputbytes = bytes;
        var presize = bytes.length;

        if(use_zip) {

            inputbytes = haxe.zip.Uncompress.run(inputbytes);

        }

        var uraw = inputbytes.toString();
        var u = new haxe.Unserializer( uraw );
        var pack : AssetPack = u.unserialize();

        var postsize = inputbytes.length;

        var presize_str = Luxe.utils.bytes_to_string(presize);
        var postsize_str = Luxe.utils.bytes_to_string(postsize);

        trace('${pack.id}: unpacked ${Pack.count(pack)} items / before:$presize_str / after:$postsize_str');

        return pack;

    } //uncompress_pack

} //Packer

