
namespace fbJsonInternal

enum jsonToken
	tab = 9
	newLine = 10
	space = 32
	quote = 34
	comma = 44
	colon = 58
	squareOpen = 91
	backSlash = 92
	squareClose = 93
	curlyOpen = 123
	curlyClose = 125
	lcaseU = 117
end enum

enum parserState
	none = -1
	keyToken = 0
	valueToken
	valueTokenClosed
end enum

sub DeEscapeString(byref escapedString as string)
	dim as uinteger length = len(escapedString)-1
	dim as uinteger trimSize = 0	
	for i as uinteger = 0 to length
		if ( escapedString[i] = BackSlash ) then
			if ( i < length andAlso escapedString[i+1] = jsonToken.lcaseU ) then
				' TODO: Decode \u0000 notation.
			else
				escapedString[i-trimsize] = escapedString[i+1]
				trimSize+=1
			end if
		elseif ( trimSize > 0 ) then
			escapedString[i-trimsize] = escapedString[i]
		end if
	next
	if ( trimSize > 0 ) then
		escapedString = left(escapedString, length - trimSize+1)
	end if
end sub

end namespace

type jsonItem
	protected:
		_dataType as jsonDataType = jsonNull
		_value as string
		_children(any) as jsonItem ptr
		_error as string
		_parent as jsonItem ptr
		
		declare sub Parse(byref jsonString as string, startIndex as integer, endIndex as integer)
		
		declare function AppendChild(newChild as jsonItem ptr) as boolean
		declare function AppendChild(key as string, newChild as jsonItem ptr) as boolean
	public:
		
		key as string
		
		declare constructor()
		declare constructor(byref jsonString as string)
		
		declare destructor()
		
		declare property Value(byref newValue as string)
		declare property Value() as string
		
		declare property Count() as integer
		declare property DataType() as jsonDataType
		
		declare operator [](key as string) byref as jsonItem
		declare operator [](index as integer) byref as jsonItem
		
		declare property Parent() byref as jsonItem
		
		declare operator LET(A as jsonItem)
		
		declare function ToString(level as integer = 0) as string
		
		declare function AddItem(key as string, value as string) as boolean
		declare function AddItem(key as string, item as jsonItem) as boolean
		
		declare function AddItem(value as string) as boolean
		declare function AddItem(item as jsonItem) as boolean
					
		declare function RemoveItem(key as string) as boolean
		declare function RemoveItem(index as integer) as boolean
		
		declare function ContainsKey(key as string) as boolean	
end type

constructor jsonItem()
	' Nothing to do
end constructor

constructor jsonItem(byref jsonString as string)
	jsonString = trim(jsonString, any " "+chr(9,10) )
	this.Parse(jsonString, 0, len(jsonstring)-1)
end constructor

destructor jsonItem()
	for i as integer = 0 to ubound(this._children)
		delete this._children(i)
	next
end destructor

operator jsonItem.LET(copy as jsonItem)
	this._value = copy._value
	this._dataType = copy._dataType
	this._error = copy._error
	
	if ( ubound(copy._children) >= 0 ) then
		redim this._children(ubound(copy._children))
		for i as integer = 0 to ubound(copy._children)
			this._children(i) = callocate(sizeOf(jsonItem))
			*this._children(i) = *copy._children(i)
		next
	end if
end operator

property jsonItem.Parent() byref as jsonItem
	if ( this._parent <> 0 ) then
		return *this._parent
	end if
	
	return *new jsonItem()
end property

operator jsonItem.[](key as string) byref as jsonItem	
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
	return *new jsonItem()
end operator

operator jsonItem.[](index as integer) byref as jsonItem
	if ( index <= ubound(this._children) ) then
		return *this._children(index)
	end if
	
	#ifdef fbJSON_debug
		print "fbJSON Error: "& index & " out of bounds in "& this.key &". Actual size is "& this.count
		end -1
	#else
		return *new jsonItem()
	#endif
end operator

property jsonItem.Count() as integer
	' +1 because arrays start at 0.
	return ubound(this._children) + 1
end property

property jsonItem.DataType() as jsonDataType
	return this._datatype
end property

