package enumstates;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.ExprTools;
import haxe.macro.Type;
import haxe.macro.TypeTools;

private typedef HookInfo = {
	var path:Array<String>; // z.B. ["Grounded"] or ["Grounded", "Running"]
	var fn:String;
	var pos:Position;
}

class EnumStatesMacro {
	public static macro function build():Array<Field> {
		var fields = Context.getBuildFields();
		var pos = Context.currentPos();
		var localClass = Context.getLocalClass().get();

		// 1. Typparameter <TEvent, TEffect> from Interface
		var eventCT:ComplexType = null;
		var effectCT:ComplexType = null;

		for (iface in localClass.interfaces) {
			var ifaceType = iface.t.get();
			if (ifaceType.name == "EnumStates" && ifaceType.pack.join(".") == "enumstates") {
				if (iface.params.length == 2) {
					eventCT = TypeTools.toComplexType(iface.params[0]);
					effectCT = TypeTools.toComplexType(iface.params[1]);
				}
				break;
			}
		}

		if (eventCT == null || effectCT == null) {
			Context.error("use EnumStates<TEvent, TEffect> with correct types.", pos);
		}

		var regions:Array<{name:String, type:ComplexType, pos:Position}> = [];
		var regionNames = new Map<String, Bool>();
		var updateMethods = new Map<String, Position>();

		var enterHooks = new Map<String, Array<HookInfo>>();
		var exitHooks = new Map<String, Array<HookInfo>>();
		var rawHooks:Array<{
			kind:String,
			region:String,
			path:Array<String>,
			fn:String,
			pos:Position
		}> = [];

		// 2. traverse fields, inline methods and optimize tupel-switches
		for (field in fields) {
			var isRegion = field.meta != null && Lambda.exists(field.meta, m -> m.name == ":region");
			if (isRegion) {
				switch (field.kind) {
					case FVar(t, _):
						if (t == null)
							Context.error('Region "${field.name}" needs explicite Enum-typ.', field.pos);
						if (regionNames.exists(field.name))
							Context.error('double region "${field.name}".', field.pos);
						regions.push({name: field.name, type: t, pos: field.pos});
						regionNames.set(field.name, true);
					default:
						Context.error("@:region has to use only on vars.", field.pos);
				}
			}

			switch (field.kind) {
				case FFun(fn):
					var isUpdate = StringTools.startsWith(field.name, "update_");
					var isEnter = StringTools.startsWith(field.name, "onEnter_");
					var isExit = StringTools.startsWith(field.name, "onExit_");

					if (isUpdate || isEnter || isExit) {
						if (field.access == null)
							field.access = [];
						if (field.access.indexOf(AInline) == -1)
							field.access.push(AInline);
					}

					if (isUpdate && fn.expr != null) {
						fn.expr = optimizeTupleSwitches(fn.expr);
						var regName = field.name.substr("update_".length);
						updateMethods.set(regName, field.pos);
					} else if (isEnter || isExit) {
						var parts = field.name.split("_");
						// supports onEnter_<region>_<State> AND onEnter_<region>_<Parent>_<Child> ...
						if (parts.length >= 3) {
							rawHooks.push({
								kind: parts[0],
								region: parts[1],
								path: parts.slice(2),
								fn: field.name,
								pos: field.pos
							});
						} else {
							Context.error('Mismatched hook-format "${field.name}". expects: onEnter_<region>_<Zustand>[_<SubZustand>].', field.pos);
						}
					}
				default:
			}
		}

		if (regions.length == 0) {
			Context.warning("Missing @:region vars.", pos);
			return fields;
		}

		// 3. Compile-Time-Validation & UML-Sorting (Parent vor Child)
		for (reg in regions) {
			if (!updateMethods.exists(reg.name)) {
				Context.error('missing "function update_${reg.name}(event:...)" for region "${reg.name}".', reg.pos);
			}
		}

		var seenHooks = new Map<String, Bool>();
		for (h in rawHooks) {
			if (!regionNames.exists(h.region)) {
				Context.error('Hook "${h.fn}" points to unknown region "${h.region}".', h.pos);
			}
			var hookKey = '${h.kind}_${h.region}_${h.path.join("_")}';
			if (seenHooks.exists(hookKey)) {
				Context.error('double lifecycle-hook for ${h.kind} in region "${h.region}", path "${h.path.join(".")}".', h.pos);
			}
			seenHooks.set(hookKey, true);

			var targetMap = (h.kind == "onEnter") ? enterHooks : exitHooks;
			if (!targetMap.exists(h.region))
				targetMap.set(h.region, []);
			targetMap.get(h.region).push({path: h.path, fn: h.fn, pos: h.pos});
		}

		// Sort: Exit = deepest Sub-States at first,  Enter = outer Parent-States at first
		for (hooks in exitHooks) {
			hooks.sort((a, b) -> b.path.length - a.path.length);
		}
		for (hooks in enterHooks) {
			hooks.sort((a, b) -> a.path.length - b.path.length);
		}

		// 4. generate Code-Blocks
		var savePrevExprs:Array<Expr> = [];
		var calcNextExprs:Array<Expr> = [];
		var applyNextExprs:Array<Expr> = [];
		var lifecycleExprs:Array<Expr> = [];
		var initialEntryExprs:Array<Expr> = [];

		var serializeFieldExprs:Array<ObjectField> = [];
		var deserializeExprs:Array<Expr> = [];

		for (reg in regions) {
			var rName = reg.name;
			var prevVar = '_prev_$rName';
			var nextVar = '_next_$rName';
			var updateFn = 'update_$rName';
			var resolvedRegType = Context.resolveType(reg.type, reg.pos);

			savePrevExprs.push({
				expr: EVars([{name: prevVar, type: reg.type, expr: macro this.$rName}]),
				pos: reg.pos
			});
			calcNextExprs.push({
				expr: EVars([{name: nextVar, type: reg.type, expr: macro this.$updateFn(event)}]),
				pos: reg.pos
			});
			applyNextExprs.push({
				expr: EBinop(OpAssign, macro this.$rName, {expr: EConst(CIdent(nextVar)), pos: reg.pos}),
				pos: reg.pos
			});

			var regionLifecycleExprs:Array<Expr> = [];
			var prevIdent:Expr = {expr: EConst(CIdent(prevVar)), pos: reg.pos};
			var nextIdent:Expr = {expr: EConst(CIdent(nextVar)), pos: reg.pos};

			if (exitHooks.exists(rName)) {
				for (hook in exitHooks.get(rName)) {
					var pattern = buildHierarchicalPattern(resolvedRegType, hook.path, hook.pos);
					var fnName = hook.fn;
					regionLifecycleExprs.push(macro {
						if ($prevIdent.match($pattern) && !$nextIdent.match($pattern)) {
							this.$fnName();
						}
					});
				}
			}

			if (enterHooks.exists(rName)) {
				for (hook in enterHooks.get(rName)) {
					var pattern = buildHierarchicalPattern(resolvedRegType, hook.path, hook.pos);
					var fnName = hook.fn;
					regionLifecycleExprs.push(macro {
						if (!$prevIdent.match($pattern) && $nextIdent.match($pattern)) {
							this.$fnName();
						}
					});
					initialEntryExprs.push(macro {
						if (this.$rName.match($pattern)) {
							this.$fnName();
						}
					});
				}
			}

			if (regionLifecycleExprs.length > 0) {
				lifecycleExprs.push(macro {
					if ($prevIdent != $nextIdent) {
						$b{regionLifecycleExprs};
					}
				});
			}

			// rekursive Serialization & Deserialisation (supports nested Sub-State-Enums)
			var serExpr = buildTypeSerializer(resolvedRegType, macro this.$rName, reg.pos);
			serializeFieldExprs.push({field: rName, expr: serExpr});

			var rawAccess = macro Reflect.field(snapshot, $v{rName});
			var deserExpr = buildTypeDeserializer(resolvedRegType, rawAccess, rName, reg.pos);
			deserializeExprs.push(macro {
				if (Reflect.hasField(snapshot, $v{rName})) {
					this.$rName = $deserExpr;
				}
			});
		}

		var snapshotObjExpr:Expr = {expr: EObjectDecl(serializeFieldExprs), pos: pos};

		// flat block without nested scopes für _processSingleEvent
		var processBodyExprs:Array<Expr> = [];
		processBodyExprs = processBodyExprs.concat(savePrevExprs);
		processBodyExprs = processBodyExprs.concat(calcNextExprs);
		processBodyExprs = processBodyExprs.concat(applyNextExprs);
		processBodyExprs = processBodyExprs.concat(lifecycleExprs);
		processBodyExprs.push(macro _flushEffects());
		var processBodyBlock:Expr = {expr: EBlock(processBodyExprs), pos: pos};

		// 5. inject class-methods
		var generatedClass = macro class {
			public var onEffect:$effectCT->Void;

			private var _eventQueue:Array<$eventCT> = [];
			private var _effectQueue:Array<$effectCT> = [];
			private var _isProcessing:Bool = false;

			public function new(?onEffect:$effectCT->Void) {
				this.onEffect = onEffect;
				_initInitialStates();
			}

			private final function _initInitialStates():Void {
				_isProcessing = true;
				$b{initialEntryExprs};
				_flushEffects();
				var idx = 0;
				while (idx < _eventQueue.length) {
					_processSingleEvent(_eventQueue[idx++]);
				}
				if (idx > 0)
					_eventQueue.resize(0);
				_isProcessing = false;
			}

			private inline final function emit(effect:$effectCT):Void {
				_effectQueue.push(effect);
			}

			public inline final function send(event:$eventCT):Void {
				if (_isProcessing) {
					_eventQueue.push(event);
					return;
				}
				_isProcessing = true;
				_processSingleEvent(event);
				var idx = 0;
				while (idx < _eventQueue.length) {
					_processSingleEvent(_eventQueue[idx++]);
				}
				if (idx > 0)
					_eventQueue.resize(0);
				_isProcessing = false;
			}

			private inline final function _processSingleEvent(event:$eventCT):Void $processBodyBlock;

			private inline final function _flushEffects():Void {
				if (_effectQueue.length == 0)
					return;
				if (onEffect != null) {
					var i = 0;
					while (i < _effectQueue.length) {
						onEffect(_effectQueue[i++]);
					}
				}
				_effectQueue.resize(0);
			}

			public final function toSnapshot():Dynamic {
				return $snapshotObjExpr;
			}

			public final function restoreSnapshot(snapshot:Dynamic, triggerEntryHooks:Bool = false):Void {
				if (snapshot == null)
					return;
				_eventQueue.resize(0);
				_effectQueue.resize(0);
				$b{deserializeExprs};
				if (triggerEntryHooks) {
					_initInitialStates();
				}
			}

			public inline final function toJson(pretty:Bool = false):String {
				return haxe.Json.stringify(toSnapshot(), null, pretty ? "  " : null);
			}

			public inline final function fromJson(json:String, triggerEntryHooks:Bool = false):Void {
				var parsed = haxe.Json.parse(json);
				restoreSnapshot(parsed, triggerEntryHooks);
			}
		}

		for (genField in generatedClass.fields) {
			fields.push(genField);
		}

		var timerKind = getTimerConstructorKind(eventCT, pos);
		if (timerKind == "Tick") {
			var tickClass = macro class {
				public var dt:Float = 0.0;
				public inline final function timerStep(dt:Float):Void {
					this.dt = dt;
					send(Tick);
				}
			};
			for (f in tickClass.fields) fields.push(f);
		}
		else if (timerKind == "TimerStep") {
			var timerClass = macro class {
				public inline final function timerStep(dt:Float):Void {
					send(TimerStep(dt));
				}
			};
			fields.push(timerClass.fields[0]);
		}

		// generated code as String (for runtime inspection)
		var printer = new haxe.macro.Printer("  ");
		var codeBuffer = new StringBuf();
		for (f in fields) {
			codeBuffer.add(printer.printField(f));
			codeBuffer.add("\n\n");
		}
		var generatedCodeStr = codeBuffer.toString();
		var debugClass = macro class {
			public function getGeneratedCode():String {
				return $v{generatedCodeStr};
			}
		};
		fields.push(debugClass.fields[0]);

		return fields;
	}

