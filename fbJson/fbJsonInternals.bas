/'	
	This Source Code Form is subject to the terms of the Mozilla Public
	License, v. 2.0. If a copy of the MPL was not distributed with this
	file, You can obtain one at http://mozilla.org/MPL/2.0/. 
'/

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
	invalidCodepoint
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
	keyToken = 1
	keyTokenClosed = 2
	valueToken = 3
	valueTokenClosed = 4
	nestEnd = 5
	resetState
end enum

end namespace
