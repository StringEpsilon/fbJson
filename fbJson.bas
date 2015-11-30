#include once "fbJsonItem.bi"


enum parserState
	none = -1
	keyToken = 0
	valueToken
	stringToken
	arrayToken
	arrayTokenClosed
	objectToken
	objectTokenClosed
end enum



declare function parseObject(byref jsonString as string, startIndex as integer, endIndex as integer) as jsonItem ptr


dim as integer ff = freefile()

dim as string inputLine 
dim as string jsonFile

open "test.json" for input as #ff 
	while (not eof(ff))
		line input #ff, inputLine 
		jsonFile += inputLine + chr(10)
	wend
close #ff
trim(jsonFile, chr(10))

dim as jsonItem ptr token = parseObject(jsonFile, 1, len(jsonFile))

sub WriteParserError(byref jsonString as string, index as integer, state as parserState, stateStart as integer )
	dim as integer lineNumber = 1
	for i as integer = 0 to index
		if (jsonString[i] = 10) then lineNumber +=1
	next
	dim as string message = "Error unexpected token '"+ chr(jsonString[index]) + "' in line "& lineNumber &" [ "
	select case state
	case valueToken
		message += "value"
	case stringToken
		message += "string"
	case arrayToken
		message += "array"
	case arrayTokenClosed
		message += "array closed"
	case objectToken
		message += "object"
	case objectTokenClosed
		message += "object closed"
	end select
	message += " ] from " & chr(jsonString[stateStart])
	print message
end sub

function parseObject(byref jsonString as string, startIndex as integer, endIndex as integer) as jsonItem ptr
	dim as jsonItem ptr item = new jsonItem()
	dim as parserState state = none
	dim as jsonItem ptr child
	dim as integer stateStart
	dim as boolean escaped = false
	dim as boolean stringOpen = false

	for i as integer = startIndex to endIndex
		select case chr(jsonString[i])
			case ":":
				if ( stringOpen = false) then
					if (state = keyToken) then
						child = new jsonItem
						child->Key = mid(jsonString, stateStart, i+1 - stateStart)  
						state = valueToken
						stateStart = i+2
					elseif (state <> objectToken) then
						WriteParserError(jsonString, i, state, stateStart)
					end if
				end if
			case ",":
				if (stringOpen = false) then
					if (state = valueToken OR state = stringToken) then
						item->value = mid(jsonString, stateStart, i+1 - stateStart)
					end if
					if (state <> objectToken and state <> arrayToken ) then
						stateStart = i
						state = none
					end if
				end if
			case """":
				if (not escaped) then
					stringOpen = not(stringOpen)
					if (stringOpen = true) then
						if (state = none ) then 
							state = keyToken
							stateStart = i+1
						elseif (state = valueToken) then
							state = stringToken
							stateStart = i+1
						end if
					end if
				else
					escaped = false
				end if
			case "\":
				escaped = true
			case "{":
				if (not stringOpen) then
					if ( state = valueToken ) then
						state = objectToken
						stateStart = i+1
					end if
				end if
			case "}"
				if (stringOpen = false) then
					if ( state = objectToken ) then
						state = objectTokenClosed
						child = parseObject(jsonString, stateStart, i)
						
						redim item->children(ubound(child->children))
						for i as integer = 0 to ubound(child->children)
							item->children(i) = child->children(i)
						next
						delete(child)
						child = 0
					elseif (state <> valueToken and state <> stringToken) then
						WriteParserError(jsonString, i, state, stateStart)
					end if
				end if
			case "[":
				if (stringOpen = false) then
					if (state = valueToken) then	
						state = arrayToken
					elseif (state < arrayToken) then
						WriteParserError(jsonString, i, state, stateStart)
					end if
				end if
			case "]":
				if (stringOpen = false) then
					if (state = arrayToken) then
						state = valueToken
					end if
				end if
		end select
		
		if (i = endIndex) then
			if (state = valueToken OR state = stringToken) then
				item->value = mid(jsonString, stateStart, i-2 - stateStart)
			else
				WriteParserError(jsonString, stateStart, state, stateStart)
			end if
		end if
		
		if ( child <> 0 ) then
			redim preserve item->children(ubound(item->children)+1)
			item->children(ubound(item->children)) = child
			child->parent = item
			item = child
			child = 0
		end if
		
		if (state = none) then
			if (item->parent <> 0) then
				item = item->parent	
			end if
		end if
	next
	
	if (item->parent <> 0) then
		item = item->parent
	end if
	return item
end function

for i as integer = 0 to ubound(token->children)
	? "item: "& token->children(i)->key & " = " & token->children(i)->value
	if ubound(token->children(i)->children) >= 0 then
		for j as integer = 0 to ubound(token->children(i)->children)
			? "    item: " & token->children(i)->children(j)->key & " = " & token->children(i)->children(j)->value
		next
	end if
next