	// --- Pattern Matching: builds e.g. Grounded(Running(_)) for ["Grounded", "Running"] ---
	private static function buildHierarchicalPattern(type:Type, path:Array<String>, pos:Position):Expr {
		var ctorName = path[0];
		var remainingPath = path.slice(1);
		switch (Context.follow(type)) {
			case TEnum(_.get() => enumType, _):
				var ctor = enumType.constructs.get(ctorName);
				if (ctor == null) {
					Context.error('State "$ctorName" not exists in Enum "${enumType.name}".', pos);
				}
				switch (ctor.type) {
					case TFun(args,_):
						if (remainingPath.length == 0) {
							var wildcards = [for (_ in args) macro _];
							return {expr: ECall(macro $i{ctorName}, wildcards), pos: pos};
						}
						else {
							// search the sub-state: Enum-parameter whats contain the next state
							var matchedArgIdx = -1;
							var subPattern:Expr = null;
							for (i in 0...args.length) {
								switch (Context.follow(args[i].t)) {
									case TEnum(_.get() => subEnum, _) if (subEnum.constructs.exists(remainingPath[0])):
										if (matchedArgIdx != -1) {
											Context.error('Ambiguous sub-state "${remainingPath[0]}" in "$ctorName".', pos);
										}
										matchedArgIdx = i;
										subPattern = buildHierarchicalPattern(args[i].t, remainingPath, pos);
									default:
								}
							}
							if (matchedArgIdx == -1) {
								Context.error('Sub-state "${remainingPath[0]}" not exists in any Sub-Enum of "$ctorName".', pos);
							}
							var callArgs = [for (i in 0...args.length) i == matchedArgIdx ? subPattern : (macro _)];
							return {expr: ECall(macro $i{ctorName}, callArgs), pos: pos};
						}
					default:
						if (remainingPath.length > 0) {
							Context.error('State "$ctorName" have no params so can not have Sub-State "${remainingPath[0]}".', pos);
						}
						return macro $i{ctorName};
				}
			default:
				Context.error("Region- or sub-state-typ have to be an Enum.", pos);
				return macro null;
		}
	}

