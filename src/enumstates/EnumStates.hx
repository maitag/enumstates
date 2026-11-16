package enumstates;

@:autoBuild(enumstates.EnumStatesMacro.build())
interface EnumStates<TEvent, TEffect> {
    public var onEffect:TEffect->Void;
    public function send(event:TEvent):Void;
    public function toSnapshot():Dynamic;
    public function restoreSnapshot(snapshot:Dynamic, triggerEntryHooks:Bool = false):Void;
    public function toJson(pretty:Bool = false):String;
    public function fromJson(json:String, triggerEntryHooks:Bool = false):Void;
}
