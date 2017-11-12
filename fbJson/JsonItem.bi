/'	
	This Source Code Form is subject to the terms of the Mozilla Public
	License, v. 2.0. If a copy of the MPL was not distributed with this
	file, You can obtain one at http://mozilla.org/MPL/2.0/. 
'/

#include once "JsonDatatype.bi"
#include once "StringFunctions.bi"

namespace fbJsonInternal

enum jsonError
	arrayNotClosed
	objectNotClosed
	stringNotClosed
	invalidValue
	invalidEscapeSequence
	invalidNumber
	expectedKey
	expectedValue
	unexpectedToken
end enum

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
	minus = 45
	plus = 43
end enum

enum parserState
	none = 0
	keyToken
	keyTokenClosed
	valueToken
	valueTokenClosed
	nestEnd
	nestEndHandled
	resetState
end enum

end namespace

type JsonItem 
	protected:
		_isMalformed as boolean = false
		_dataType as jsonDataType = jsonNull
		_value as string
		_error as string
		_children as jsonItem ptr ptr = 0
		_parent as JsonItem ptr = 0
		_key as string
		_count as integer = -1
		
		declare sub Parse(jsonString as byte ptr, endIndex as integer)
		declare sub SetMalformed()
		declare function AppendChild(newChild as JsonItem ptr) as boolean
		declare sub setErrorMessage(errorCode as fbJsonInternal.jsonError, jsonstring as byte ptr, position as uinteger)
	public:
		declare static function ParseJson(inputString as string) byref as JsonItem
		declare constructor()
		declare constructor(byref jsonString as string)
		
		declare destructor()
		
		declare property Key () as string
		declare property Key (value as string)
		
		declare property Value(byref newValue as string)
		declare property Value() as string
		
		declare property Count() as integer
		declare property DataType() as jsonDataType
		
		declare operator [](key as string) byref as JsonItem
		declare operator [](index as integer) byref as JsonItem
		
		declare property Parent() byref as JsonItem
		
		declare operator LET(A as JsonItem)
		
		declare sub Parse(jsonString as string)
		
		declare function ToString(level as integer = 0) as string
		
		declare function AddItem(key as string, value as string) as boolean
		declare function AddItem(key as string, item as JsonItem) as boolean
		
		declare function AddItem(value as string) as boolean
		declare function AddItem(item as JsonItem) as boolean
					
		declare function RemoveItem(key as string) as boolean
		declare function RemoveItem(index as integer) as boolean
		
		declare function ContainsKey(key as string) as boolean
end type

sub JsonItem.setErrorMessage(errorCode as fbJsonInternal.jsonError, jsonstring as byte ptr, position as uinteger) 
	
	using fbJsonInternal
	dim as integer lineNumber = 1
	dim as integer linePosition = 1
	dim as integer lastBreak = 0
	dim as string lastLine
	
	for j as integer = 0 to position
		if ( jsonString[j] = 10 ) then
			lineNumber +=1
			linePosition = 1
			lastBreak = j
		end if
		linePosition +=1
	next
	select case as const errorCode
		case arrayNotClosed:
			this._error = "Array was not properly closed. Expected ']' at position "& linePosition &" on line "& lineNumber &", found '"& chr(jsonstring[position]) &"' instead."
		case objectNotClosed:
			this._error = "Object was not properly closed. Expected '}' at position "& linePosition &" on line "& lineNumber &", found '"& chr(jsonstring[position]) &"' instead."
		case stringNotClosed:
			this._error = "String value or key was not closed. Expected '""', found "& chr(jsonstring[position]) &" at position "& linePosition &" on line "& lineNumber &"."
		case invalidValue:
			this._error = "Invalid value '"& this._value &"' encountered at position "& linePosition &" on line "& lineNumber &"."
		case invalidEscapeSequence:
			this._error = "Could not de-escape '"& this._value &"' encountered at position "& linePosition &" on line "& lineNumber &"."
		case invalidNumber:
			this._error = "Invalid number '"& this._value &"' encountered at position "& linePosition &" on line "& lineNumber &"."
		case expectedKey:
			this._error = "Expected a key at position "& linePosition &" on line "& lineNumber &", found '"& chr(jsonstring[position]) &"' instead."
		case expectedValue:
			this._error = "Expected a value at position "& linePosition &" on line "& lineNumber &", found '"& chr(jsonstring[position]) &"' instead."
		case unexpectedToken:
			this._error = "Unexpected token '"& chr(jsonstring[position]) &"' at "& linePosition &" on line "& lineNumber &"."
	end select
	
	this._value = ""
	this.SetMalformed()
	#ifdef fbJSON_debug
		print "fbJSON Error: "& this._error
		end -1
	#endif