property jsonItem.Value( byref newValue as string)
	using fbJsonInternal	
	' First, handle strings in quotes:
	if ( newValue[0] = jsonToken.Quote ) then 
		if ( newValue[len(newValue)-1] = jsonToken.Quote ) then
			this._dataType = jsonString
			this._value = newValue
			DeEscapeString(this._value)
		else
			this._dataType = malformed
		end if
	else
		' Now handle the other stuff:
		select case lcase(newValue)
		case "null", "nan","+nan","-nan", "infinity", "-infinity":
			this._value = newValue
			this._dataType = jsonNull
		case "true", "false"
			this._value = newValue
			this._dataType = jsonBool
		case else:
			this._dataType = jsonNumber
			this._value = str(cdbl(newValue))
			' And for convience: Everything that's none of the above and not a number, we save as string:
			if ( this._value = "0" andAlso newValue <> "0" ) then
				this._value = newValue
				DeEscapeString(this._value)
				this._dataType = jsonString
			end if
		end select
	end if
end property

property jsonItem.Value() as string
	return this._value
end property

sub jsonItem.Parse(byref jsonString as string, startIndex as integer, endIndex as integer)
	using fbJsonInternal
	
	dim as boolean errorOccured = false
	dim as string newKey
	dim as integer currentLevel
	dim as integer stateStart = startIndex + 1
	dim as parserState state = none
	dim as boolean isStringOpen = false

	if (this._dataType = jsonNull) then
		if ( jsonString[startIndex] = jsonToken.CurlyOpen andAlso jsonString[endIndex] = jsonToken.CurlyClose ) then
			this._datatype = jsonObject
		elseif ( jsonString[startIndex] = jsonToken.SquareOpen andAlso jsonString[endIndex] = jsonToken.SquareClose ) then
			this._dataType = jsonArray
		end if
	end if
	
	if (this._datatype = jsonarray) then 
		state = valueToken
	end if
	
	if (startIndex +1 >= endIndex) then
		return
	end if
	
	for i as integer = startIndex +1 to endIndex -1
		' Because strings can contain other json tokens, we handle strings seperately:
		select case as const jsonString[i]
		case jsonToken.Quote
			if ( jsonString[i-1] <> jsonToken.BackSlash ) then
				isStringOpen = not(isStringOpen)
				
				if ( isStringOpen = true ) then
					if ( this._dataType <> jsonArray ) then
						if ( state = none ) then 
							state = keyToken
							stateStart = i+1
						end if
					end if
				else
					if ( state = keyToken ) then
						newKey = mid(jsonString, stateStart+1, i - stateStart)
					end if
				end if
			end if
		case jsonToken.BackSlash
			if ( isStringOpen = false ) then 
				errorOccured = true
			end if
		end select
		
		' When not in a string, we can handle the complicated suff:
		if ( isStringOpen = false ) then
			select case as const jsonString[i]
				case jsonToken.Colon:
					if ( this._dataType = jsonArray ) then
						if ( currentLevel = 0 ) then errorOccured = true
					else
						if ( state = keyToken ) then
							state = valueToken
							stateStart = i+1
						elseif (currentLevel = 0 ) then
							errorOccured = true
						end if
					end if
				case jsonToken.Comma:
					if (currentLevel = 0 andAlso state = valueToken ) then
						state = valueTokenClosed
					end if
				case jsonToken.CurlyOpen, jsonToken.SquareOpen
					if ( currentLevel = 0 andAlso state = valueToken ) then
						stateStart = i
					end if
					currentLevel += 1
				case jsonToken.CurlyClose, jsonToken.SquareClose
					currentLevel -= 1
				case jsonToken.Space, jsonToken.Tab, jsonToken.NewLine, jsonToken.Quote, 13
					' break.
				case else:
					if (state <> valueToken) then
						errorOccured = true
					end if
			end select
		end if	
		
		if ( i =  endIndex -1 ) then
			if ( isStringOpen = -1 orElse currentLevel <> 0 orElse state <> valueToken ) then
				errorOccured = true
			end if
			state = valueTokenClosed 
			i+=1
		end if
		
		if ( state = valueTokenClosed ) then
			dim child as jsonItem ptr = new jsonItem
			dim valueString as string = trim(mid(jsonString, stateStart+1, i - stateStart),any " "+chr(9,10))
			
			if ( valueString[0] = jsonToken.CurlyOpen andAlso _
				valueString[len(valueString)-1] = jsonToken.CurlyClose ) then
					
				child->_datatype = jsonObject
				child->Parse(jsonString, stateStart, stateStart + len(valuestring) -1)
			elseif ( valueString[0] = jsonToken.SquareOpen andAlso _
				valueString[len(valueString)-1] = jsonToken.SquareClose ) then
				
				child->_datatype = jsonArray
				child->Parse(jsonString, stateStart, stateStart + len(valuestring) -1)
			else
				child->Value = valueString
			end if
			
			if ( this._dataType = jsonObject ) then
				this.AppendChild(newKey, child)
				state = none
			else
				this.AppendChild(child)
				state = valueToken
			end if
			stateStart = i+1
		end if
		
		if ( errorOccured ) then
			dim as integer lineNumber = 1
			dim as integer position = 1
			for i as integer = 0 to i
				if ( jsonString[i] = 10 ) then
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
			#ifdef fbJson_DEBUG
				print "fbJSON Error: " & this._error
			#endif
			this._dataType = malformed
			return
		end if
	next
