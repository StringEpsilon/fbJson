enum jsonDataType
	malformed = -1
	jsonNull = 0
	jsonObject
	jsonArray
	jsonNumber
	jsonString
	jsonBool
end enum

namespace fbJsonInternal

enum parserState
	none = -1
	keyToken = 0
	valueToken
	valueTokenClosed
end enum

end namespace

type jsonItem extends object
	protected:
		_dataType as jsonDataType = jsonNull
		_value as string
		_children(any) as jsonItem ptr
		_error as string
		
		declare static function ParseNumber(rawString as string) as string
		declare sub ParseObjectString(byref jsonString as string, startIndex as integer, endIndex as integer)
		declare sub ParseArrayString(byref jsonString as string, startIndex as integer, endIndex as integer)
	public:
		parent as jsonItem ptr
		key as string
		
		declare constructor()
		declare constructor(byref jsonString as string)
		
		declare property Value(newValue as string)
		declare property Value() as string
		declare property Count() as integer
		declare property DataType() as jsonDataType
		declare operator [](key as string) as jsonItem
		declare operator [](index as integer) as jsonItem
		
		declare function ToString(level as integer = 0) as string
end type

constructor jsonItem()
	' Nothing to do
end constructor

constructor jsonItem(byref jsonString as string)
	jsonString = trim(jsonString, any " "+chr(9,10) )
	this.ParseObjectString(jsonString, 0, len(jsonstring)-1)
end constructor

operator jsonItem.[](key as string) as jsonItem	
	if ( this._datatype = jsonObject ) then
		for i as integer = 0 to ubound(this._children)
			if ( this._children(i)->key = key ) then
				return *this._children(i)
			end if
		next
	end if
	#ifdef fbJSON_debug
		print "fbJSON Error: "& key & " not found in "& this.key
		end -1
	#endif
	return type<jsonItem>()
end operator

operator jsonItem.[](index as integer) as jsonItem
	if ( index <= ubound(this._children) ) then
		return *this._children(index)
	end if
	
	#ifdef fbJSON_debug
		print "fbJSON Error: "& index & " out of bounds in "& this.key &". Actual size is "& this.count
		end -1
	#else
		return type<jsonItem>()
	#endif
end operator

property jsonItem.Count() as integer
	return ubound(this._children)
end property

property jsonItem.DataType() as jsonDataType
	return this._datatype
end property

