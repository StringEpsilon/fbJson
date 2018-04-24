/'	
	This Source Code Form is subject to the terms of the Mozilla Public
	License, v. 2.0. If a copy of the MPL was not distributed with this
	file, You can obtain one at http://mozilla.org/MPL/2.0/. 
'/


#include "crt.bi"

namespace fbJsonInternal

' Allows us to interact directly with the FB-Internal string-structure.
' Don't use it, unless you know what you're doing.
type fbString
    dim as byte ptr stringData
    dim as integer length
    dim as integer size
end type

const replacementChar as string  = "�"

declare function validateCodepoint(byref codepoint as ubyte) as boolean
declare sub FastSpace(byref destination as string, length as uinteger)
declare sub FastLeft(byref destination as string, length as uinteger)
declare sub FastMid(byref destination as string, byref source as byte ptr, start as uinteger, length as uinteger)
declare function isInString(byref target as string, byref query as byte) as boolean
declare function LongToUft8(byref codepoint as long) as string
declare function SurrogateToUtf8(surrogateA as long, surrogateB as long) as string
declare function areEqual(byref stringA as string, byref stringB as string) as boolean
declare function DeEscapeString(byref escapedString as string) as boolean

function validateCodepoint(byref codepoint as ubyte) as boolean
	' Anything below 191 *should* be valid.
	if (codepoint < 191) then
		return true
	end if
	
	select case as const codepoint
		' These codepoints are straight up invalid no matter what:
		case 192, 193, 245, 246, 247, 248, 249, 250, 251, 252, 253, 254, 255:
			return false
		case 237
			' TODO Validate against surrogate pairs, which are invalid in UTF-8.
			return true
		case else
			' Validation of invalid continuation handled in parser.
			return true
	end select
	return true
end function

sub FastSpace(byref destination as string, length as uinteger)
	dim as fbString ptr destinationPtr = cast(fbString ptr, @destination)
	if ( destinationPtr->size <> length ) then 
		deallocate destinationptr->stringdata
		destinationPtr->stringData = allocate( length)
	end if
    memset(destinationPtr->stringData, 32, length)
    destinationPtr->length = length
end sub

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
	destinationPtr->stringData = allocate(length +1)
	' We allocate an extra byte here because FB tries to write into that extra byte when doing string copies.
	' The more "correct" mitigation would be to allocate up to the next blocksize (32 bytes), but that's slow.
	memcpy( destinationPtr->stringData, source+start, destinationPtr->size )
end sub

function isInString(byref target as string, byref query as byte) as boolean
	dim as fbstring ptr targetPtr = cast(fbstring ptr, @target)
	if ( targetPtr->size = 0 ) then return false
	
	return memchr( targetPtr->stringData, query, targetPtr->size ) <> 0
end function

function LongToUft8(byref codepoint as long) as string
	dim result as string
	
	if codePoint <= &h7F then
		fastSpace(result, 1)
		result[0] = codePoint
		return result
	endif
	
	if (&hD800 <= codepoint AND codepoint <= &hDFFF) OR _
		(codepoint > &h10FFFD) then
		return replacementChar
	end if
	
	if (codepoint <= &h7FF) then
		fastSpace(result, 2)
		result[0] = &hC0 OR (codepoint SHR 6) AND &h1F 
		result[1] = &h80 OR codepoint AND &h3F
		return result
	end if
	if (codepoint <= &hFFFF) then
		fastSpace(result, 3)
        result[0] = &hE0 OR codepoint SHR 12 AND &hF
        result[1] = &h80 OR codepoint SHR 6 AND &h3F
        result[2] = &h80 OR codepoint AND &h3F
        return result
    end if
	
	fastSpace(result, 4)
	result[0] = &hF0 OR codepoint SHR 18 AND &h7
	result[1] = &h80 OR codepoint SHR 12 AND &h3F
	result[2] = &h80 OR codepoint SHR 6 AND &h3F
	result[3] = &h80 OR codepoint AND &h3F
    
	return result
end function

function SurrogateToUtf8(surrogateA as long, surrogateB as long) as string
	dim as long codepoint = 0
    if (&hD800 <= surrogateA and surrogateA <= &hDBFF) then
		if (&hDC00 <= surrogateB and surrogateB <= &hDFFF) then
			codepoint = &h10000
			codepoint += (surrogateA and &h03FF) shl 10
			codepoint += (surrogateB and &h03FF)
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

function areEqual(byref stringA as string, byref stringB as string) as boolean
	dim as fbString ptr A = cast(fbString ptr, @stringA)
	dim as fbString ptr B = cast(fbString ptr, @stringB)

	if (A->length <> B->length) then
		return false
	end if
	
	if (A = B) then
		return true
	end if
	
	return strcmp(A->stringData, B->stringData) = 0
end function

function DeEscapeString(byref escapedString as string) as boolean
	dim as uinteger length = len(escapedString)-1

	dim as uinteger trimSize = 0	
	for i as uinteger = 0 to length 
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
					dim as long codepoint = strtoull(sequence, 0, 16)
					if (&hD800 <= codepoint and codepoint <= &hDBFF) then
						dim secondSurrogate as string = mid(escapedString, i+7+2, 4)
						if (len(secondSurrogate) = 4) then
							glyph = SurrogateToUtf8(codepoint, strtoull(secondSurrogate, 0, 16))
							pad = 12 - len(glyph)
						else
							return false
						end if
					elseif (codepoint > 0) then
						glyph = LongToUft8(codepoint)
						pad = 6 - len(glyph)

					end if
					
					if (glyph = "" ) then
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
