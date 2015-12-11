#include once "JsonItem.bi"

type jsonDocument extends jsonItem
	declare function ReadFile(path as string) as boolean
	
	declare operator [](key as string) byref as jsonItem
	declare operator [](index as integer) byref  as jsonItem
	declare function SaveFile(path as string, overwrite as boolean = true) as boolean
end type

operator jsonDocument.[](key as string) byref as jsonItem	
	if ( this._datatype = jsonObject ) then
		for i as integer = 0 to this.Count -1
			if ( this._children(i)->key = key ) then
				return *this._children(i)
			end if
		next
	end if
	return *new jsonItem()
end operator

operator jsonDocument.[](index as integer) byref as jsonItem
	if ( index <= this.Count -1 ) then
		return *this._children(index)
	end if
	return *new jsonItem()
end operator

function jsonDocument.ReadFile(path as string) as boolean
	dim as string jsonFile
	dim as integer ff = freefile()
	
	open path for binary as #ff 
	' I don't know if there is any better way to get the whole file at once.
	jsonFile = space(lof(ff))
	get #ff, , jsonFile
	' But using "get #" is definetly faster.
	close #ff
	
	jsonFile = trim(jsonFile, any " "+chr(9,10))
	this.Parse(jsonFile, 0, len(jsonFile)-1)	
	return this._datatype <> malformed
end function

function jsonDocument.SaveFile(path as string, overwrite as boolean = true) as boolean
	dim as string jsonFile = this.ToString()
	dim as integer ff = freefile()
	dim as integer fileError 
	
	if ( len(dir(path)) > 0 and overwrite = false ) then return false
	
	fileError = open(path for output as #ff)
	if (fileError = 0 ) then
		print #ff, jsonFile 
		close #ff
		return true
	end if
	return false
end function
