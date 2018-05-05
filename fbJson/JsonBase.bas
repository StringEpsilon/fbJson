/'	
	This Source Code Form is subject to the terms of the Mozilla Public
	License, v. 2.0. If a copy of the MPL was not distributed with this
	file, You can obtain one at http://mozilla.org/MPL/2.0/. 
'/

#include once "JsonBase.bi"
#include once "StringFunctions.bi"

sub JsonBase.setErrorMessage(errorCode as fbJsonInternal.jsonError, jsonstring as byte ptr, position as uinteger) 
	using fbJsonInternal
	dim as integer lineNumber = 1
	dim as integer linePosition = 0
	dim as integer lastBreak = 0
	dim as string lastLine
	
	for j as integer = 0 to position
		if ( jsonString[j] = 10 ) then
			lineNumber +=1
			linePosition = 0
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
		case invalidCodepoint
			this._error = "Invalid UTF-8 bytesequence encountered: "& hex(jsonstring[position])  &"' at "& linePosition &" on line "& lineNumber &"."
	end select
	
	this._value = ""
	this.SetMalformed()
	#ifdef fbJSON_debug
		print "fbJSON Error: "& this._error
		'end -1
	#endif
end sub

constructor JsonBase()
	' Nothing to do
end constructor

constructor JsonBase(byref jsonString as string)
	jsonString = trim(jsonString, any " "+chr(9,10) )
	this.Parse(strptr(jsonString), len(jsonstring)-1)
end constructor

destructor JsonBase()
	if (this._count >= 0 and this._children <> 0) then
		for i as integer = 0 to this._count
			delete this._children[i]
		next
		this._count = -1
		deallocate(this._children)
	end if
end destructor

operator JsonBase.LET(copy as JsonBase)
	this.destructor()
	fbJsonInternal.FastCopy(this._key, copy._key)
	fbJsonInternal.FastCopy(this._value, copy._value)
	
	this._dataType = copy._dataType
	this._error = copy._error
	this._count = copy._count
	
	if ( copy._count >= 0) then
		this._children = allocate(sizeof(JsonBase ptr) * (copy._count+1))
		for i as integer = 0 to copy._count
			this._children[i] = callocate(sizeOf(JsonBase))
			*this._children[i] = *copy._children[i]
		next
	end if
end operator

property JsonBase.Parent() byref as JsonBase
	if ( this._parent <> 0 ) then
		return *this._parent
	end if
	
	return *new JsonBase()
end property

property JsonBase.Count() as integer
	return this._count + 1
end property

property JsonBase.DataType() as jsonDataType
	return this._datatype
end property

function JsonBase.AppendChild(newChild as JsonBase ptr, override as boolean = false) as boolean
	if ( newChild = 0 ) then return false	
	if ( this._datatype = jsonObject ) then 
		for i as integer = 0 to this._count
			if ( fbJsonInternal.AreEqual(this._children[i]->_key, newChild->_key) ) then
				if (override) then
					delete this._children[i]
					newChild->_parent = @this
					this._children[i] = newChild
					return true
				else 
					return false
				end if
			end if
		next
	end if
	
	newChild->_parent = @this
	this._count += 1
	
	' I think allocating 2 elements at a time is a decent compromise between memory and speed.
	' And it does cut the number of reallocations in half.
	if (this._count mod 2 = 0) then
		if this._children = 0 then
			this._children = allocate(sizeof(JsonBase ptr) * (this._count+2))
		else
			this._children = reallocate(this._children, sizeof(JsonBase ptr) * (this._count+2))
		end if
		
		if this._children = 0 then
			this.setMalformed()
			return false
		end if
	end if
	this._children[this._count] = newChild
	
	if ( newChild->_datatype = malformed ) then
		this.SetMalformed()
	end if
	return true
end function

function JsonBase.ContainsKey(byref newKey as string) as boolean
	if ( this._datatype <> jsonObject ) then return false
	
	for i as integer = 0 to this._count
		if ( fbJsonInternal.areEqual(this._children[i]->_key, newKey ) ) then
			return true
		end if
	next
	return false
end function

sub JsonBase.SetMalformed()
	this._datatype = malformed
	if (this._parent <> 0) then
		dim item as JsonBase ptr = this._parent
		item->_error = this._error
		do
			if (item->_parent <> 0) then
				item->_parent->_error = item->_error
			end if
			item->_datatype = malformed
			item = item->_parent
			
		loop until item = 0
	end if
end sub