	// --- recursive serialization ( nested Enums at any depth) ---
	private static function buildTypeSerializer(type:Type, targetExpr:Expr, pos:Position):Expr {
		switch (Context.follow(type)) {
			case TEnum(_.get() => enumType, _):
				var cases:Array<Case> = [];
				for (name => ctor in enumType.constructs) {
					switch (ctor.type) {
						case TFun(args, _):
							var argIdents = [for (i in 0...args.length) macro $i{'_a$i'}];
							var pattern:Expr = {expr: ECall(macro $i{name}, argIdents), pos: pos};
							var arrayElems = [
								for (i in 0...args.length)
									buildTypeSerializer(args[i].t, macro $i{'_a$i'}, pos)
							];
							var argsArray:Expr = {expr: EArrayDecl(arrayElems), pos: pos};
							cases.push({
								values: [pattern],
								expr: macro {name: $v{name}, args: $argsArray}
							});
						default:
							cases.push({
								values: [macro $i{name}],
								expr: macro {name: $v{name}, args: []}
							});
					}
				}
				return {expr: ESwitch(targetExpr, cases, null), pos: pos};
			default:
				// atomic value like Float, Int, String, Bool etc.
				return macro($targetExpr : Dynamic);
		}
	}

	private static function buildTypeDeserializer(type:Type, dataExpr:Expr, contextName:String, pos:Position):Expr {
		switch (Context.follow(type)) {
			case TEnum(_.get() => enumType, _):
				var cases:Array<Case> = [];
				for (name => ctor in enumType.constructs) {
					switch (ctor.type) {
						case TFun(args, _):
							var callArgs = [
								for (i in 0...args.length)
									buildTypeDeserializer(args[i].t, macro _data.args[$v{i}], '$contextName.$name[$i]', pos)
							];
							var callExpr:Expr = {expr: ECall(macro $i{name}, callArgs), pos: pos};
							cases.push({
								values: [macro $v{name}],
								expr: callExpr
							});
						default:
							cases.push({
								values: [macro $v{name}],
								expr: macro $i{name}
							});
					}
				}
				var switchExpr:Expr = {
					expr: ESwitch(macro(_data.name : String), cases, macro throw 'Unknown state "' + _data.name + '" in "' + $v{contextName} + '"'),
					pos: pos
				};
				return macro {
					var _data:Dynamic = $dataExpr;
					$switchExpr;
				}
			default:
				return macro($dataExpr : Dynamic);
		}
	}

