#include once "JsonDatatype.bi"

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
	forwardSlash = 47
	squareClose = 93
	curlyOpen = 123
	curlyClose = 125
	lcaseU = 117
	lcaseB = 98
	lcaseF = 102
	lcaseN = 110
	lcaseR = 114
	lcaseT = 116
end enum

enum parserState
	jsonError = -1
	none = 0
	keyToken
	valueToken
	valueTokenClosed
	nestEnd
end enum

function DeEscapeString(byref escapedString as string) as boolean
	dim as uinteger length = len(escapedString)-1
	dim as uinteger trimSize = 0	
	for i as uinteger = 0 to length
		if ( escapedString[i] = BackSlash ) then
			if ( i < length ) then
				select case as const escapedString[i-trimsize+1]
				case quote, backSlash, forwardSlash:
					'escapedString[i-trimsize+1] = escapedString[i-trimsize+1]
				case lcaseB
					escapedString[i-trimsize+1] = 8 ' backspace
				case lcaseF
					escapedString[i-trimsize+1] = 12
				case lcaseN
					escapedString[i-trimsize+1] = 10
				case lcaseR
					escapedString[i-trimsize+1] = 13
				case lcaseT
					escapedString[i-trimsize+1] = 9 ' tab
				case lcaseU
					' TO DO: Escape unicode sequences.
				case else
					return false
				end select
				trimSize+=1
			end if
		elseif ( trimSize > 0 ) then
			escapedString[i-trimsize] = escapedString[i]
		end if
	next
	if ( trimSize > 0 ) then
		escapedString = left(escapedString, length - trimSize+1)
	end if
	return true
end function

end namespace

type jsonItem
	protected:
		_dataType as jsonDataType = jsonNull
		_value as string
		_children(any) as jsonItem ptr
		_error as string
		_parent as jsonItem ptr
		
		declare sub Parse(byref jsonString as string,  endIndex as integer) 
		
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
	this.Parse(jsonString, len(jsonstring)-1)
end constructor

destructor jsonItem()
	for i as integer = 0 to ubound(this._children)
		delete this._children(i)
	next
end destructor

operator jsonItem.LET(copy as jsonItem)
	this.destructor()
	this._value = copy._value
	this._dataType = copy._dataType
	this._error = copy._error
	
	if (ubound(copy._children) >= 0) then
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
			this._value = mid(newValue,2, len(newValue)-2)
			if ( DeEscapeString(this._value) = false ) then
				this._datatype = malformed
			end if
		else
			this._dataType = malformed
		end if
	else
		
		select case lcase(newValue)
		case "null"
			this._value = newValue
			this._dataType = jsonNull
		case "true", "false"
			this._value = newValue
			this._dataType = jsonBool
		case else:
			
			dim as byte lastCharacter = newValue[len(newValue)-1]
			if ( lastCharacter > 57 orElse lastCharacter < 48 ) then
				' IF the current item is already a string, we can be a little more forgiving
				' This allows for easier manipulation of items in code 
				' (because you don't have to include the quotes every time)
				' This solution is of course ugly as f..., but whatever.
				if ( this._datatype = jsonString ) then
					this._value = newValue
				else
					this._datatype = malformed
				end if
			else
				this._dataType = jsonNumber
				this._value = str(cdbl(newValue))
				if ( this._value = "0" andAlso newValue <> "0" ) then
					this._datatype = malformed
				end if
			end if
		end select
	end if
end property

property jsonItem.Value() as string
	return this._value
end property

