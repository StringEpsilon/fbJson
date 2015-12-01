enum jsonDataType
	malformed = -1
	null
	object
	array
	number
	jsonString
	bool
end enum

type jsonItem extends object
	private:
		_dataType as jsonDataType = null
		_value as string
		declare static function ParseNumber(rawString as string) as string
	
	public:
		parent as jsonItem ptr
		key as string
	
		children(any) as jsonItem ptr
		values(any) as string
		
		declare property Value(newValue as string)
		declare property Value() as string
		declare property DataType() as jsonDataType
		declare operator [](key as string) as jsonItem
		declare operator [](index as integer) as  jsonItem
end type

operator jsonItem.[](key as string) as jsonItem	
	for i as integer = 0 to ubound(this.children)
		if ( this.children(i)->key = key ) then
			return *this.children(i)
		end if
	next
	return type<jsonItem>()
end operator

operator jsonItem.[](index as integer) as jsonItem
	if ( index <= ubound(this.children) ) then
		return *this.children(index)
	end if
	? "error accessing child"
	return type<jsonItem>()
end operator

property jsonItem.Value( newValue as string)
	newValue = trim(newValue, any " " + chr(9))
	this._value = newValue
	
	if ( left(this._value, 1) = """" ) then 
		if (right(this._value, 1) = """" ) then
			this._dataType = jsonString
			this._value = ""
			for i as integer = 1 to len(newValue)-2
				if chr(newValue[i]) <> "\" then
					this._value += chr(newValue[i])
				end if
			next
		else
			this._dataType = malformed
		end if
	elseif ( left(this._value, 1) = "[" ) then 
		if (right(this._value, 1) = "]" ) then
			this._dataType = array
		else
			this._dataType = malformed
		end if
	else
		select case lcase(newValue)
		case "null":
			this._dataType = null
		case "true", "false"
			this._dataType = bool
		case else:
			this._dataType = number
			this._value = jsonItem.ParseNumber(this._value)
		end select
	end if
end property

property jsonItem.Value() as string
	return this._value
end property

function jsonItem.ParseNumber(rawString as string) as string
	return str(cdbl(rawString))
end function

type fbJsonDocument extends JsonItem

end type
