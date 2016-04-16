#include once "JsonDatatype.bi"
#include once "StringFunctions.bi"

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

type jsonItem 
	protected:
		_isMalformed as boolean = false
		_dataType as jsonDataType = jsonNull
		_value as string
		_error as string
		_children(any) as jsonItem ptr
		_parent as jsonItem ptr
		_key as string
		
		declare sub Parse(jsonString as byte ptr, endIndex as integer) 
		declare function AppendChild(newChild as jsonItem ptr) as boolean
	public:
		declare constructor()
		declare constructor(byref jsonString as string)
		
		declare destructor()
		
		declare property Key () as string
		declare property Key (value as string)
		
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
	this.Parse(strptr(jsonString), len(jsonstring)-1)
end constructor

destructor jsonItem()
	this._value = ""
	for i as integer = 0 to ubound(this._children)
		delete this._children(i)
	next
end destructor

operator jsonItem.LET(copy as jsonItem)
	this.destructor()
	this._key = copy._key
	this._value = copy._value
	this._dataType = copy._dataType
	this._error = copy._error
	this._isMalformed = copy._isMalformed 
	
	if (ubound(copy._children) >= 0) then
		redim this._children(ubound(copy._children))
		for i as integer = 0 to ubound(copy._children)
			this._children(i) = callocate(sizeOf(jsonItem))
			*this._children(i) = *copy._children(i)
		next
	end if
end operator

property jsonItem.Key() as string
	return this._key
end property

property jsonItem.Key(newkey as string)
	if ( this._key = newKey ) then return

	if ( this.Parent.ContainsKey(newKey) ) then return
	
	this._key = newKey
end property

property jsonItem.Parent() byref as jsonItem
	if ( this._parent <> 0 ) then
		return *this._parent
	end if
	
	return *new jsonItem()
end property

operator jsonItem.[](newKey as string) byref as jsonItem	
	if ( this._datatype = jsonObject ) then
		for i as integer = 0 to ubound(this._children)
			if ( this._children(i)->_key = newkey ) then
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
	if ( this._isMalformed ) then return malformed
	return this._datatype
end property

property jsonItem.Value( byref newValue as string)
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

property jsonItem.Value() as string
	return this._value
end property

