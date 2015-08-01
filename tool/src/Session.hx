import Parceler.FileInfo;

typedef ParcelerSession = {
    flag_zip : Bool,
    path_base : String,
    paths : Array<FileInfo>
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

    } //write_session


    static function read_session(_path:String) {

        var content = sys.io.File.getContent(_path);

        if(content != null && content.length > 0) {

            try {
                session = cast haxe.Json.parse(content);
                path = _path;
            } catch(e:Dynamic) {
                Parceler._log('action / session failed to load\n$_path');
                reset_session();
                return false;
            }

        } //content valid

        return true;

    } //read_session

    static function reset_session() {

        Parceler._log('action / session reset');

        path = null;

        session = {
            flag_zip: true,
            path_base: 'assets/',
            paths:[]
        }

    } //reset_session

} //Session
