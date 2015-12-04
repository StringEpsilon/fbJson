#include once "JsonItem.bi"

type jsonDocument extends jsonItem
	declare function ReadFile(path as string) as boolean
	
	declare operator [](key as string) as jsonItem
	declare operator [](index as integer) as jsonItem
end type

operator jsonDocument.[](key as string) as jsonItem	
	if ( this._datatype = jsonObject ) then
		for i as integer = 0 to ubound(this._children)
			if ( this._children(i)->key = key ) then
				return *this._children(i)
			end if
		next
	end if
	return type<jsonItem>()
end operator

operator jsonDocument.[](index as integer) as jsonItem
	if ( index <= ubound(this._children) ) then
		return *this._children(index)
	end if
	return type<jsonItem>()
end operator

function jsonDocument.ReadFile(path as string) as boolean
	dim as string inputLine 
	dim as string jsonFile
	dim as integer ff = freefile()
	
	open path for input as #ff 
		while (not eof(ff))
			line input #ff, inputLine 
			jsonFile += inputLine + chr(10)
		wend
	close #ff
	
	jsonFile = trim(jsonFile, any " "+chr(9,10) )
	this.ParseObjectString(jsonFile, 0, len(jsonFile)-1)	
	return this._datatype <> malformed
end function