	// --- AST-optimizing: transforms switch [a, b, c] in nested switch-blocks ---
	private static function optimizeTupleSwitches(e:Expr):Expr {
		return switch (e.expr) {
			case ESwitch(target, cases, edef):
				var transformedCases = [
					for (c in cases)
						{
							values: c.values,
							guard: c.guard != null ? optimizeTupleSwitches(c.guard) : null,
							expr: c.expr != null ? optimizeTupleSwitches(c.expr) : null
						}
				];
				var transformedDef = edef != null ? optimizeTupleSwitches(edef) : null;
				switch (target.expr) {
					case EArrayDecl(subjects) if (subjects.length > 1):
						var canFlatten = true;
						for (c in transformedCases) {
							for (v in c.values) {
								switch (v.expr) {
									case EArrayDecl(pats) if (pats.length == subjects.length):
									default:
										canFlatten = false;
										break;
								}
							}
							if (!canFlatten) break;
						}
						if (canFlatten) buildNestedSwitch(subjects, transformedCases, transformedDef, e.pos);
						else {expr: ESwitch(target, transformedCases, transformedDef), pos: e.pos};
						
					default: {expr: ESwitch(target, transformedCases, transformedDef), pos: e.pos};
				}
			default:
				ExprTools.map(e, optimizeTupleSwitches);
		}
	}

