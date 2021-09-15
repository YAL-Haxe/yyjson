package yy;
import yy.YyJsonMeta;
import yy.YyResourceType;

/**
	An implementation of JSON printer in Haxe.

	This class is used by `haxe.Json` when native JSON implementation
	is not available.

	@see https://haxe.org/manual/std-Json-encoding.html
**/
class YyJsonPrinter {
	/**
		Encodes `o`'s value and returns the resulting JSON string.

		If `replacer` is given and is not null, it is used to retrieve
		actual object to be encoded. The `replacer` function takes two parameters,
		the key and the value being encoded. Initial key value is an empty string.

		If `space` is given and is not null, the result will be pretty-printed.
		Successive levels will be indented by this string.
	**/
	static public function print(o:Dynamic, ?replacer:(key:Dynamic, value:Dynamic) -> Dynamic, ?space:String):String {
		var printer = new YyJsonPrinter(replacer, space);
		printer.write("", o);
		return printer.buf.toString();
	}

	var buf:#if flash flash.utils.ByteArray #else StringBuf #end;
	var replacer:(key:Dynamic, value:Dynamic) -> Dynamic;
	var indent:String;
	/** indentation depth */
	var nind:Int;

	function new(replacer:(key:Dynamic, value:Dynamic) -> Dynamic, space:String) {
		this.replacer = replacer;
		this.indent = "  ";
		//this.pretty = space != null;
		this.nind = 0;

		#if flash
		buf = new flash.utils.ByteArray();
		buf.endian = flash.utils.Endian.BIG_ENDIAN;
		buf.position = 0;
		#else
		buf = new StringBuf();
		#end
	}

	inline function ipad(pretty:Bool):Void {
		if (pretty) add(StringTools.lpad('', indent, nind * indent.length));
	}

	inline function newl(pretty:Bool):Void {
		if (pretty) addChar('\n'.code);
	}

