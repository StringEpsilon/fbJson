/'	
	This Source Code Form is subject to the terms of the Mozilla Public
	License, v. 2.0. If a copy of the MPL was not distributed with this
	file, You can obtain one at http://mozilla.org/MPL/2.0/. 
'/


#include "crt.bi"

namespace fbJsonInternal

const replacementChar as string  = "�"

' Allows us to interact directly with the FB-Internal string-structure.
' Don't use it, unless you know what you're doing.
type fbString
    dim as byte ptr stringData
    dim as integer length
    dim as integer size
end type

sub FastLeft(byref destination as string, length as uinteger)
	dim as fbString ptr destinationPtr = cast(fbString ptr, @destination)
	destinationPtr->length = IIF(length < destinationPtr->length, length, destinationPtr->length)
	destinationPtr->size = destinationPtr->length
	destinationPtr->stringData = reallocate(destinationPtr->stringData,destinationPtr->size)
end sub


sub FastMid(byref destination as string, byref source as byte ptr, start as uinteger, length as uinteger)
	dim as fbString ptr destinationPtr = cast(fbString ptr, @destination)
	if ( destinationPtr->size ) then deallocate destinationPtr->stringData
	' Setting the length and size of the string, so the runtime knows how to handle it properly.
	destinationPtr->length = length
	destinationPtr->size = length
	destinationPtr->stringData = allocate(destinationPtr->size)
	memcpy( destinationPtr->stringData, source+start, destinationPtr->size )
end sub

function EscapedToUtf8(byref escapedPoint as string) as string
	dim as ulong codePoint = valulng("&h" & escapedPoint)	
	dim result as string
	
	if codePoint <= &h7F then
		result = space(1)
		result[0] = codePoint
		return result
	endif
	
	if 	(&hD800 <= codepoint AND codepoint <= &hDFFF) OR _
		(codepoint > &h10FFFD) then
		return replacementChar
	end if
	
	if (codepoint <= &h7FF) then
		result = space(2)
		result[0] = &hC0 OR (codepoint SHR 6) AND &h1F 
		result[1] = &h80 OR codepoint AND &h3F
		return result
	end if
	if (codepoint <= &hFFFF) then
		result = space(3)
        result[0] = &hE0 OR codepoint SHR 12 AND &hF
        result[1] = &h80 OR codepoint SHR 6 AND &h3F
        result[2] = &h80 OR codepoint AND &h3F
        return result
    end if
	
	result = space(4)
	result[0] = &hF0 OR codepoint SHR 18 AND &h7
	result[1] = &h80 OR codepoint SHR 12 AND &h3F
	result[2] = &h80 OR codepoint SHR 6 AND &h3F
	result[3] = &h80 OR codepoint AND &h3F
    
	return result
end function

function EscapeSequenceToGlyph(sequence as string) as string
	if (len(sequence) <> 4) then
		return ""
	else
		for j as integer = 0 to len(sequence)-1
			if (not ((sequence[j]>= 48 and sequence[j] <= 57 ) or (sequence[j] >= 65 and sequence[j] <= 70 ))) then
				return ""
			end if
		next
	end if
	return  EscapedToUtf8(sequence)
end function


function IsSurrogate(codepoint as long ) as boolean
	if (&hD800 <= codepoint and codepoint <= &hDBFF) then
		return true
	end if
	return false
end function

function SurrogateToUtf8(surrogate() as long) as string
	dim as long codepoint = 0
    if (&hD800 <= surrogate(0) and surrogate(0) <= &hDBFF) then
		if (&hDC00 <= surrogate(1) and surrogate(1) <= &hDFFF) then
		
			codepoint = &h10000
			codepoint += (surrogate(0) and &h03FF) shl 10
			codepoint += (surrogate(1) and &h03FF)
		end if
	end if
	
	
	if ( codePoint = 0 ) then
		return replacementChar
	end if
	dim result as string = space(4)
	result[0] = &hF0 OR codepoint SHR 18 AND &h7
	result[1] = &h80 OR codepoint SHR 12 AND &h3F
	result[2] = &h80 OR codepoint SHR 6 AND &h3F
	result[3] = &h80 OR codepoint AND &h3F
	return result
end function

function DeEscapeString(byref escapedString as string) as boolean
	dim as uinteger length = len(escapedString)-1

	dim as uinteger trimSize = 0	
	for i as uinteger = 0 to length +1
		' 92 is backslash
		if ( escapedString[i] = 92 ) then
			if ( i < length ) then
				select case as const escapedString[i+1]
				case 34, 92, 47: ' " \ /
					' Nothing to do here.
				case 98 ' b
					escapedString[i+1] = 8 ' backspace
				case 102 ' f
					escapedString[i+1] = 12
				case 110 ' n
					escapedString[i+1] = 10
				case 114 ' r
					escapedString[i+1] = 13
				case 116 ' t
					escapedString[i+1] = 9 ' tab
				case 117 ' u
					'magic number '6': 2 for "\u" and 4 digit.
					dim sequence as string = mid(escapedString, i+3, 4) 
					dim pad as integer
					dim as string glyph
					dim as long codepoint = vallng("&h"& sequence)
					if (IsSurrogate(codepoint) ) then
						dim secondSurrogate as string = mid(escapedString, i+7+2, 4)
						if (len(secondSurrogate) = 4) then
							dim as long array(1) = {codepoint, vallng("&h"&secondSurrogate)}
							glyph = SurrogateToUtf8(array())
							pad = 12 - len(glyph)
						else
							return false
						end if
					else
						glyph = EscapeSequenceToGlyph(sequence)
						pad = 6 - len(glyph)

					end if
					
					if (glyph = "") then
						return false
					end if
					
					for j as integer = 0 to len(glyph)-1
						escapedString[i+j+pad] = glyph[j]
					next
					i += pad -1
					trimSize += pad -1
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
		fastleft(escapedString, length - trimSize+1)
	end if
	return true
end function

end namespace
