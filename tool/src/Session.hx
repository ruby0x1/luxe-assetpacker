import Parceler.FileInfo;

typedef ParcelerSession = {
    flag_zip : Bool,
    path_base : String,
    paths : Array<String>,
    files : Array<FileInfo>
}

@:allow(Parceler)
class Session {

    static var session : ParcelerSession = null;
    static var path : String = null;

    static function init() {

        var found = Luxe.snow.io.string_load('previous_session');
        if(found != null) {
            Parceler._log('action / session init existing session\n' + found);
            read_session(found);
        } else {
            Parceler._log('action / session init new session');
            reset_session();
        }

    } //init

    static function save(force:Bool=false) {

        var save_path = path;

        if(save_path == null || force) {
            save_path = Luxe.core.app.io.module.dialog_save('select parceler session file to save', { extension:'parceler' });
        }

        if(save_path != null && save_path.length > 0) {
            Parceler._log('action / save parceler session\n$save_path');
            write_session(save_path);
        }

    } //save

    static function load() {

        var open_path = Luxe.core.app.io.module.dialog_open('select parceler session to open', [{ extension:'parceler' }]);
        if(open_path.length > 0) {
            Parceler._log('action / open parceler session\n$open_path');
            if(read_session(open_path)) {
                Luxe.snow.io.string_save('previous_session', open_path);
            }
        } else {
            Parceler._log('action / cancelled open parceler session');
        }

    } //load


    static function write_session(_path:String) {

        path = _path;
        sys.io.File.saveContent(_path, haxe.Json.stringify(session));

        trace('session save ' + _path);

    } //write_session


    static function read_session(_path:String) {

        var content = sys.io.File.getContent(_path);

        trace('session load ' + _path);

        if(content != null && content.length > 0) {

            try {
                session = cast haxe.Json.parse(content);
                path = _path;
                    //readd the files to ensure disk changes are caught
                for(p in session.paths) add_files(p);
            } catch(e:Dynamic) {
                Parceler._log('action / session failed to load\n$_path');
                reset_session();
                return false;
            }

        } //content valid

        return true;

    } //read_session

    static function add_path( _path:String ) {

        if(session.paths.indexOf(_path) == -1) {
            session.paths.push(_path);
            add_files(_path);
        }

    } //add_path

    static function has_file(_path:String) {
        for(f in session.files) if(f.full_path == _path) return true;
        return false;
    }

    static function add_files(_root:String) {

        var _list = [];

        get_file_list(_root, Parceler.extensions, true, _list);

        for(_path in _list) {
            if(has_file(_path)) continue;

            var _asset_path = StringTools.replace(_path, _root, '');
            var _display_path = haxe.io.Path.join([ session.path_base, _asset_path ]);
                _display_path = Parceler.normalize(_display_path);
            var path_info = { parcel_name:_display_path, full_path:_path, selected:false };

            session.files.push(path_info);

        } //each _path

    } //add_files

    static function reset_session() {

        Parceler._log('action / session reset');
        trace('session reset');

        path = null;

        session = {
            flag_zip: true,
            path_base: 'assets/',
            paths:[],
            files:[]
        }

    } //reset_session

//internal


    static function get_file_list( _path:String, _exts:Array<String>, _recursive:Bool=true, ?_into:Array<String> ) {

        if(_into == null) _into = [];

            var nodes = sys.FileSystem.readDirectory(_path);
            for(node in nodes) {
                node = haxe.io.Path.join([_path, node]);
                var is_dir = sys.FileSystem.exists(node) && sys.FileSystem.isDirectory(node);
                if(!is_dir) {

                    var ext = haxe.io.Path.extension(node);
                    if(_exts.indexOf(ext) != -1) {
                        if(_into.indexOf(node) == -1) {
                            _into.push(node);
                        }
                    }

                } else {
                    if(_recursive) _into = get_file_list(node, _exts, _into);
                }
            }

        return _into;

    } //get_file_list
} //Session