	function write(k:Dynamic, v:Dynamic, ?resourceType:YyResourceType) {
		if (replacer != null) v = replacer(k, v);
		//add('/*$resourceType*/');
		switch (Type.typeof(v)) {
			case TUnknown:
				add('"???"');
			case TObject:
				objString(v, resourceType);
			case TInt:
				add(#if (jvm || hl) Std.string(v) #else v #end);
				if (resourceType == "Float") add(".0");
			case TFloat:
				if (Math.isFinite(v)) {
					var s = Std.string(v);
					if (resourceType == "Float" && s.indexOf(".") < 0) s += ".0";
					add(s);
				} else add('null');
			case TFunction:
				add('"<fun>"');
			case TClass(c):
				if (c == String) {
					quote(v);
				}
				else if (c == Array) {
					var v:Array<Dynamic> = v;
					if (resourceType != null && StringTools.endsWith(resourceType, "[]")) {
						resourceType = resourceType.substring(0, resourceType.length - 2);
					} else resourceType = null;
					addChar('['.code);

					var len = v.length;
					var last = len - 1;
					nind++;
					for (i in 0 ... len) {
						if (i == 0) nind++;
						newl(true);
						ipad(true);
						write(i, v[i], resourceType);
						addChar(','.code);
						if (i == last) {
							nind--;
							newl(true);
							ipad(true);
						}
					}
					nind--;
					addChar(']'.code);
				}
				else if (c == haxe.ds.StringMap) {
					var v:haxe.ds.StringMap<Dynamic> = v;
					var o = {};
					for (k in v.keys())
						Reflect.setField(o, k, v.get(k));
					objString(o, resourceType);
				}
				else if (c == Date) {
					var v:Date = v;
					quote(v.toString());
				}
				else classString(v, resourceType);
			case TEnum(_):
				var i:Dynamic = Type.enumIndex(v);
				add(i);
			case TBool:
				add(#if (php || jvm || hl) (v ? 'true' : 'false') #else v #end);
			case TNull:
				add('null');
		}
	}

	extern inline function addChar(c:Int) {
		#if flash
		buf.writeByte(c);
		#else
		buf.addChar(c);
		#end
	}

	extern inline function add(v:String) {
		#if flash
		// argument is not always a string but will be automatically casted
		buf.writeUTFBytes(v);
		#else
		buf.add(v);
		#end
	}

	function classString(v:Dynamic, resourceType:YyResourceType) {
		fieldsString(v, Type.getInstanceFields(Type.getClass(v)), resourceType);
	}

	inline function objString(v:Dynamic, resourceType:YyResourceType) {
		fieldsString(v, Reflect.fields(v), resourceType);
	}

	function fieldsString(v:Dynamic, fields:Array<String>, resourceType:YyResourceType) {
		if (resourceType == null) resourceType = Reflect.field(v, "resourceType");
		var fieldOrder:Array<String>, fieldType:Map<String, YyResourceType>;
		if (resourceType != null) {
			fieldOrder = YyJsonMeta.fieldOrder[resourceType];
			if (fieldOrder == null) fieldOrder = YyJsonMeta.fieldOrder[""];
			fieldType = YyJsonMeta.fieldType[resourceType];
		} else {
			switch (fields) {
				case ["name", "path"], ["path", "name"]: fieldOrder = ["name", "path"];
				default: fieldOrder = [];
			}
			fieldType = null;
		}
		fields.sort(function(a, b) {
			var ia = fieldOrder.indexOf(a);
			var ib = fieldOrder.indexOf(b);
			if (ia >= 0) return ib >= 0 ? ia - ib : 1;
			return ib >= 0 ? -1 : (a > b ? 1 : -1);
		});
		addChar('{'.code);
		//add('/*$fieldOrder*/');
		var pretty = nind < 2;
		var len = fields.length;
		var last = len - 1;
		var first = true;
		for (i in 0...len) {
			var f = fields[i];
			var value = Reflect.field(v, f);
			if (Reflect.isFunction(value))
				continue;
			if (first) {
				nind++;
				first = false;
			}
			newl(pretty);
			ipad(pretty);
			quote(f);
			addChar(':'.code);
			if (pretty) addChar(' '.code);
			write(f, value, fieldType != null ? fieldType[f] : null);
			addChar(','.code);
			if (i == last) {
				nind--;
				newl(pretty);
				ipad(pretty);
			}
		}
		addChar('}'.code);
	}

	function quote(s:String) {
		#if neko
		if (s.length != neko.Utf8.length(s)) {
			quoteUtf8(s);
			return;
		}
		#end
		addChar('"'.code);
		var i = 0;
		var length = s.length;
		#if hl
		var prev = -1;
		#end
		while (i < length) {
			var c = StringTools.unsafeCodeAt(s, i++);
			switch (c) {
				case '"'.code:
					add('\\"');
				case '\\'.code:
					add('\\\\');
				case '\n'.code:
					add('\\n');
				case '\r'.code:
					add('\\r');
				case '\t'.code:
					add('\\t');
				case 8:
					add('\\b');
				case 12:
					add('\\f');
				default:
					#if flash
					if (c >= 128)
						add(String.fromCharCode(c))
					else
						addChar(c);
					#elseif hl
					if (prev >= 0) {
						if (c >= 0xD800 && c <= 0xDFFF) {
							addChar((((prev - 0xD800) << 10) | (c - 0xDC00)) + 0x10000);
							prev = -1;
						} else {
							addChar("□".code);
							prev = c;
						}
					} else {
						if (c >= 0xD800 && c <= 0xDFFF)
							prev = c;
						else
							addChar(c);
					}
					#else
					addChar(c);
					#end
			}
		}
		#if hl
		if (prev >= 0)
			addChar("□".code);
		#end
		addChar('"'.code);
	}

	#if neko
	function quoteUtf8(s:String) {
		var u = new neko.Utf8();
		neko.Utf8.iter(s, function(c) {
			switch (c) {
				case '\\'.code, '"'.code:
					u.addChar('\\'.code);
					u.addChar(c);
				case '\n'.code:
					u.addChar('\\'.code);
					u.addChar('n'.code);
				case '\r'.code:
					u.addChar('\\'.code);
					u.addChar('r'.code);
				case '\t'.code:
					u.addChar('\\'.code);
					u.addChar('t'.code);
				case 8:
					u.addChar('\\'.code);
					u.addChar('b'.code);
				case 12:
					u.addChar('\\'.code);
					u.addChar('f'.code);
				default:
					u.addChar(c);
			}
		});
		buf.add('"');
		buf.add(u.toString());
		buf.add('"');
	}
	#end
}
