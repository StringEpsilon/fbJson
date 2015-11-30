enum jsonType
	malformed = -1
	object
	array
	number
	strng
	bool
	null
end enum

enum parserState
	none = -1
	jkey = 0
	jvalue
	jstring
	jarray
	jarrayValue
	jarrayClosed
	jobject
	jobjectClosed
end enum

type jsonItem
	parent as jsonItem ptr
	key as string
	value as string
	
	innerText as string
	children(any) as jsonItem ptr
	values(any) as string
end type

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
	case jvalue
		message += "value"
	case jstring
		message += "string"
	case jarray
		message += "array"
	case jarrayValue
		message += "array value"
	case jarrayClosed
		message += "array closed"
	case jobject
		message += "object"
	case jobjectClosed
		message += "object closed"
	end select
	message += " ] from " & chr(jsonString[stateStart])
	print message
end sub

function parseObject(byref jsonString as string, startIndex as integer, endIndex as integer) as jsonItem ptr
	dim as jsonItem ptr token = new jsonItem()
	dim as parserState state = none
	dim as jsonItem ptr child
	dim as integer stateStart
	dim as boolean escaped = false
	dim as boolean stringOpen = false

	for i as integer = startIndex to endIndex
		select case chr(jsonString[i])
			case ":":
				if ( stringOpen = false) then
					if (state = jKey) then
						child = new jsonItem
						child->Key = mid(jsonString, stateStart, i+1 - stateStart)  
						state = jValue
						stateStart = i+2
					elseif (state <> jObject) then
						WriteParserError(jsonString, i, state, stateStart)
					end if
				end if
			case ",":
				if (stringOpen = false) then
					if (state = jValue OR state = jString) then
						token->value = mid(jsonString, stateStart, i+1 - stateStart)
					elseif (state = jArrayValue) then
						dim as string value = mid(jsonString, stateStart, i+1 - stateStart)
						redim preserve token->values(ubound(token->values)+1)
						token->values(ubound(token->values)) = value
						state = jArray
					end if
					if (state <> jobject and state <> jArray ) then
						stateStart = i
						state = none
					end if
				end if
			case """":
				if (not escaped) then
					stringOpen = not(stringOpen)
					if (stringOpen = true) then
						if (state = none ) then 
							state = jKey
							stateStart = i+1
						elseif (state = jValue) then
							state = jString
							stateStart = i+1
						elseif (state = jArray) then
							state = jArrayValue
							stateStart = i+1
						end if
					end if
				end if
			case "\":
				escaped = true
			case "{":
				if (not stringOpen) then
					if ( state = jValue ) then
						state = jObject
						stateStart = i+1
					end if
				end if
			case "}"
				if (stringOpen = false) then
					if ( state = jObject ) then
						state = jObjectClosed
						child = parseObject(jsonString, stateStart, i)
						
						redim token->children(ubound(child->children))
						for i as integer = 0 to ubound(child->children)
							token->children(i) = child->children(i)
						next
						delete(child)
						child = 0
					elseif (state <> jvalue and state <> jString) then
						WriteParserError(jsonString, i, state, stateStart)
					end if
				end if
			case "[":
				if (stringOpen = false) then
					if (state = jvalue) then	
						state = jArray
					elseif (state < jArray) then
						WriteParserError(jsonString, i, state, stateStart)
					end if
				end if
			case "]":
				if (stringOpen = false) then
					if (state = jArray) then
						state = jValue
					elseif (state = jArrayValue) then
						dim as string value = mid(jsonString, stateStart, i - stateStart)
						redim preserve token->values(ubound(token->values)+1)
						token->values(ubound(token->values)) = value
						state = jValue
					end if
				end if
		end select
		
		if (i = endIndex) then
			if (state = jValue OR state = jString) then
				token->value = mid(jsonString, stateStart, i-2 - stateStart)
			else
				WriteParserError(jsonString, stateStart, state, stateStart)
			end if
		end if
		
		if ( child <> 0 ) then
			redim preserve token->children(ubound(token->children)+1)
			token->children(ubound(token->children)) = child
			child->parent = token
			token = child
			child = 0
		end if
		
		if (state = none) then
			if (token->parent <> 0) then
				token = token->parent	
			end if
		end if
	next
	
	if (token->parent <> 0) then
		token = token->parent
	end if
	return token
end function

for i as integer = 0 to ubound(token->children)
	? token->children(i)->key & " : " & token->children(i)->value
	if ubound(token->children(i)->children) >= 0 then
		for j as integer = 0 to ubound(token->children(i)->children)
			? "    " & token->children(i)->children(j)->key & " : " & token->children(i)->children(j)->value
		next
	end if
next
