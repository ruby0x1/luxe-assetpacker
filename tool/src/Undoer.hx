
import Parceler.Node;

@:enum abstract ActionType(Int) from Int to Int {
    var undo = 0;
    var redo = 1;
}

typedef UndoState = { node:Node, before:Bool, after:Bool };


@:allow(Parceler)
class Undoer {

    static var undo_stack:Array< Array<UndoState> > = [];
    static var redo_stack:Array< Array<UndoState> > = [];

    static function action( ?act:Array<UndoState>, ?type:ActionType, ?cb:Node->Bool->Bool->Void) {

        if(act != null) {

            undo_stack.push(act);

            if(undo_stack.length > 1000) {
                undo_stack.shift();
            }

            redo_stack = [];

        } else if(type != null) {

            switch(type) {

                case undo: {
                    trace('undo');
                    var lastact = undo_stack.pop();
                    if(lastact != null) {
                        if(cb != null) {
                            for(inst in lastact) {
                                cb(inst.node, inst.before, true);
                            }
                        }

                        redo_stack.push(lastact);
                        if(redo_stack.length > 1000) redo_stack.shift();
                    }
                } //undo

                case redo: {
                    trace('redo');
                    var lastundo = redo_stack.pop();
                    if(lastundo != null) {

                        if(cb != null) {
                            for(inst in lastundo) {
                                cb(inst.node, inst.after, true);
                            }
                        }

                        undo_stack.push(lastundo);
                        if(undo_stack.length > 1000) undo_stack.shift();
                    }
                } //redo

            } //switch type
        } //type != null

        trace('undos: ${undo_stack.length} / redos: ${redo_stack.length}');

    } //action

}