sub JsonBase.Parse(jsonString as ubyte ptr, endIndex as integer) 
	using fbJsonInternal
	if (endIndex < 0) then
		this.setMalformed()
		this._error = "No data!"
		return
	end if
	
	
	' Objects we will work with:
	dim currentItem as JsonBase ptr = @this
	dim as JsonBase ptr child
	
	' key states and variables for the main parsing:
	dim as uinteger parseStart = 1, parseEnd = endIndex -1
	dim as integer valueStart
	dim as parserState state
	dim as boolean isStringOpen
	dim as byte unicodeSequence
	dim as boolean isEscaped = false
	
	' To handle trimming, we use these:
	dim as integer valueLength = 0
	dim as boolean trimLeftActive = false
	
	if ( jsonstring[0] = jsonToken.CurlyOpen ) then
		if ( jsonString[endIndex] = jsonToken.CurlyClose ) then
			currentItem->_datatype = jsonObject
			state = parserState.none
		else
			currentItem->setErrorMessage(objectNotClosed, jsonstring, endIndex)
			return
		end if
	elseif ( jsonstring[0] = jsonToken.SquareOpen ) then
		if (jsonString[endIndex] = jsonToken.SquareClose ) then
			currentItem->_dataType = jsonArray
			valueStart = 1
			trimLeftActive = true
			state = valueToken
		else
			currentItem->setErrorMessage(arrayNotClosed, jsonstring, endIndex)
			return
		end if
	else
		parseStart = 0
		parseEnd = endIndex
		state = valueToken
	end if
			
	' Skipping the opening and closing brackets makes things a bit easier.
	for i as integer = parseStart to parseEnd
		select case as const jsonstring[i]		
			' These codepoints are straight up invalid no matter what:
			case 192, 193, 245 to 255:
				currentItem->setErrorMessage(invalidCodepoint, jsonstring, i)
				goto cleanup
			case 237
				' TODO Validate against surrogate pairs, which are invalid in UTF-8.
				currentItem->setErrorMessage(invalidCodepoint, jsonstring, i)
				goto cleanup
			case else
				' UTF-8 length validation:
				if ( jsonstring[i] > 127 andAlso jsonstring[i] SHR 6 = &b10 ) then
					unicodeSequence -= 1
					if (unicodeSequence < 0 ) then
						currentItem->setErrorMessage(invalidCodepoint, jsonstring, i)
						goto cleanup
					end if
				else
					if (unicodeSequence > 0) then
						currentItem->setErrorMessage(invalidCodepoint, jsonstring, i)
						goto cleanup
					end if
					select case as const jsonString[i] ' shr 4 
						case 192 to 223
							unicodeSequence = 1
						case 224 to 239
							unicodeSequence = 2
						case 240 to 247
							unicodeSequence = 3
						case else
							unicodeSequence = 0
					end select
				end if
		end select
			
		' Because strings can contain json tokens, we handle them seperately:
		if ( jsonString[i] = jsonToken.Quote andAlso isEscaped = false) then
			isStringOpen = not(isStringOpen)
			if ( currentItem->_datatype = jsonObject ) then
				if state = none then
					state = keyToken
					valueStart = i+1
				elseif state = keyToken then
					child = new JsonBase()
					fastmid(child->_key, jsonString, valuestart,  i - valueStart)
					if ( isInString(child->_key, jsonToken.backslash) <> 0 ) then
						if ( DeEscapeString(child->_key) = false ) then
							child->setErrorMessage(invalidEscapeSequence, jsonstring, i)
						end if
					end if
					state = keyTokenClosed
				end if
			end if
		end if
		
		' When not in a string, we can handle the complicated suff:
		if ( isStringOpen = false ) then
			' Note: Not a single string-comparison in here.
			select case as const jsonstring[i]
				case jsonToken.BackSlash
					currentItem->setErrorMessage(unexpectedToken, jsonstring, i)
					goto cleanup

				case jsonToken.Colon:
					if ( state = keyTokenClosed ) then 
						state = valueToken
						trimLeftActive = true
						valueStart = i+1
					else
						currentItem->setErrorMessage(expectedKey, jsonstring, i)
						goto cleanup
					end if
					
				case jsonToken.Comma:
					if (i = parseEnd) then
						currentItem->setErrorMessage(unexpectedToken, jsonstring, i)
						goto cleanup
					end if

					if ( state = valueToken ) then
						state = valueTokenClosed
						if (valueLength = 0) then
							currentItem->setErrorMessage(unexpectedToken, jsonstring, i)
							goto cleanup
						end if
					elseif ( state = nestEndHandled ) then
						state = resetState
					else 
						currentItem->setErrorMessage(expectedKey, jsonstring, i)
						goto cleanup
					end if
					
				case jsonToken.CurlyOpen:
					if ( state = valueToken ) then
						if (child = 0) then child = new JsonBase()
						child->_datatype = jsonobject
						currentItem->AppendChild( child , true)
						currentItem = child
						state = resetState
					else
						currentItem->setErrorMessage(expectedKey, jsonstring, i)
						goto cleanup
					end if
					
				case jsonToken.SquareOpen:
					if ( state = valueToken andAlso valueLength = 0 ) then
						if (child = 0) then child = new JsonBase()
						child->_datatype = jsonArray
						currentItem->AppendChild( child , true)
						currentItem = child
						state = resetState
					else
						currentItem->setErrorMessage(unexpectedToken, jsonstring, i)
						goto cleanup
					end if
					
				case jsonToken.CurlyClose:
					if (currentItem->_datatype = jsonObject) then
						state = nestEnd
					else
						currentItem->setErrorMessage(arrayNotClosed, jsonstring, i)
						goto cleanup
					end if
							
				case jsonToken.SquareClose:
					if (currentItem->_datatype = jsonArray ) then
						state = nestEnd
					else
						currentItem->setErrorMessage(unexpectedToken, jsonstring, i)
						goto cleanup
					end if
					
				case jsonToken.Space, jsonToken.Tab, jsonToken.NewLine, 13
					' Here, we count the left trim we need. This is faster than using TRIM() even for a single space in front of the value
					' And most important: It's not slower if we have no whitespaces.
					if ( state = valueToken andAlso trimLeftActive) then
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
						goto cleanup
					end if
			end select
		else
			if (jsonString[i] = 92 andAlso isEscaped = false) then
				isEscaped = true
			else
				isEscaped = false
			end if
			
			select case as const jsonString[i]
				case 0 to 31
					currentItem->setErrorMessage(unexpectedToken, jsonstring, i)
					goto cleanup
			end select

			' If we are in a string IN a value, we add up the length.
			if ( state = valueToken ) then
				valueLength +=1
			end if
			
			if (i = parseEnd) then
				currentItem->setErrorMessage(stringNotClosed, jsonstring, i+1)
				goto cleanup 
			end if
			
			continue for
		end if	
		
		if ( i = parseEnd andAlso  state <> nestEnd) then
			if (state = keyTokenClosed) then
				currentItem->setErrorMessage(expectedKey, jsonstring, i+1)
				goto cleanup
			end if
					
			if ( currentItem->_parent <> 0) then
				currentItem->setErrorMessage(iif(currentItem->_datatype = jsonObject,objectNotClosed, arrayNotClosed), jsonstring, i)
				goto cleanup
			end if
		
			if ( state = valueToken ) then
				if (valueLength > 0 ) then
					state = valueTokenClosed
				else
					currentItem->setErrorMessage(expectedValue, jsonstring, i+1)
					goto cleanup
				end if
			end if
		end if
		
		select case as const state
			case valueTokenClosed, nestEnd
				' because we already know how long the string we are going to parse is, we can skip if it's 0.
				if ( valueLength > 0 ) then
					if (child = 0) then child = new JsonBase()
					' The time saved with this is miniscule, but reliably measurable.
					select case as const jsonstring[valuestart]
						case jsonToken.Quote
							if ( jsonstring[valueStart+valueLength-1] <> jsonToken.Quote ) then
								currentItem->setErrorMessage(unexpectedToken, jsonstring, i)
								goto cleanup
							end if
							FastMid(child->_value, jsonString, valuestart+1, valueLength-2)
							child->_dataType = jsonDataType.jsonString
							if ( isinstring(child->_value, jsonToken.backslash) <> 0 ) then 
								if ( child->_value <> "" andAlso DeEscapeString(child->_value) = false ) then
									child->setErrorMessage(invalidEscapeSequence, jsonstring, i)
								end if
							end if

						case 110, 102, 116 ' n f t
							' Nesting "select-case" isn't pretty, but fast. Saw this first in the .net compiler.
							FastMid(child->_value, jsonString, valuestart, valueLength)
							select case child->_value
								case "null"
									child->_dataType = jsonNull
								case "true", "false"
									child->_dataType = jsonBool
								case else
									' Invalid value or missing quotation marks
									child->setErrorMessage(invalidValue, jsonstring, valueStart)
							end select
							
						case jsonToken.minus, 48 to 57:
							fastMid(child->_value, jsonString, valuestart, valueLength)
							if ( isValidDouble(child->_value) ) then
								child->_dataType = jsonDataType.jsonNumber
							else
								child->setErrorMessage(invalidNumber, jsonstring, i)
							end if
													
						case else
							FastMid(child->_value, jsonString, valuestart, valueLength)
							child->setErrorMessage(invalidValue, jsonstring, i)
					end select
					
					if (currentItem->_datatype <> jsonObject andAlso currentItem->_dataType <> jsonArray ) then
						if (i = parseEnd and child->_datatype <> malformed) then
							FastCopy(this._value, child->_value)
							this._datatype = child->_datatype
							this._error = child->_error
							delete child
						else
							currentItem->setErrorMessage(0, jsonstring, i+1)
							goto cleanup
						end if
						child = 0
					else
						if (child->_datatype = malformed) then
							currentItem->SetMalformed()
						end if
						currentItem->AppendChild(child, true)
					end if
					valueLength = 0
				end if
				
				if state = nestEnd then
					if (currentItem = 0 or currentItem->_parent = 0) then
						this.setMalformed()
						return
					end if
					
					currentItem = currentItem->_parent
					state = nestEndHandled
				else
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
		
			case resetState:
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
		end select
	next
	
	return
	
	cleanup:
		if (child <> 0) then
			delete child
		end if
end sub

sub JsonBase.Parse( inputString as string)
	this.destructor()
	this.constructor()
	inputString = trim(inputString, any !" \9\10")
	this.Parse( cast (byte ptr, strptr(inputstring)), len(inputString)-1)
end sub

function JsonBase.getError() as string
	return this._error
end function