sub jsonItem.Parse(byref jsonString as string, endIndex as integer) 
	using fbJsonInternal
	dim currentItem as jsonItem ptr = @this
	dim child as jsonItem ptr
	dim i as integer
	dim as string key
	dim as integer valueStart
	dim as parserState state
	dim as boolean isStringOpen 
	dim valueString as string
	
	if ( jsonString[0] = jsonToken.CurlyOpen andAlso jsonString[endIndex] = jsonToken.CurlyClose ) then
		currentItem->_datatype = jsonObject
		state = parserState.none
	elseif ( jsonString[0] = jsonToken.SquareOpen andAlso jsonString[endIndex] = jsonToken.SquareClose ) then
		currentItem->_dataType = jsonArray
		state = valueToken
	end if
	
	if ( endIndex <= 1) then
		return 
	end if
	endindex = endIndex -1
	
	for i = 1 to endIndex 
		' Because strings can contain json tokens, we handle them seperately:
		if ( jsonString[i] = jsonToken.Quote AndAlso jsonString[i-1] <> jsonToken.BackSlash ) then
			isStringOpen = not(isStringOpen)
			if ( currentItem->_datatype = jsonObject ) then
				select case as const state
				case none:
					state = keyToken
					valueStart = i+1
				case keyToken
					key = mid(jsonString, valueStart+1, i - valueStart)
				end select
			end if
		end if
		
		' When not in a string, we can handle the complicated suff:
		if ( isStringOpen = false ) then
			' Note: Not a single string-comparison in here. 
			select case as const jsonString[i]
				case jsonToken.BackSlash
					state = jsonError

				case jsonToken.Colon:
					if (state = keyToken ) then 
						state = valueToken
						valueStart = i+1
					end if
					
				case jsonToken.Comma:
					if ( state = valueToken ) then
						state = valueTokenClosed
					end if
					
				case jsonToken.CurlyOpen:
					if ( state = valueToken ) then
						child = new jsonItem()
						child->_datatype = jsonobject
						if ( currentItem->_datatype = jsonObject ) then
							currentItem->AppendChild( key, child )
						else
							currentItem->AppendChild( child )
						end if
						currentItem = child
						state = none
					else
						state = jsonError
					end if
					
				case jsonToken.SquareOpen:
					if ( state = valueToken ) then
						child = new jsonItem()
						child->_datatype = jsonArray
						if ( currentItem->_datatype = jsonObject ) then
							currentItem->AppendChild( key, child )
						else
							currentItem->AppendChild( child )
						end if
						currentItem = child
						state = valueToken
						valueStart = i+1
					else
						state = jsonError
					end if
					
				case jsonToken.CurlyClose:
					if ( currentItem->_parent <> 0 andAlso currentItem->_datatype = jsonObject) then
						state = nestEnd
					else
						state = jsonError
					end if
				
				case jsonToken.SquareClose:
					if ( currentItem->_parent <> 0 andAlso currentItem->_datatype = jsonArray) then
						state = nestEnd
					else
						state = jsonError
					end if

				case jsonToken.Space, jsonToken.Tab, jsonToken.NewLine, jsonToken.Quote, 13
					' break.
					
				case else:
					if ( state <> valueToken ) then
						state = jsonError
					end if
			end select
		end if	
		
		if ( i = endIndex ) then
			if ( currentItem->_parent <> 0 andAlso state <> nestEnd ) then
				state = jsonError
			end if
		
			if (state = valueToken) then
				state = valueTokenClosed
			end if
		end if
		
		if ( state = valueTokenClosed orElse state = nestEnd ) then
			dim length as integer
			
			' Believe it or not: It's faster to check this first.
			if ( i-valueStart <> 0 ) then
				' This trim() munches a good amount of the runtime, at least for the object_flat example.
				' I could probably get around that, by manually counting up the whitespaces to have the exact "MID()" i need.
				valueString = trim(mid(jsonString, valueStart+1, i - valueStart),any !" \r\n")
				length = len(valuestring)
			end if
						
			if ( length <> 0 ) then
				child = new jsonItem()

				select case as const valueString[0]
				case jsonToken.Quote
					if ( valueString[length-1] = jsonToken.Quote ) then
						child->_dataType = jsonDataType.jsonString
						child->_value = mid(valueString,2, length-2)
						if ( DeEscapeString(child->_value) = false ) then
							child->_datatype = malformed
							state = jsonError
						end if
					else
						child->_dataType = malformed
					end if
				case 110,78, 102,70, 116,84 ' n,N f,F t,T
					select case lcase(valueString)
						case "null"
							child->_value = valueString
							child->_dataType = jsonNull
						case "true", "false"
							child->_value = valueString
							child->_dataType = jsonBool
						case else
							child->_datatype = malformed
					end select
				case else:
					dim as byte lastCharacter = valueString[length-1]
					if ( lastCharacter <= 57 orElse lastCharacter >= 48 ) then
						child->_dataType = jsonNumber
						child->_value = str(cdbl(valueString))
						if ( child->_value = "0" andAlso valueString <> "0" ) then
							child->_datatype = malformed
						end if
					else
						child->_datatype = malformed
					end if
				end select
				
				if ( currentItem->_datatype = jsonObject ) then
					currentItem->AppendChild(key, child)
				else
					currentItem->AppendChild(child)
				end if
			end if
			
			if ( state = nestEnd ) then
				currentItem = currentItem->_parent
			end if
			
			if ( currentItem->_datatype = jsonArray ) then
				state = valueToken
				valueStart = i+1
			else
				state = none
			end if
		end if
		
		if ( state = jsonError ) then
			dim as integer lineNumber = 1
			dim as integer position = 1
			dim as integer lastBreak = 0
			for j as integer = 0 to i
				if ( jsonString[j] = 10 ) then
					lineNumber +=1
					position = 1
					lastBreak = j
				end if
				position +=1
			next

			if ( isStringOpen ) then
				currentItem->_error = "Expected closing quote, found: "+ chr(jsonString[i]) + "' in line "& lineNumber &" at position " & position
			else
				currentItem->_error = "Unexpected token '"+ chr(jsonString[i]) + "' in line "& lineNumber &" at position " & position & "."
			end if
			#ifdef fbJson_DEBUG
				print mid(jsonString, lastBreak +1, i - lastBreak +2)
				print space(position-2) + "^"
				print "fbJSON Error: " & currentItem->_error
			#endif
			currentItem->_dataType = malformed
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
	if ( newChild <> 0 ) then
		newChild->_parent = @this
		redim preserve this._children(this.count)
		this._children(this.Count -1) = newChild
		if ( newChild->datatype = jsonDataType.malformed ) then
			this._datatype = malformed
		end if
		return true
	else
		if newChild <> 0 then delete newChild
		return false
	end if
end function

function jsonItem.AppendChild(key as string, newChild as jsonItem ptr) as boolean
	if ( cbool(len(key) <> 0) AndAlso this.ContainsKey(key) = false ) then
		newChild->key = key
		return this.AppendChild(newChild)
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