end sub

constructor JsonItem()
	' Nothing to do
end constructor

constructor JsonItem(byref jsonString as string)
	jsonString = trim(jsonString, any " "+chr(9,10) )
	this.Parse(strptr(jsonString), len(jsonstring)-1)
end constructor

destructor JsonItem()
	if (this._count >= 0 and this._children <> 0) then
		for i as integer = 0 to this._count
			delete this._children[i]
		next
		this._count = -1
		deallocate(this._children)
	end if
end destructor

operator JsonItem.LET(copy as JsonItem)
	this.destructor()
	this._key = copy._key
	this._value = copy._value
	this._dataType = copy._dataType
	this._error = copy._error
	this._isMalformed = copy._isMalformed
	this._count = copy._count
	
	if ( copy._count >= 0) then
		this._children = callocate(sizeof(jsonItem ptr) * (copy._count+1))
		for i as integer = 0 to copy._count
			this._children[i] = callocate(sizeOf(JsonItem))
			*this._children[i] = *copy._children[i]
		next
	end if
end operator

operator JsonItem.[](newKey as string) byref as JsonItem	
	if ( this._datatype = jsonObject and this._count > -1 ) then
		for i as integer = 0 to this._count
			if ( this._children[i]->_key = newkey ) then
				return *this._children[i]
			end if
		next
	end if
	
	#ifdef fbJSON_debug
		print "fbJSON Error: Key '"& key & "' not found in object "& this.key
		end -1
	#endif
	return *new JsonItem()
end operator

operator JsonItem.[](index as integer) byref as JsonItem
	if ( index <= this._count ) then
		return *this._children[index]
	end if
	
	#ifdef fbJSON_debug
		print "fbJSON Error: "& index & " out of bounds in "& this.key &". Actual size is "& this.count
		end -1
	#else
		return *new JsonItem()
	#endif
end operator

property JsonItem.Key() as string
	return this._key
end property

property JsonItem.Key(newkey as string)
	if ( this._key = newKey ) then return

	if ( this.Parent.ContainsKey(newKey) ) then return
	
	this._key = newKey
end property

property JsonItem.Parent() byref as JsonItem
	if ( this._parent <> 0 ) then
		return *this._parent
	end if
	
	return *new JsonItem()
end property

property JsonItem.Count() as integer
	return this._count + 1
end property

property JsonItem.DataType() as jsonDataType
	if ( this._isMalformed ) then return malformed
	return this._datatype
end property

property JsonItem.Value( byref newValue as string)
	using fbJsonInternal
	
	' TODO: Optimize this, according to the parser optimizations
	
	' First, handle strings in quotes:
	select case as const newValue[0]
	case jsonToken.Quote
		if ( newValue[len(newValue)-1] = jsonToken.Quote ) then
			this._dataType = jsonString
			this._value = mid(newValue,2, len(newValue)-2)
			if ( DeEscapeString(this._value) = false ) then
				this._isMalformed = true
			end if
		else
			this._isMalformed = true
		end if
	case 48,49,50,51,52,53,54,55,56,57 ' 0 - 9
		dim as byte lastCharacter = newValue[len(newValue)-1]
		if ( lastCharacter > 57 orElse lastCharacter < 48 ) then
			' IF the current item is already a string, we can be a little more forgiving
			' This allows for easier manipulation of items in code 
			' (because you don't have to include the quotes every time)
			' This solution is of course ugly as f..., but whatever.
			if ( this._datatype = jsonString ) then
				this._value = newValue
			else
				this._isMalformed = true
			end if
		else
			this._dataType = jsonNumber
			this._value = str(cdbl(newValue))
			if ( this._value = "0" andAlso newValue <> "0" ) then
				this._isMalformed = true
			end if
		end if
	case 110,78, 102,70, 116,84 ' n, f, t
		select case lcase(newValue)
		case "null"
			this._value = newValue
			this._dataType = jsonNull
		case "true", "false"
			this._value = newValue
			this._dataType = jsonBool
		case else:
			' strict vs. nonstrict mode?
			this._datatype = jsonString
			this._value = newValue
		end select
	end select
end property

property JsonItem.Value() as string
	return this._value
end property

function JsonItem.AddItem(newKey as string, newValue as string) as boolean
	if ( len(key) = 0 orElse this[key].datatype <> jsonNull ) then
		return false
	end if
	
	if ( this._datatype = jsonNull ) then
		this._datatype = jsonObject
	end if
	
	if ( this._datatype = jsonObject ) then
		dim child as JsonItem ptr = new JsonItem
		child->Value = newValue
		child->_key = newKey
		return this.AppendChild(child)
	end if
	return false