property jsonItem.Value( newValue as string)
	newValue = trim(newValue, any " " + chr(9,10,13))
	
	if ( left(newValue, 1) = """" ) then 
		if ( right(newValue, 1) = """" ) then
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
	else
		select case lcase(newValue)
		case "null", "nan", "infinity", "-infinity":
			this._value = newValue
			this._dataType = jsonNull
		case "true", "false"
			this._value = newValue
			this._dataType = jsonBool
		case else:
			this._dataType = jsonNumber
			this._value = jsonItem.ParseNumber(newValue)
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
	using fbJsonInternal
	
	dim as boolean errorOccured = false
	dim as string newKey
	dim as integer tokenCount
	dim as integer stateStart = startIndex + 1
	dim as parserState state = none
	dim as boolean isStringOpen = false

	if (this._dataType = jsonNull) then
		if ( chr(jsonString[startIndex]) = "{" and chr(jsonString[endIndex]) = "}" ) then
			this._datatype = jsonObject
		elseif ( chr(jsonString[startIndex]) = "[" and chr(jsonString[endIndex]) = "]" ) then
			this._dataType = jsonArray
		end if
	end if
	
	if (this._datatype = jsonarray) then 
		state = valueToken
	end if
	
	if (startIndex +1 = endIndex) then
		return
	end if
	
	for i as integer = startIndex +1 to endIndex -1
		' Because strings can contain other json tokens, we handle strings seperately:
		select case chr(jsonString[i])
		case """":
			if ( chr(jsonString[i-1]) <> "\" ) then
				isStringOpen = not(isStringOpen)
				
				if (isStringOpen = true) then
					if ( this._dataType <> jsonArray ) then
						if ( state = none ) then 
							state = keyToken
							stateStart = i+1
						end if
					end if
				end if
			end if
		case "\"
			if ( isStringOpen = false ) then 
				errorOccured = true
			end if
		end select
		
		' When not in a string, we can handle the complicated suff:
		if (isStringOpen = false) then
			select case chr(jsonString[i])
				case ":":
					if ( this._dataType = jsonArray ) then
						if ( tokenCount = 0 ) then errorOccured = true
					else
						if ( state = keyToken ) then
							newKey = trim(mid(jsonString, stateStart, i+1 - stateStart), any " """)
							state = valueToken
							stateStart = i+2
						elseif (tokenCount = 0 ) then
							errorOccured = true
						end if
					end if
				case ",":
					if( this._dataType = jsonArray ) then
						if ( state = valueToken and tokenCount = 0 ) then
							state = valueTokenClosed
						end if
					else
						if (state = valueToken and tokenCount = 0) then
							state = valueTokenClosed
						end if
					end if
				case "{", "[":
					if ( state = valueToken and tokenCount = 0 ) then
						stateStart = i
					end if
					tokenCount += 1
				case "}", "]"
					tokenCount -= 1
				case " ", chr(9), chr(10), """"
					
				case else:
					if (state <> valueToken) then
						errorOccured = true
					end if
			end select
		end if	
		
		if (i =  endIndex -1) then
			if ( isStringOpen = -1 or tokenCount <> 0  or state <> valueToken) then
				errorOccured = true
			end if
			state = valueTokenClosed 
			i+=1
		end if
		
		if ( state = valueTokenClosed ) then
			dim child as jsonItem ptr = new jsonItem
			dim valueString as string = trim(mid(jsonString, stateStart+1, i - stateStart),any " "+chr(9,10))
			
			child->parent = @this
			if ( this._datatype = jsonObject ) then
				child->key = newKey
				state = none
			else
				state = valueToken
			end if
			
			if ( left(valueString,1) = "{" and right(valueString,1) = "}" ) then
				child->_datatype = jsonObject
				child->ParseObjectString(jsonString, stateStart, stateStart + len(valuestring) -1)
			elseif ( left(valueString,1) = "[" and right(valueString,1) = "]" ) then
				child->_datatype = jsonArray
				child->ParseObjectString(jsonString, stateStart, stateStart + len(valuestring) -1)
			else
				child->Value = valueString
			end if
			
			redim preserve this._children(ubound(this._children)+1)
			this._children(ubound(this._children)) = child
			stateStart = i+1
		end if
		
		if ( errorOccured ) then
			dim as integer lineNumber = 1
			dim as integer position = 1
			for i as integer = 0 to i
				if (jsonString[i] = 10) then
					lineNumber +=1
					position = 1
				end if
				position +=1
			next
			
			if ( isStringOpen ) then
				this._error = "Expected closing quote, found: "+ chr(jsonString[i]) + "' in line "& lineNumber &" at position " & position
			else
				this._error = "Unexpected token '"+ chr(jsonString[i]) + "' in line "& lineNumber &" at position " & position
			end if
			? i +1, state
			#ifdef fbJson_DEBUG
				print "fbJSON Error: " & this._error
			#endif
			this._dataType = malformed
			return
		end if
	next
end sub


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


function jsonItem.ToString(level as integer = 0) as string
	dim as string result
	
	if this.datatype = jsonObject  then
		result = "{" + chr(10) + string((level+1), chr(9)) 
	elseif ( this.datatype = jsonArray ) then
		result = "["
	end if
		
	for i as integer = 0 to this.count
		if ( this.datatype = jsonObject ) then
			result += """" & this[i].key & """ : " 
		end if
		
		if ( this[i].Count >= 0 ) then
			result += this[i].toString(level+1)
		else			
			if ( this[i].datatype = jsonString) then
				result += """"
			end if
			
			result += this[i].value
			
			if ( this[i].datatype = jsonString) then
				result += """"
			end if
		end if
		if ( i < this.count ) then
			result += ","
		else
			level -= 1
		end if
		
		if (this.datatype = jsonObject) then
			result += chr(10)
			result += string((level+1),chr(9)) 
		end if
	next
	
	if this.datatype = jsonObject  then
		result += "}"
	elseif ( this.datatype = jsonArray ) then
		result += "]"
	end if
	
	return result
end function