	private static function getConstructorInfo(e:Expr):Null<{name:String, args:Array<Expr>}> {
		return switch (e.expr) {
			case EConst(CIdent("_")): null;
			case EConst(CIdent(name)): {name: name, args: []};
			case ECall({expr: EConst(CIdent(name))}, args): {name: name, args: args};
			default: null;
		}
	}

	private static function buildNestedSwitch(subjects:Array<Expr>, cases:Array<Case>, edef:Null<Expr>, pos:Position):Expr {
		if (subjects.length == 0) {
			for (c in cases) {
				if (c.guard == null) {
					return c.expr != null ? c.expr : macro {};
				}
				return {
					expr: EIf(c.guard, c.expr != null ? c.expr : macro {}, buildNestedSwitch(subjects, cases.slice(1), edef, pos)),
					pos: pos
				}
			}
			return edef != null ? edef : macro {};
		}

		var headSubject = subjects[0];
		var tailSubjects = subjects.slice(1);

		var orderedCtors:Array<String> = [];
		var ctorArity = new Map<String, Int>();
		var hasParamBindings = new Map<String, Bool>();
		var singlePatMap = new Map<String, Expr>();

		for (c in cases) {
			for (v in c.values) {
				var pats = switch (v.expr) {
					case EArrayDecl(p): p;
					default: [];
				}
				var headPat = pats[0];
				var info = getConstructorInfo(headPat);
				var key = info != null ? info.name : (isWildcardExpr(headPat) ? null : ExprTools.toString(headPat));

				if (key != null) {
					if (!ctorArity.exists(key)) {
						orderedCtors.push(key);
						ctorArity.set(key, info != null ? info.args.length : 0);
						singlePatMap.set(key, headPat);
						hasParamBindings.set(key, false);
					} else if (ExprTools.toString(headPat) != ExprTools.toString(singlePatMap.get(key))) {
						hasParamBindings.set(key, true);
					}
				}
			}
		}

		var subCases:Array<Case> = [];
		for (key in orderedCtors) {
			var arity = ctorArity.get(key);
			var expandArgs = hasParamBindings.get(key) && arity > 0;
			var matchingSubCases:Array<Case> = [];

			var argSubjects:Array<Expr> = expandArgs ? [for (i in 0...arity) macro $i{'_arg_${subjects.length}_$i'}] : [];
			var argBindPats:Array<Expr> = expandArgs ? [for (i in 0...arity) macro $i{'_arg_${subjects.length}_$i'}] : [];

			for (c in cases) {
				var matchedValues:Array<Expr> = [];
				for (v in c.values) {
					var pats = switch (v.expr) {
						case EArrayDecl(p): p;
						default: [];
					}
					var headPat = pats[0];
					var info = getConstructorInfo(headPat);
					var patKey = info != null ? info.name : (isWildcardExpr(headPat) ? null : ExprTools.toString(headPat));

					if (patKey == null || patKey == key) {
						var nextPats = 
							if (expandArgs) {
								var innerArgs = (info != null) ? info.args : [for (_ in 0...arity) macro _];
								innerArgs.concat(pats.slice(1));
							}
							else pats.slice(1);
						matchedValues.push({expr: EArrayDecl(nextPats), pos: v.pos});
					}
				}
				if (matchedValues.length > 0) {
					matchingSubCases.push({values: matchedValues, guard: c.guard, expr: c.expr});
				}
			}

			var outerPat:Expr = (expandArgs) ? {expr: ECall(macro $i{key}, argBindPats), pos: pos} : singlePatMap.get(key);
			var nextSubjects = expandArgs ? argSubjects.concat(tailSubjects) : tailSubjects;

			subCases.push({
				values: [outerPat],
				expr: buildNestedSwitch(nextSubjects, matchingSubCases, edef, pos)
			});
		}

		var wildcardSubCases:Array<Case> = [];
		for (c in cases) {
			var matchedValues:Array<Expr> = [];
			for (v in c.values) {
				var pats = switch (v.expr) {
					case EArrayDecl(p): p;
					default: [];
				}
				if (isWildcardExpr(pats[0])) {
					matchedValues.push({expr: EArrayDecl(pats.slice(1)), pos: v.pos});
				}
			}
			if (matchedValues.length > 0) {
				wildcardSubCases.push({values: matchedValues, guard: c.guard, expr: c.expr});
			}
		}

		var hasCatchAllCase = false;
		for (sc in subCases) {
			if (sc.values.length > 0 && isCatchAllPattern(sc.values[0])) {
				hasCatchAllCase = true;
				break;
			}
		}

		var defaultBranch = 
			if (hasCatchAllCase) null;
			else if (wildcardSubCases.length > 0) buildNestedSwitch(tailSubjects, wildcardSubCases, edef, pos);
			else edef;

		return {expr: ESwitch(headSubject, subCases, defaultBranch), pos: pos};
	}