end function

function JsonItem.AddItem(newKey as string, item as JsonItem) as boolean
	if ( len(key) = 0 orElse this.containsKey(key) <> jsonNull ) then
		return false
	end if
	
	if ( this._datatype = jsonNull ) then
		this._datatype = jsonObject
	end if
	
	if ( this._datatype = jsonObject ) then
		dim child as JsonItem ptr = callocate(sizeof(JsonItem))
		*child = item
		child->_key = newKey
		return this.AppendChild(child)
	end if
	return false
end function

function JsonItem.AddItem(newValue as string) as boolean
	if ( this._datatype = jsonArray or this._datatype = jsonNull ) then
		this._datatype = jsonArray
		dim child as JsonItem ptr = new JsonItem
		child->value = newValue
		return this.AppendChild(child)
	end if
	return false
end function

function JsonItem.AddItem(item as JsonItem) as boolean
	if ( this._datatype = jsonArray ) then
		dim child as JsonItem ptr = callocate(sizeof(JsonItem))
		*child = item
		return this.AppendChild(child) 		
	end if
	return false
end function

function JsonItem.AppendChild(newChild as JsonItem ptr) as boolean
	if ( newChild = 0 ) then return false	
	if ( this._datatype = jsonObject ) then 
		if ( this.ContainsKey(newChild->_key) ) then
			return false
		end if
	end if
	
	newChild->_parent = @this
	this._count += 1
	
	if this._children = 0 then
		this._children = allocate(sizeof(jsonItem ptr) * (this._count+1))
	else
		this._children = reallocate(this._children, sizeof(jsonItem ptr) * (this._count+1))
	end if
	
	this._children[this._count] = newChild
	if ( newChild->_isMalformed ) then
		this.SetMalformed()
	end if
	return true
end function

function JsonItem.ContainsKey(newKey as string) as boolean
	if ( this._datatype <> jsonObject ) then return false
	
	for i as integer = 0 to this._count
		if ( this._children[i]->_key = newKey ) then
			return true
		end if
	next
	return false
end function

sub JsonItem.SetMalformed()
	this._datatype = malformed
	if (this._parent <> 0) then
		dim item as jsonItem ptr = this._parent
		do
			item->_datatype = malformed
			item = item->_parent
		loop until item = 0
	end if
end sub

