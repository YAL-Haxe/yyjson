package yy;
import yy.YyResourceType;

/**
 * ...
 * @author YellowAfterlife
 */
class YyJsonMeta {
	/**
	 * If set, will auto-populate basic fieldOrder+fieldType while parsing,
	 * meaning that parsing an object and then printing it back will produce same
	 * output for objects with resourceType.
	 */
	public static var autofill:Bool = true;
	
	public static var fieldOrder:Map<YyResourceType, Array<String>> = {
		// function fieldOrder(obj) { let r = []; for (let f in obj) r.push(f); return r; }
		var map = new Map();
		var base = ['parent', 'resourceVersion', 'name', 'tags', 'resourceType'];
		map[""] = base;
		map;
	};
	
	public static var fieldType:Map<YyResourceType, Map<String, YyResourceType>> = new Map();
}