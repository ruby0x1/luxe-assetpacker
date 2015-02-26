
#if newtypedarrays import snow.io.typedarray.Uint8Array; #end
#if !newtypedarrays import snow.utils.ByteArray; #end
import luxe.resource.Resource.JSONResource;
import luxe.resource.Resource.TextResource;
import phoenix.Texture;
import phoenix.BitmapFont.BitmapFont;



typedef AssetPack = {
    var id: String;
    #if newtypedarrays var items: Map<String, Uint8Array>; #end
    #if !newtypedarrays var items: Map<String, haxe.io.Bytes>; #end
}

class Pack {

    public var pack : AssetPack;

    public function new( load_from_file_id:String, ?onload:Pack->Void, ?_do_preload:Bool=true ) {

        Luxe.loadData(load_from_file_id, function(d){

            #if newtypedarrays
                pack = Packer.uncompress_pack(d.data.buffer);
            #else
                pack = Packer.uncompress_pack(d.data.getByteBuffer());
            #end

            if(_do_preload) preload();
            if(onload != null) onload(this);

        }); //loadData

    } //new

    public function preload(_silent:Bool=false) {

        inline function loadlog(v) if(!_silent) trace(v);

        loadlog('adding to Luxe.resources:');
        for(_id in pack.items.keys()) {
            var ext = haxe.io.Path.extension(_id);
            switch(ext) {
                case 'png','jpg':
                    loadlog('\t image: $_id');
                    create_texture(_id);
                case 'json':
                    loadlog('\t json: $_id');
                    var r = create_json(_id);
                    // loadlog(r.json);
                case 'txt','csv':
                    loadlog('\t text: $_id');
                    var r = create_text(_id);
                    // loadlog(r.text);
                case 'wav','ogg','pcm':
                    loadlog('\t sound: $_id');
                    create_sound(_id);
            }
        }

    } //preload

    public function create_text( _id:String ) : TextResource {

        if(!pack.items.exists(_id)) {
            luxe.Log.log('text not found in the pack! $_id');
            return null;
        }

             //fetch the bytes from the pack
        #if newtypedarrays
        var _bytes : Uint8Array = pack.items.get(_id);
        var string : String = _bytes.buffer.toString();
        #else
        var _bytes = ByteArray.fromBytes(pack.items.get(_id));
        var string : String = _bytes.toString();
        #end

        var res = new TextResource( _id, string, Luxe.resources );
        Luxe.resources.cache(res);

        return res;
    }

    public function create_json( _id:String ) : JSONResource {
        if(!pack.items.exists(_id)) {
            luxe.Log.log('json not found in the pack! $_id');
            return null;
        }

        var t = create_text(_id);
        var json = haxe.Json.parse(t.text);

        var res = new JSONResource( _id, json, Luxe.resources );
        Luxe.resources.cache(res);

        return res;
    }

    public function create_sound( _id:String ) : luxe.Sound {
        if(!pack.items.exists(_id)) {
            luxe.Log.log('sound not found in the pack! $_id');
            return null;
        }

             //fetch the bytes from the pack
        #if newtypedarrays
        var _bytes : Uint8Array = pack.items.get(_id);
        #else
        var _bytes = ByteArray.fromBytes(pack.items.get(_id));
        #end

        var name = haxe.io.Path.withoutDirectory(_id);
            name = haxe.io.Path.withoutExtension(name);

        luxe.Log.log('create sound from $_id as $name');
        var sound = Luxe.audio.create_from_bytes(_id, name, _bytes);

        return sound;
    }

    public function create_texture( _id:String ) : Texture {

        if(!pack.items.exists(_id)) {
            luxe.Log.log('texture not found in the pack! $_id');
            return null;
        }

            //fetch the bytes from the pack
        #if newtypedarrays
        var _bytes : Uint8Array = pack.items.get(_id);
        #else
        var _bytes = ByteArray.fromBytes(pack.items.get(_id));
        #end

            //:todo:which resources
        var resources = Luxe.resources;

        #if newtypedarrays
        var texture = Texture.load_from_bytes(_id, _bytes, true);
        #else
        var texture = Texture.load_from_bytearray(_id, _bytes, true);
        #end

        resources.cache(texture);

        return texture;

    } //loadTexture


} //Pack


class Packer {

    public static var use_lzma = true;
    public static var use_zip = false;

    public static function compress_pack( pack:AssetPack ) : haxe.io.Bytes {

        var s = new haxe.Serializer();
            s.serialize( pack );

        var raw = s.toString();
        var finalbytes = haxe.io.Bytes.ofString(raw);
        var presize = finalbytes.length;

        if(use_lzma) {

            var packdata = finalbytes.getData();
                packdata = snow_lzma_encode(packdata);

            finalbytes = haxe.io.Bytes.ofData(packdata);

        }

        if(use_zip) {

            finalbytes = haxe.zip.Compress.run(finalbytes, 9);

        }

        var postsize = finalbytes.length;

        var presize_str = Luxe.utils.bytes_to_string(presize);
        var postsize_str = Luxe.utils.bytes_to_string(postsize);

        Sys.println('${pack.id}: packed ${Lambda.count(pack.items)} items / before:$presize_str / after:$postsize_str');

        return finalbytes;

    } //compress_pack

    public static function uncompress_pack( bytes:haxe.io.Bytes ) : AssetPack {

        var inputbytes = bytes;
        var presize = bytes.length;

        if(use_zip) {

            inputbytes = haxe.zip.Uncompress.run(inputbytes);

        }

        if(use_lzma) {

            var inputdata = inputbytes.getData();
                inputdata = snow_lzma_decode(inputdata);

            inputbytes = haxe.io.Bytes.ofData(inputdata);

        }


        var uraw = inputbytes.toString();
        var u = new haxe.Unserializer( uraw );
        var pack : AssetPack = u.unserialize();

        var postsize = inputbytes.length;

        var presize_str = Luxe.utils.bytes_to_string(presize);
        var postsize_str = Luxe.utils.bytes_to_string(postsize);

        Sys.println('${pack.id}: unpacked ${Lambda.count(pack.items)} items / before:$presize_str / after:$postsize_str');

        return pack;

    } //uncompress_pack

    static var snow_lzma_encode    = snow.utils.Libs.load("snow", "snow_lzma_encode", 1);
    static var snow_lzma_decode    = snow.utils.Libs.load("snow", "snow_lzma_decode", 1);

} //Packer