sub JsonItem.Parse(jsonString as byte ptr, endIndex as integer) 
	using fbJsonInternal
	
	' Objects we will work with:
	dim currentItem as JsonItem ptr = @this
	dim as JsonItem ptr child
	
	' key states and variables for the main parsing:
	dim i as integer
	dim as uinteger parseStart = 1, parseEnd = endIndex -1
	dim as integer valueStart
	dim as parserState state
	dim as boolean isStringOpen
	
	' To handle trimming, we use these:
	dim as integer valueLength = 0
	dim as boolean trimLeftActive = false
	
	if ( jsonstring[i] = jsonToken.CurlyOpen ) then
		if ( jsonString[endIndex] = jsonToken.CurlyClose ) then
			currentItem->_datatype = jsonObject
			state = parserState.none
		else
			currentItem->setErrorMessage(objectNotClosed, jsonstring, i)
			return
		end if
	elseif ( jsonstring[i] = jsonToken.SquareOpen ) then
		if (jsonString[endIndex] = jsonToken.SquareClose ) then
			currentItem->_dataType = jsonArray
			valueStart = 1
			trimLeftActive = true
			state = valueToken
		else
			currentItem->setErrorMessage(arrayNotClosed, jsonstring, i)
			return
		end if
	else
		parseStart = 0
		parseEnd = endIndex
		state = valueToken
	end if
	
	' Abort early:
	if ( endIndex <= 1) then
		return 
	end if
		
	' Skipping the opening and closing brackets makes things a bit easier.
	for i = parseStart to parseEnd		
		' Because strings can contain json tokens, we handle them seperately:
		if ( jsonString[i] = jsonToken.Quote AndAlso (I = 0 orElse jsonString[i-1] <> jsonToken.BackSlash) ) then
			isStringOpen = not(isStringOpen)
			if ( currentItem->_datatype = jsonObject ) then
				select case as const state
				case none:
					state = keyToken
					valueStart = i+1
				case keyToken
					if child = 0  then child = new JsonItem()
					fastmid (child->_key, jsonString, valuestart,  i - valueStart)
					state = keyTokenClosed
				case else
				end select
			end if
		end if
		
		' When not in a string, we can handle the complicated suff:
		if ( isStringOpen = false ) then
			' Note: Not a single string-comparison in here. 
			select case as const jsonstring[i]
				case jsonToken.BackSlash
					currentItem->setErrorMessage(unexpectedToken, jsonstring, i)
					return

				case jsonToken.Colon:
					if ( state = keyTokenClosed ) then 
						state = valueToken
						trimLeftActive = true
						valueStart = i+1
					else
						currentItem->setErrorMessage(expectedKey, jsonstring, i)
						return
					end if
					
				case jsonToken.Comma:
					if ( state = valueToken ) then
						state = valueTokenClosed
					elseif ( state = nestEndHandled ) then
						state = resetState
					else 
						currentItem->setErrorMessage(expectedKey, jsonstring, i)
						return
					end if
					
				case jsonToken.CurlyOpen:
					if ( state = valueToken ) then
						if (child = 0) then child = new JsonItem()
						child->_datatype = jsonobject
						currentItem->AppendChild( child )
						currentItem = child
						state = resetState
					else
						currentItem->setErrorMessage(expectedKey, jsonstring, i)
						return
					end if
					
				case jsonToken.SquareOpen:
					if ( state = valueToken ) then
						if (child = 0) then child = new JsonItem()
						child->_datatype = jsonArray
						currentItem->AppendChild( child )
						currentItem = child
						state = resetState
					else
						currentItem->setErrorMessage(unexpectedToken, jsonstring, i)
						return
					end if
					
				case jsonToken.CurlyClose:
					if (currentItem->_datatype = jsonObject) then
						state = nestEnd
					else
						currentItem->setErrorMessage(arrayNotClosed, jsonstring, i)
						return
					end if					
				case jsonToken.SquareClose:
					if (currentItem->_datatype = jsonArray) then
						state = nestEnd
					else
						currentItem->setErrorMessage(unexpectedToken, jsonstring, i)
						return
					end if
					
				case jsonToken.Space, jsonToken.Tab, jsonToken.NewLine, 13
					' Here, we count the left trim we need. This is faster than using TRIM() even for a single space in front of the value
					' And most important: It's not slower if we have no whitespaces.
					if ( state = valueToken and trimLeftActive) then
						valueStart +=1
					end if
				case jsonToken.Quote
					' The closing quote get's through to here. We treat is as part of a value, but without throwing errors.
					if ( state = valueToken ) then
						valueLength +=1
						trimLeftActive = false
					end if
				case else:
					' If we are currently parsing values, add up the length and abort the trim-counting.
					if ( state = valueToken ) then
						valueLength +=1
						trimLeftActive = false
					else
						currentItem->setErrorMessage(unexpectedToken, jsonstring, i)
						return
					end if
			end select
		else
			' If we are in a string IN a value, we add up the length.
			if ( state = valueToken ) then
				valueLength +=1			
			end if
		end if	
		
		if ( i = parseEnd) then
			if ( isStringOpen ) then 
				currentItem->setErrorMessage(stringNotClosed, jsonstring, i+1)
				return 
			end if
			if ( state <> nestEnd ) then

				if (state = keyTokenClosed) then
					currentItem->setErrorMessage(expectedKey, jsonstring, i+1)
					return
				end if
						
				if ( currentItem->_parent <> 0) then
					currentItem->setErrorMessage(iif(currentItem->_datatype = jsonObject,objectNotClosed, arrayNotClosed), jsonstring, i)
					return
				end if
			
				if ( state = valueToken and valueLength > 0 ) then
					state = valueTokenClosed					
				end if
			end if
			if ( state = valueToken ) then
				currentItem->setErrorMessage(expectedValue, jsonstring, i+1)
				return
			end if
		end if
		
		if (state = valueTokenClosed orElse state = nestEnd) then			
			' because we already know how long the string we are going to parse is, we can skip if it's 0.
			if ( valueLength <> 0 ) then
				if (child = 0) then child = new JsonItem()
				' The time saved with this is miniscule, but reliably measurable.		
				select case as const jsonstring[valuestart]
				case jsonToken.Quote
					if ( jsonstring[valueStart+valueLength-1] ) then
						FastMid(child->_value, jsonString, valuestart+1, valueLength-2)
						child->_dataType = jsonDataType.jsonString
						if ( instr(child->_value, "\") <> 0 ) then 
							if ( DeEscapeString(child->_value) = false ) then
								FastMid(child->_value, jsonString, valuestart+1, valueLength-2)
								child->setErrorMessage(invalidEscapeSequence, jsonstring, i)
							end if
						end if
					else
						FastMid(child->_value, jsonString, valuestart, valueLength)
						child->setErrorMessage(stringNotClosed, jsonstring, i)
					end if
				case 110,78, 102,70, 116,84 ' n,N f,F t,T
					' Nesting "select-case" isn't pretty, but fast. Saw this first in the .net compiler.
					FastMid(child->_value, jsonString, valuestart, valueLength)
					select case lcase(child->_value)
						case "null"
							child->_dataType = jsonNull
						case "true", "false"
							child->_dataType = jsonBool
						case else
							FastMid(child->_value, jsonString, valuestart, valueLength)
							' Invalid value or missing quotation marks							
							child->setErrorMessage(invalidValue, jsonstring, i)
					end select
				case jsonToken.minus, 48,49,50,51,52,53,54,55,56,57:
					dim as byte lastCharacter = jsonstring[valuestart+valueLength-1]
					if ( lastCharacter >= 48 and lastCharacter <= 57) then
						FastMid(child->_value, jsonString, valuestart, valueLength)
						
						child->_value = str(cdbl(child->_value))
						child->_dataType = jsonNumber
						if ( child->_value = "0" andAlso child->_value <> "0" ) then
							child->setErrorMessage(invalidNumber, jsonstring, i)
						end if
					else
						child->setErrorMessage(invalidValue, jsonstring, i)
					end if
				case jsonToken.SquareClose
				
				case else
					FastMid(child->_value, jsonString, valuestart, valueLength)
					child->setErrorMessage(invalidValue, jsonstring, i)
				end select
				
				if (child->_datatype = malformed) then					
					if (currentItem->_datatype <> jsonObject andAlso currentItem->_dataType <> jsonArray ) then						
						delete child
					else
						currentItem->AppendChild(child)
					end if
					currentItem->SetMalformed()
					return
				end if
				if (currentItem->_datatype <> jsonObject andAlso currentItem->_dataType <> jsonArray ) then
					this._value = child->_value
					this._datatype = child->_datatype
					this._error = child->_error
					delete child
				else
					currentItem->AppendChild(child)
				end if
			else
				if state <> nestEnd then
					if (child <> 0) then
						child->setErrorMessage(arrayNotClosed, jsonstring, i)
					else
						currentItem->setErrorMessage(arrayNotClosed, jsonstring, i)
					end if
					return
				end if
			end if
			valueLength = 0
			if state = nestEnd then
				currentItem = currentItem->_parent
				state = nestEndHandled 
			else
				state = resetState
			end if
		end if
		
		if( state = resetState) then
			valueLength = 0
			child = 0
			if ( currentItem->_datatype = jsonArray ) then
				state = valueToken
				valueStart = i+1
				trimLeftActive = true
			else
				trimLeftActive = false
				state = none
			end if
		end if
	next
end sub

sub JsonItem.Parse( inputString as string)
	this.destructor()
	this.Parse( cast (byte ptr, strptr(inputstring)), len(inputString)-1)
end sub

function JsonItem.RemoveItem(newKey as string) as boolean
	dim as integer index = -1
	
	if ( this._datatype = jsonObject ) then
		for i as integer = 0 to this._count
			if ( this._children[i]->_key = newkey ) then
				index = i
				exit for
			end if
		next
	end if
	
	return this.RemoveItem(index)
end function

function JsonItem.RemoveItem(index as integer) as boolean
	if ( index <= this._count andAlso index > -1 ) then
		delete this._children[index]
		if ( index < this.Count -1 ) then
			for i as integer = index to this._count 
				this._children[i] = this._children[i+1]
			next
		end if
		
		this._count -= 1
		this._children = reallocate(this._children, sizeof(jsonItem ptr) * this._count)
		
		return true
	end if
	return false
end function

function JsonItem.ToString(level as integer = 0) as string
	dim as string result
	
	' TODO: Clean up this mess.
	
	if this.datatype = jsonObject  then
		result = "{"
	elseif ( this.datatype = jsonArray ) then
		result = "["
	end if
		
	for i as integer = 0 to this._count 
		if ( this.datatype = jsonObject ) then
			result += """" & this[i]._key & """ : " 
		end if
		
		if ( this[i].Count >= 0 ) then
			result += this[i].toString(level+1)
		else			
			if ( this[i].datatype = jsonString) then
				result += """"
			end if
			
			result += this[i]._value
			
			if ( this[i].datatype = jsonString) then
				result += """"
			end if
		end if
		if ( i < this.Count - 1 ) then
			result += ","
		else
			level -= 1
		end if
		
	next
	
	if this.datatype = jsonObject  then
		result += "}"
	elseif ( this.datatype = jsonArray ) then
		result += "]"
	end if
	
	return result
end function
