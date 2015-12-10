#include once "JsonItem.bi"

type jsonDocument extends jsonItem
	declare function ReadFile(path as string) as boolean
	
	declare operator [](key as string) byref as jsonItem
	declare operator [](index as integer) byref  as jsonItem
	declare function SaveFile(path as string, overwrite as boolean = true) as boolean
end type