end sub

function jsonItem.ToString(level as integer = 0) as string
	dim as string result
	
	if this.datatype = jsonObject  then
		result = "{" + chr(10) + string((level+1), chr(9)) 
	elseif ( this.datatype = jsonArray ) then
		result = "["
	end if
		
	for i as integer = 0 to this.count - 1
		if ( this.datatype = jsonObject ) then
			result += """" & this[i].key & """ : " 
		end if
		
		if ( this[i].Count >= 1 ) then
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
		if ( i < this.Count - 1 ) then
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

function JsonItem.AddItem(key as string, newValue as string) as boolean
	if ( len(key) = 0 orElse this[key].datatype <> jsonNull ) then
		return false
	end if
	
	if ( this._datatype = jsonNull ) then
		this._datatype = jsonObject
	end if
	
	if ( this._datatype = jsonObject ) then
		dim child as JsonItem ptr = new jsonItem
		child->Value = newValue
		return this.AppendChild(key, child)
	end if
	return false
end function

function JsonItem.AddItem(key as string, item as jsonItem) as boolean
	if ( len(key) = 0 orElse this[key].datatype <> jsonNull ) then
		return false
	end if
	
	if ( this._datatype = jsonNull ) then
		this._datatype = jsonObject
	end if
	
	if ( this._datatype = jsonObject ) then
		dim child as JsonItem ptr = callocate(sizeof(jsonItem))
		*child = item
		return this.AppendChild(key, child)
	end if
	return false
end function

function JsonItem.AddItem(newValue as string) as boolean
	if ( this._datatype = jsonArray or this._datatype = jsonNull ) then
		this._datatype = jsonArray
		dim child as JsonItem ptr = new jsonItem
		child->value = newValue
		return this.AppendChild(child)
	end if
	return false
end function

function JsonItem.AddItem(item as jsonItem) as boolean
	if ( this._datatype = jsonArray ) then
		dim child as JsonItem ptr = callocate(sizeof(jsonItem))
		*child = item
		return this.AppendChild(child) 		
	end if
	return false
end function

function jsonItem.AppendChild(newChild as jsonItem ptr) as boolean
	if ( this._dataType = jsonArray andAlso newChild <> 0 ) then
		newChild->_parent = @this
		redim preserve this._children(this.count)
		this._children(this.Count -1) = newChild
		return true
	else
		if newChild <> 0 then delete newChild
		return false
	end if
end function

function jsonItem.AppendChild(key as string, newChild as jsonItem ptr) as boolean
	if ( this._dataType = jsonObject andAlso newChild <> 0 andAlso len(key) <> 0 ) then
		newChild->_parent = @this
		newChild->key = key
		redim preserve this._children(this.count)
		this._children(this.Count -1) = newChild
		return true
	else
		if ( newChild <> 0 ) then delete newChild
		return false
	end if
end function

function JsonItem.RemoveItem(key as string) as boolean
	dim as integer index = -1
	
	if ( this._datatype = jsonObject ) then
		for i as integer = 0 to ubound(this._children)
			if ( this._children(i)->key = key ) then
				index = i
				exit for
			end if
		next
	end if
	
	return this.RemoveItem(index)
end function

function JsonItem.RemoveItem(index as integer) as boolean
	if ( index <= this.Count -1 andAlso index > -1 ) then
		delete this._children(index)
		if ( index < this.Count -1 ) then
			for i as integer = index to this.Count -1
				this._children(i) = this._children(i+1)
			next
		end if
		
		redim preserve this._children(this.Count -1)
		return true
	end if
	return false
end function

function JsonItem.ContainsKey(key as string) as boolean
	if ( this._datatype <> jsonObject ) then return false
	
	for i as integer = 0 to this.Count -1
		if ( this._children(i)->key = key ) then
			return true
		end if
	next
	return false
end function
