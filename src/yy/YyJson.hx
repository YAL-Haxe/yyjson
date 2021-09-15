package yy;

/**
 * ...
 * @author YellowAfterlife
 */
class YyJson {
	public static inline function parse(text:String):Dynamic {
		return YyJsonParser.parse(text);
	}
	public static inline function stringify(value:Dynamic, ?replacer:(key:Dynamic, value:Dynamic)->Dynamic):String {
		return YyJsonPrinter.print(value, replacer);
	}
}