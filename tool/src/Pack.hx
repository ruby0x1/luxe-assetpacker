
import luxe.options.ResourceOptions;
import luxe.resource.Resource;
import luxe.Resources;
import snow.api.buffers.Uint8Array;
import luxe.resource.Resource;
import phoenix.Texture;
import phoenix.BitmapFont.BitmapFont;
import snow.system.assets.Asset;
import snow.types.Types.AudioFormatType;
import luxe.importers.bitmapfont.BitmapFontParser;
import luxe.Log.*;


typedef AssetPack = {
    var id: String;
    var items: Map<String, haxe.io.Bytes>;
}

class Pack {

    public var pack : AssetPack;

    public function new( _id:String, ?onload:Pack->Void, ?_do_preload:Bool=true ) {

        var get = Luxe.resources.load_bytes(_id);
            get.then(function(res:BytesResource) {

                pack = Packer.uncompress_pack(res.asset.bytes.toBytes());

                if(_do_preload) preload();
                if(onload != null) onload(this);

            });

    } //new

    public function preload(_silent:Bool=false) {

        inline function loadlog(v) if(!_silent) trace(v);

        var index = 0;
        var fonts = [];

        loadlog('adding to Luxe.resources:');
        for(_id in pack.items.keys()) {
            var ext = haxe.io.Path.extension(_id);
            switch(ext) {
                case 'png','jpg':
                    loadlog('\t $index image: $_id');
                    create_texture(_id);
                case 'json':
                    loadlog('\t $index json: $_id');
                    create_json(_id);
                case 'fnt':
                    loadlog('\t $index defer font: $_id');
                    fonts.push(_id);
                case 'txt','csv':
                    loadlog('\t $index text: $_id');
                    create_text(_id);
                // case 'glsl':
                //     loadlog('\t $index shader: $_id');
                //     create_shader(_id);
                case 'wav','ogg','pcm':
                    loadlog('\t $index sound: $_id');
                    create_sound(_id);
            }
            index++;
        }

        //now do fonts, as they have texture dependencies
        for(_id in fonts) {
            loadlog('\t font: $_id');
            create_font(_id);
        }

    } //preload

    public function create_font( _id:String ) {

        if(!pack.items.exists(_id)) {
            luxe.Log.log('font not found in the pack! $_id');
            return;
        }

             //fetch the bytes from the pack
        var _bytes : haxe.io.Bytes = pack.items.get(_id);
        var string : String = _bytes.toString();

        var info = BitmapFontParser.parse(string);
        var texture_path = haxe.io.Path.directory(_id);
        var pages = [];

        for(page in info.pages) {
            var _path = haxe.io.Path.join([ texture_path, page.file ]);
            var tex = Luxe.resources.texture(_path);
            assertnull(tex);
            pages.push(tex);
        }

        var opt : BitmapFontOptions = { id:_id, system:Luxe.resources };
            opt.font_data = string;
            opt.pages = pages;

        var fnt = new phoenix.BitmapFont(opt);
            fnt.state = loaded;

        Luxe.resources.add(fnt);

    } //create_font

    public function create_text( _id:String ) {

        if(!pack.items.exists(_id)) {
            luxe.Log.log('text not found in the pack! $_id');
            return;
        }

             //fetch the bytes from the pack
        var _bytes : haxe.io.Bytes = pack.items.get(_id);
        var string : String = _bytes.toString();

        var opt : TextResourceOptions = { id:_id, system:Luxe.resources };
            opt.asset = new AssetText(Luxe.snow.assets, _id, string);

        var txt = new TextResource(opt);
            txt.state = loaded;

        Luxe.resources.add(txt);

    }

    public function create_json( _id:String ) {
        if(!pack.items.exists(_id)) {
            luxe.Log.log('json not found in the pack! $_id');
            return;
        }

             //fetch the bytes from the pack
        var _bytes : haxe.io.Bytes = pack.items.get(_id);
        var string : String = _bytes.toString();
        var _json = haxe.Json.parse(string);

        var opt : JSONResourceOptions = { id:_id, system:Luxe.resources };
            opt.asset = new AssetJSON(Luxe.snow.assets, _id, _json);

        var json = new JSONResource(opt);
            json.state = loaded;

        Luxe.resources.add(json);

    }

    public function create_sound( _id:String ) {
        if(!pack.items.exists(_id)) {
            luxe.Log.log('sound not found in the pack! $_id');
            return;
        }

             //fetch the bytes from the pack
        var _bytes : haxe.io.Bytes = pack.items.get(_id);

        var name = haxe.io.Path.withoutDirectory(_id);
            name = haxe.io.Path.withoutExtension(name);
        var  ext = haxe.io.Path.extension(_id);

        luxe.Log.log('create sound from $_id as $name');
        var _format: AudioFormatType = AudioFormatType.unknown;
        switch(ext) {
            case 'ogg': _format = AudioFormatType.ogg;
            case 'wav': _format = AudioFormatType.wav;
            case _:
        }

        var _arr:Uint8Array = Uint8Array.fromBytes(_bytes);

        Luxe.audio.create_from_bytes(name, _arr, _format);

    }

    public function create_texture( _id:String ) {

        if(!pack.items.exists(_id)) {
            luxe.Log.log('texture not found in the pack! $_id');
            return;
        }

            //fetch the bytes from the pack
        var _bytes : haxe.io.Bytes = pack.items.get(_id);

            //create the texture ahead of time
        var tex = new Texture({ id:_id, system:Luxe.resources });
            tex.state = loading;

        Luxe.resources.add(tex);

        var _arr = Uint8Array.fromBytes(_bytes);
        var _load = Luxe.snow.assets.image_from_bytes(_id, _arr);

        _load.then(function(asset:AssetImage) {
            @:privateAccess tex.from_asset(asset);
            tex.state = loaded;
        });

    } //create_texture

    // public function create_shader( _id:String ) {

    //     if(!pack.items.exists(_id)) {
    //         luxe.Log.log('texture not found in the pack! $_id');
    //         return;
    //     }

    //         //fetch the bytes from the pack
    //     var _bytes : haxe.io.Bytes = pack.items.get(_id);

    //         //create the texture ahead of time
    //     var sh = new phoenix.Shader({ id:_id, system:Luxe.resources });
    //         sh.state = loading;

    //     Luxe.resources.add(sh);

    //     var _bytes : haxe.io.Bytes = pack.items.get(_id);
    //     var string : String = _bytes.toString();

    //     sh.from_string(Luxe.renderer.shaders.plain.source.vert, string);
    //     sh.state = loaded;

    // } //create_shader


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

        trace('${pack.id}: packed ${Lambda.count(pack.items)} items / before:$presize_str / after:$postsize_str');

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

        trace('${pack.id}: unpacked ${Lambda.count(pack.items)} items / before:$presize_str / after:$postsize_str');

        return pack;

    } //uncompress_pack

} //Packer

