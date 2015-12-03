enum jsonDataType
	malformed = -1
	jsonNull = 0
	jsonObject
	jsonArray
	jsonNumber
	jsonString
	jsonBool
end enum

enum parserState
	none = -1
	keyToken = 0
	valueToken
	valueTokenClosed
	arrayToken
	arrayTokenClosed
	objectToken
end enum

type jsonItem extends object
	private:
		_dataType as jsonDataType = jsonNull
		_value as string
		_children(any) as jsonItem ptr
		
		declare static function ParseNumber(rawString as string) as string
		declare sub ParseObjectString(byref jsonString as string, startIndex as integer, endIndex as integer)
	public:
		parent as jsonItem ptr
		key as string
	
		
		values(any) as string
		
		declare constructor()
		declare constructor(byref jsonString as string)
		
		declare property Value(newValue as string)
		declare property Value() as string
		declare property Count() as integer
		declare property DataType() as jsonDataType
		declare operator [](key as string) as jsonItem
		declare operator [](index as integer) as  jsonItem
end type

constructor jsonItem()
	' Nothing to do
end constructor

constructor jsonItem(byref jsonString as string)
	this.ParseObjectString(jsonString, 1, len(jsonstring)-2)
end constructor

operator jsonItem.[](key as string) as jsonItem	
	for i as integer = 0 to ubound(this._children)
		if ( this._children(i)->key = key ) then
			return *this._children(i)
		end if
	next
	return type<jsonItem>()
end operator

operator jsonItem.[](index as integer) as jsonItem
	if ( index <= ubound(this._children) ) then
		return *this._children(index)
	end if
	return type<jsonItem>()
end operator

property jsonItem.Count() as integer	
	return ubound(this._children)
end property

property jsonItem.Value( newValue as string)
	newValue = trim(newValue, any " " + chr(9,10,13))
	if ( left(newValue, 1) = """" ) then 
		if (right(newValue, 1) = """" ) then
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
	elseif ( left(newValue, 1) = "[" ) then 
		if (right(newValue, 1) = "]" ) then
			this._dataType = jsonarray
			this._value = newValue
		else
			this._dataType = malformed
		end if
	else
		select case lcase(newValue)
		case "null":
			this._value = newValue
			this._dataType = jsonnull
		case "true", "false"
			this._value = newValue
			this._dataType = jsonbool
		case else:
			this._dataType = jsonnumber
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

sub jsonItem.ParseObjectString(byref jsonString as string, startIndex as integer, endIndex as integer)	
	this._datatype = jsonObject
	dim as boolean errorOccured = false
	dim as string newKey
	dim as integer tokenCount
	dim as integer stateStart
	dim as parserState state = none
	dim as boolean isEscaped = false
	dim as boolean isStringOpen = false

	for i as integer = startIndex to endIndex
		' Because strings can contain other json tokens, we handle string seperately:
		select case chr(jsonString[i])
		case """":
			if (not isEscaped) then
				isStringOpen = not(isStringOpen)
				if (isStringOpen = true) then
					if ( state = none ) then 
						state = keyToken
						stateStart = i+1
					elseif (state = valueToken) then
						stateStart = i+1
					end if
				end if
			else
				isEscaped = false
			end if
		case "\":
			if (isStringOpen) then
				isEscaped = true
			else
				errorOccured = true
			end if
		end select
		
		' When not in a string, we can handle the complicated suff:
		if (isStringOpen = false) then
			select case chr(jsonString[i])
				case ":":
					if (state = keyToken) then
						newKey = trim(mid(jsonString, stateStart, i+1 - stateStart), any " """)
						state = valueToken
						stateStart = i+2
					elseif (state <> objectToken and state <> arrayToken) then
						errorOccured = true
					end if
				case ",":
					if (state = valueToken) then
						state = valueTokenClosed
					end if
				case "{":
					if ( state = valueToken and tokenCount = 0 ) then
						state = objectToken
						stateStart = i+1
					end if
					tokenCount += 1
				case "}"
					tokenCount -= 1
					if ( state = objectToken and tokenCount = 0) then
						this._datatype = jsonObject
						
						dim child as jsonItem ptr = new jsonItem
						
						redim preserve this._children(ubound(this._children)+1)
						this._children(ubound(this._children)) = child
						child->parent = @this
						
						child->key = newKey
						child->ParseObjectString(jsonString, stateStart, i)
						state = none
						stateStart = i+1
					elseif (state <> valueToken and state <> arrayToken) then
						if (state <> objectToken and tokenCount = 0) then
							errorOccured = true
						end if
					end if
				case "[":
					if (state = valueToken) then	
						state = arrayToken
					elseif (state < arrayToken) then
						errorOccured = true
					end if
				case "]":
					if (state = arrayToken) then
						state = valueToken
					end if
			end select
		end if	
		
		if (i = endIndex) then
			if (isStringOpen) then
				errorOccured = true
			end if
			if (state = valueToken) then
				state = valueTokenClosed
			else
				errorOccured = true
			end if
		end if
		
		if (state = valueTokenClosed) then
			dim child as jsonItem ptr = new jsonItem
			
			child->parent = @this
			child->key = newKey
			child->Value = mid(jsonString, stateStart, i+1 - stateStart)
			
			redim preserve this._children(ubound(this._children)+1)
			this._children(ubound(this._children)) = child
			stateStart = i
			state = none
		end if
		
		if ( errorOccured ) then
			this._dataType = malformed
			
			dim as integer lineNumber = 1
			dim as integer position = 1
			for i as integer = 0 to endIndex
				if (jsonString[i] = 10) then
					lineNumber +=1
					position = 1
				end if
				position +=1
			next
			
			if (isStringOpen) then
				print "FBJSON Error: Expected closing quote, found: "+ chr(jsonString[i]) + "' in line "& lineNumber &" at position " & position
			else
				print "FBJSON Error: Unexpected token '"+ chr(jsonString[i]) + "' in line "& lineNumber &" at position " & position
			end if
			return
		end if
	next
end sub

type fbJsonDocument extends JsonItem

end type
