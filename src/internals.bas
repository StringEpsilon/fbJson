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
