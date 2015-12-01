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



function parseObject(byref jsonString as string, startIndex as integer, endIndex as integer) as jsonItem ptr
	dim as jsonItem ptr item = new jsonItem()
	dim as parserState state = none
	dim as jsonItem ptr child
	dim as boolean errorOccured = false
	dim as integer stateStart
	dim as boolean escaped = false
	dim as boolean stringOpen = false
	dim as integer tokenCount = 0

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
						errorOccured = true
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
					if ( state = valueToken or state = arrayToken ) then
						state = objectToken
						stateStart = i+1
						
					elseif (state = objectToken) then
						tokenCount += 1 
					end if
				end if
			case "}"
				if (stringOpen = false) then
					if ( state = objectToken  and tokenCount = 0) then
						state = objectTokenClosed
						child = parseObject(jsonString, stateStart, i)
						
						redim item->children(ubound(child->children))
						for i as integer = 0 to ubound(child->children)
							item->children(i) = child->children(i)
						next
						delete(child)
						child = 0
					elseif (state = objectToken ) then
						tokenCount -=1
					elseif (state <> valueToken and state <> stringToken) then
						errorOccured = true
					end if
				end if
			case "[":
				if (stringOpen = false) then
					if (state = valueToken) then	
						state = arrayToken
					elseif (state < arrayToken) then
						errorOccured = true
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
				errorOccured = true
			end if
		end if
		
		if ( child <> 0 ) then
			redim preserve item->children(ubound(item->children)+1)
			item->children(ubound(item->children)) = child
			child->parent = item
			item = child
			child = 0
		end if
		
		if ( errorOccured ) then			
			dim as integer lineNumber = 1
			dim as integer position = 1
			for i as integer = 0 to endIndex
				if (jsonString[i] = 10) then
					lineNumber +=1
					position = 1
				end if
				position +=1
			next
			
			if (stringOpen) then
				print "fbJSON Error: Expected closing quote, found: "+ chr(jsonString[i]) + "' in line "& lineNumber &" at position " & position
			else
				print "fbJSON Error: Unexpected token '"+ chr(jsonString[i]) + "' in line "& lineNumber &" at position " & position
			end if
			exit for
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
