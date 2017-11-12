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