	private static function isCatchAllPattern(e:Expr):Bool {
		return switch (e.expr) {
			case EConst(CIdent("_")): true;
			case EConst(CIdent(name)) if (name.length > 0 && name.charAt(0) == name.charAt(0).toLowerCase()): true;
			default: false;
		}
	}

	private static function stripPatternBindings(e:Expr):Expr {
		return switch (e.expr) {
			case ECall(fn, args):
				{expr: ECall(fn, [for (_ in args) macro _]), pos: e.pos};
			default: e;
		}
	}

	private static function isWildcardExpr(e:Expr):Bool {
		return switch (e.expr) {
			case EConst(CIdent("_")): true;
			default: false;
		}
	}
    
	private static function getTimerConstructorKind(eventCT:ComplexType, pos:Position):Null<String> {
		try {
			var resolved = Context.resolveType(eventCT, pos);
			switch (Context.follow(resolved)) {
				case TEnum(_.get() => enumType, _):
					// 1. Bevorzugt: parameterloses Tick (0 Heap-Allokationen!)
					var tickCtor = enumType.constructs.get("Tick");
					if (tickCtor != null) {
						switch (tickCtor.type) {
							case TEnum(_, _): return "Tick";
							default:
						}
					}
					// 2. Fallback: TimerStep(dt:Float)
					var stepCtor = enumType.constructs.get("TimerStep");
					if (stepCtor != null) {
						switch (stepCtor.type) {
							case TFun([{t: argType}], _):
								switch (Context.follow(argType)) {
									case TAbstract(_.get() => {name: "Float", pack: []}, _): return "TimerStep";
									default:
								}
							default:
						}
					}
					return null;
				default: return null;
			}
		} catch (e:Dynamic) return null;
	}

}
#end