sub jsonItem.Parse(jsonString as byte ptr, endIndex as integer) 
	using fbJsonInternal
	
	' Objects we will work with:
	dim currentItem as jsonItem ptr = @this
	dim as jsonItem ptr child '= new jsonItem
	
	' key states and variables for the main parsing:
	dim i as integer
	dim as integer valueStart
	dim as parserState state
	dim as boolean isStringOpen
	
	' To handle trimming, we use these:
	dim as integer valueLength = 0
	dim as boolean trimLeftActive = false
	
	dim as byte character = peek(ubyte, jsonstring)
	
	if ( character = jsonToken.CurlyOpen andAlso jsonString[endIndex] = jsonToken.CurlyClose ) then
		currentItem->_datatype = jsonObject
		state = parserState.none
	elseif ( character = jsonToken.SquareOpen andAlso jsonString[endIndex] = jsonToken.SquareClose ) then
		currentItem->_dataType = jsonArray
		valueStart = 1
		trimLeftActive = true
		state = valueToken
	else
		this._isMalformed = true
		return
	end if
	
		' Abort early:
	if ( endIndex <= 1) then
		delete child
		return 
	end if
		
	' Skipping the opening and closing brackets makes things a bit easier.
	for i = 1 to endIndex-1
		character = peek(ubyte, jsonString + i)
		
		' Because strings can contain json tokens, we handle them seperately:
		if ( character = jsonToken.Quote AndAlso jsonString[i-1] <> jsonToken.BackSlash ) then
			isStringOpen = not(isStringOpen)
			if ( currentItem->_datatype = jsonObject ) then
				select case as const state
				case none:
					state = keyToken
					valueStart = i+1
				case keyToken
					if child = 0  then child = new jsonItem()
					fastmid (child->_key, jsonString, valuestart,  i - valueStart)
					state = keyTokenClosed
				case else
				end select
			end if
		end if
		
		' When not in a string, we can handle the complicated suff:
		if ( isStringOpen = false ) then
			' Note: Not a single string-comparison in here. 
			select case as const character
				case jsonToken.BackSlash
					goto errorHandling

				case jsonToken.Colon:
					if ( state = keyTokenClosed ) then 
						state = valueToken
						trimLeftActive = true
						valueStart = i+1
					end if
					
				case jsonToken.Comma:
					if ( state = valueToken ) then
						state = valueTokenClosed
					elseif ( state = nestEndHandled ) then
						state = resetState
					end if
					
				case jsonToken.CurlyOpen:
					if ( state = valueToken ) then
						if (child = 0) then child = new jsonItem()
						child->_datatype = jsonobject
						currentItem->AppendChild( child )
						currentItem = child
						state = resetState
					else
						goto errorHandling
					end if
					
				case jsonToken.SquareOpen:
					if ( state = valueToken ) then
						if (child = 0) then child = new jsonItem()
						child->_datatype = jsonArray
						currentItem->AppendChild( child )
						currentItem = child
						state = resetState
					else
						goto errorHandling
					end if
					
				case jsonToken.CurlyClose:
					if ( currentItem->_parent <> 0 andAlso currentItem->_datatype = jsonObject) then
						state = nestEnd
						
					else
						goto errorHandling
					end if					
				case jsonToken.SquareClose:
					if ( currentItem->_parent <> 0 andAlso currentItem->_datatype = jsonArray) then
						state = nestEnd
					else
						goto errorHandling
					end if
					
				case jsonToken.Space, jsonToken.Tab, jsonToken.NewLine, 13
					' Here, we count the left trim we need. This is faster than using TRIM() even for a single space in front of the value
					' And most important: It's not slower if we have no whitespaces.
					if ( state = valueToken ) then
						if ( trimLeftActive = true) then
							valueStart +=1
						end if
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
						' If not in value parsing, we have invalid JSON at this point.
						goto errorHandling
					end if
			end select
		else
			' If we are in a string IN a value, we add up the length.
			if ( state = valueToken ) then
				valueLength +=1			
			end if
		end if	
		
		if ( i = endIndex -1) then
			if ( isStringOpen ) then goto errorHandling
			if ( state <> nestEnd ) then
				if ( currentItem->_parent <> 0 andAlso state <> valueToken ) then
					goto errorHandling
				end if
			
				if ( state = valueToken and valueLength > 0 ) then
					state = valueTokenClosed					
				end if
			end if
			if ( state = valueToken ) then
				goto errorHandling
			end if
		end if

		if ( state = valueTokenClosed orElse state = nestEnd ) then
			' because we already know how long the string we are going to parse is, we can skip if it's 0.
			if ( valueLength <> 0 ) then
				if (child = 0) then child = new jsonItem()
				' The time saved with this is miniscule, but reliably measurable.		
				select case as const jsonstring[valuestart]
				case jsonToken.Quote
					if ( jsonstring[valueStart+valueLength-1] ) then
						FastMid(child->_value, jsonString, valuestart+1, valueLength-2)
						child->_dataType = jsonDataType.jsonString
						if ( instr(child->_value, "\") <> 0 ) then 
							if ( DeEscapeString(child->_value) = false ) then
								goto errorHandling
							end if
						end if
					else
						goto errorHandling
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
							child->_value = ""
							goto errorHandling
					end select
				case jsonToken.minus, jsonToken.plus, 48,49,50,51,52,53,54,55,56,57:
					dim as byte lastCharacter = jsonstring[valuestart+valueLength-1]
					if ( lastCharacter <= 57 andAlso lastCharacter >= 48 ) then
						
						FastMid(child->_value, jsonString, valuestart, valueLength)
						? child->_value
						child->_dataType = jsonNumber
						child->_value = str(cdbl(child->_value))
						if ( child->_value = "0" andAlso child->_value <> "0" ) then
							goto errorHandling
						end if
					else
						goto errorHandling
					end if
				case jsonToken.SquareClose
				case else
					 goto errorHandling
				end select
				
				currentItem->AppendChild(child)
			else
				if state <> nestEnd then
					goto errorHandling
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
		
		if ( state = resetState ) then
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
	return
	
	errorHandling:
		dim as integer lineNumber = 1
		dim as integer position = 1
		dim as integer lastBreak = 0
		dim as string lastLine
		for j as integer = 0 to i
			if ( jsonString[j] = 10 ) then
				lineNumber +=1
				position = 1
				lastBreak = j
			end if
			position +=1
		next

		if ( isStringOpen ) then
			currentItem->_error = "Expected closing quote, found: "+ chr(character) + "' in line "& lineNumber &" at position " & position
		else
			currentItem->_error = "Unexpected token '"+ chr(character) + "' in line "& lineNumber &" at position " & position & "."
		end if
		#ifdef fbJson_DEBUG
			fastmid(lastLine,jsonString, lastBreak +1, i - lastBreak +1)
			print lastLine
			print space(position-3) + "^"
			print "fbJSON Error: " & currentItem->_error, state, valueLength
		#endif
		if ( child <> 0 andAlso child->_parent = 0) then
			delete child
		end if
		currentItem->_isMalformed = true
		return
end sub

function jsonItem.ToString(level as integer = 0) as string
	dim as string result
	
	' TODO: Clean up this mess.
	
	if this.datatype = jsonObject  then
		result = "{"
	elseif ( this.datatype = jsonArray ) then
		result = "["
	end if
		
	for i as integer = 0 to this.count - 1
		if ( this.datatype = jsonObject ) then
			result += """" & this[i]._key & """ : " 
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

function JsonItem.AddItem(newKey as string, newValue as string) as boolean
	if ( len(key) = 0 orElse this[key].datatype <> jsonNull ) then
		return false
	end if
	
	if ( this._datatype = jsonNull ) then
		this._datatype = jsonObject
	end if
	
	if ( this._datatype = jsonObject ) then
		dim child as JsonItem ptr = new jsonItem
		child->Value = newValue
		child->_key = newKey
		return this.AppendChild(child)
	end if
	return false
end function

function JsonItem.AddItem(newKey as string, item as jsonItem) as boolean
	if ( len(key) = 0 orElse this.containsKey(key) <> jsonNull ) then
		return false
	end if
	
	if ( this._datatype = jsonNull ) then
		this._datatype = jsonObject
	end if
	
	if ( this._datatype = jsonObject ) then
		dim child as JsonItem ptr = callocate(sizeof(jsonItem))
		*child = item
		child->_key = newKey
		return this.AppendChild(child)
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
	if ( newChild = 0 ) then return false	
	if ( this._datatype = jsonObject ) then 
		if ( cbool(len(newChild->_key) = 0) OrElse this.ContainsKey(newChild->_key) ) then
			return false
		end if
	end if
	
	newChild->_parent = @this
	dim as uinteger size = ubound(this._children)+1
	redim preserve this._children(size)
	this._children(size) = newChild
	if ( newChild->_isMalformed ) then
		this._isMalformed = true
	end if
	return true
end function

function JsonItem.RemoveItem(newKey as string) as boolean
	dim as integer index = -1
	
	if ( this._datatype = jsonObject ) then
		for i as integer = 0 to ubound(this._children)
			if ( this._children(i)->_key = newkey ) then
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

function JsonItem.ContainsKey(newKey as string) as boolean
	if ( this._datatype <> jsonObject ) then return false
		
	for i as integer = 0 to ubound(this._children)
		if ( this._children(i)->_key = newKey ) then
			return true
		end if
	next
	return false
end function
