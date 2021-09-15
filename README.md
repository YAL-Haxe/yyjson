## yyjson
This little library helps with processing GameMaker Studio 2.3's `yy` files,
which are slightly lean (read: trailing commas, 64-bit integer literals) JSON with field order depending
on C# field order of serialized objects.

Features:

*	`parse` and `stringify` methods with generally-identical output to IDE.
*	"learns" the field patterns (per-`resourceType`) while parsing and applies them on `stringify` (see `yy.YyJsonMeta`).
*	Has `yy.YyJsonParser.storeKeys` that you can flip on for a few cases where you need ordered iteration on an object.