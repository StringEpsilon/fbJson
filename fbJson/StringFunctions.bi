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

'declare function validateCodepoint(byref codepoint as ubyte) as boolean
declare sub FastSpace(byref destination as string, length as uinteger)
declare sub FastLeft(byref destination as string, length as uinteger)
declare sub FastMid(byref destination as string, byref source as byte ptr, start as uinteger, length as uinteger)
declare function isInString(byref target as string, query as byte) as boolean
declare sub LongToUft8(byref codepoint as long, byref result as string) 
declare sub SurrogateToUtf8(surrogateA as long, surrogateB as long, byref result as string)
declare function areEqual(byref stringA as string, byref stringB as string) as boolean
declare function DeEscapeString(byref escapedString as string) as boolean

sub FastSpace(byref destination as string, length as uinteger)
	dim as fbString ptr destinationPtr = cast(fbString ptr, @destination)
	if ( destinationPtr->size < length ) then 
		deallocate destinationptr->stringdata
		destinationPtr->stringData = allocate(length+1)
	end if
    memset(destinationPtr->stringData, 32, length)
    destinationPtr->length = length
end sub

sub FastCopy(byref destination as string, byref source as string)
	dim as fbString ptr destinationPtr = cast(fbString ptr, @destination)
	dim as fbString ptr sourcePtr = cast(fbString ptr, @source)
	if (sourcePtr->length = 0 and destinationPtr->length = 0) then return
	if ( destinationPtr->size < sourcePtr->size ) then 
		deallocate destinationptr->stringdata
		destinationPtr->length = sourcePtr->length
		destinationPtr->size = sourcePtr->length
		destinationPtr->stringData = allocate(sourcePtr->length+1)
		destinationPtr->stringData[sourcePtr->length] = 0
	end if
	
	' We allocate an extra byte here because FB tries to write into that extra byte when doing string copies.
	' The more "correct" mitigation would be to allocate up to the next blocksize (32 bytes), but that's slow.
	memcpy( destinationPtr->stringData, sourcePtr->stringData, destinationPtr->size)
	
end sub


sub FastLeft(byref destination as string, length as uinteger)
	dim as fbString ptr destinationPtr = cast(fbString ptr, @destination)
	dim as any ptr oldPtr = destinationPtr->stringData
	destinationPtr->length = IIF(length < destinationPtr->length, length, destinationPtr->length)
	'destinationPtr->size = destinationPtr->length
end sub

sub FastMid(byref destination as string, byref source as byte ptr, start as uinteger, length as uinteger)
	dim as fbString ptr destinationPtr = cast(fbString ptr, @destination)
	
	' Setting the length and size of the string, so the runtime knows how to handle it properly.
	if ( destinationPtr->size < length ) then 
		if ( destinationPtr->size ) then deallocate destinationPtr->stringData

		' We allocate an extra byte here because FB tries to write into that extra byte when doing string copies.
		' The more "correct" mitigation would be to allocate up to the next blocksize (32 bytes), but that's slow.
		destinationPtr->stringData = allocate(length+1)
		destinationPtr->stringData[length] = 0
	end if
	destinationPtr->length = length
	destinationPtr->size = length
	memcpy( destinationPtr->stringData, source+start, destinationPtr->size )
end sub

function isInString(byref target as string, query as byte) as boolean
	dim as fbstring ptr targetPtr = cast(fbstring ptr, @target)
	if ( targetPtr->size = 0 ) then return false
	
	return memchr( targetPtr->stringData, query, targetPtr->size ) <> 0
end function

sub LongToUft8(byref codepoint as long, byref result as string)	
	if codePoint <= &h7F then
		fastSpace(result, 1)
		result[0] = codePoint
	endif
	
	if (&hD800 <= codepoint AND codepoint <= &hDFFF) OR _
		(codepoint > &h10FFFD) then
		result = replacementChar
		return
	end if
	
	if (codepoint <= &h7FF) then
		fastSpace(result, 2)
		result[0] = &hC0 OR (codepoint SHR 6) AND &h1F 
		result[1] = &h80 OR codepoint AND &h3F
		return
	end if
	if (codepoint <= &hFFFF) then
		fastSpace(result, 3)
        result[0] = &hE0 OR codepoint SHR 12 AND &hF
        result[1] = &h80 OR codepoint SHR 6 AND &h3F
        result[2] = &h80 OR codepoint AND &h3F
        return
    end if
	
	fastSpace(result, 4)
	result[0] = &hF0 OR codepoint SHR 18 AND &h7
	result[1] = &h80 OR codepoint SHR 12 AND &h3F
	result[2] = &h80 OR codepoint SHR 6 AND &h3F
	result[3] = &h80 OR codepoint AND &h3F
    
	return
end sub

sub SurrogateToUtf8(surrogateA as long, surrogateB as long, byref result as string)
	dim as long codepoint = 0
    if (&hD800 <= surrogateA and surrogateA <= &hDBFF) then
		if (&hDC00 <= surrogateB and surrogateB <= &hDFFF) then
			codepoint = &h10000
			codepoint += (surrogateA and &h03FF) shl 10
			codepoint += (surrogateB and &h03FF)
		end if
	end if
	
	
	if ( codePoint = 0 ) then
		result = replacementChar
	end if
	FastSpace(result, 4)
	result[0] = &hF0 OR codepoint SHR 18 AND &h7
	result[1] = &h80 OR codepoint SHR 12 AND &h3F
	result[2] = &h80 OR codepoint SHR 6 AND &h3F
	result[3] = &h80 OR codepoint AND &h3F
end sub

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
	dim as boolean isEscaped
	for i as uinteger = 0 to length 
		' 92 is backslash
		
		if ( escapedString[i] = 92 andAlso isEscaped = false) then
			isEscaped = true
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
					if (i+5 > length) then
						return false
					end if
					dim sequence as string = mid(escapedString, i+3, 4)

					dim pad as integer
					dim as string glyph
					dim as long codepoint = strtoull(sequence, 0, 16)
					if (&hD800 <= codepoint and codepoint <= &hDFFF) then
						dim secondSurrogate as string = mid(escapedString, i+7+2, 4)
						if (len(secondSurrogate) = 4) then
							SurrogateToUtf8(codepoint, strtoull(secondSurrogate, 0, 16), glyph)
							pad = 12 - len(glyph)
						else
							return false
						end if
					elseif (codepoint > 0 orElse sequence = "0000") then
						LongToUft8(codepoint, glyph)
						pad = 6 - len(glyph)
					end if
					
					if (len(glyph) = 0) then
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
			isEscaped = false
			escapedString[i-trimsize] = escapedString[i]
		end if
	next
	if ( trimSize > 0 ) then
		fastleft(escapedString, length - trimSize+1)
	end if
	return true
end function

function isValidDouble(byref value as string) as boolean	
	' Note to reader: 
	' This function is strictly for validation as far as the IETF rfc7159 is concerned.
	' This might be more restrictive than you need it to be outside JSON use.
	
	' It's also a bit nuts. Callgrind is such a fascinating thing.
	

	dim as fbString ptr valuePtr = cast(fbString ptr, @value)
	
	if (value[0] = 48) then
		if ( valuePtr->length > 2) then
			select case value
				' Shorthands for "0" that won't pass this validation otherwise.
				case  "0e1","0e+1","0E1", "0E+1", "0e-1", "0E-1"
					value = "0"
					return true
				end 
			end select
		elseif ( valuePtr->length = 1) then
			return true
		end if
	end if
	
	dim as integer period = 0, exponent = 0, sign = 0
	
	' Yay for manual loop-unrolling.
	select case as const value[0]
		case 48: ' 0. No leading zeroes allowed.
			if (valuePtr->length > 1 and value[1] <> 101 and value[1] <> 69  and value[1] <> 46 ) then
				return false
			end if
		case 49 to 57 ' 1 - 9
			' do nothing
		case 101, 69: 'e, E
			return false
		case 46: ' .
			return false
		case 45: ' -
			sign += 1
			if (valuePtr->length = 1) then
				return false
			elseif (valuePtr->length >= 3) then
				if (value[1] = 48 andAlso (value[2] >= 48 and value[2] <= 57)) then
					return false
				end if
			end if
		case else
			return false
	end select
	
	
	for i as integer = 1 to valuePtr->length-1
		select case as const value[i]
			case 48 to 57 ' 0 - 9
				' do nothing
			case 101, 69: 'e, E
				if (i = valuePtr->length-1) then
					return false
				end if
				if (exponent > 0) then
					return false
				end if
				if (value[i-1] = 46) then
					return false
				end if
				exponent += 1
			case 46: ' .
				if (i = valuePtr->length-1) then
					return false
				end if
				if (period > 0 or exponent > 0 ) then
					return false
				end if
				if ( value[i-1] = 45) then return false
				period += 1
			case 45, 43 ' -, +
				if ((value[i-1] <> 101 and value[i-1] <> 69)) then
					return false
				end if
				if (i = valuePtr->length-1) then
					return false
				end if
			
			case else
				return false
		end select
	next
	
	if (exponent = 0 and period = 0 and (sign = 0 orElse valuePtr->length > 1) and valuePtr->length < 309) then
		return true
	end if
	value = str(cdbl(value))
	return not(valuePtr->length = 1 andAlso (value = "0"))
end function


sub FastTrimWhitespace(byref destination as string)
	dim as uinteger start, i, strLen = len(destination)
	if (strLen = 0) then return
	
	while start < strLen-1 andAlso destination[start] = 32 orElse destination[start] = 9 orElse destination[start] = 10  orElse destination[start] = 13
		start += 1
	wend
	if start = strLen -1 then 
		destination = ""
		return
	end if
	
	i = strLen -1
	while i > 1 andAlso destination[i] = 32 orElse destination[i] = 9 orElse destination[i] = 10  orElse destination[i] = 13
		i -= 1
	wend
	if (start = 0 and i = strLen-1) then return
	
	fastMid(destination, cast(byte ptr,strptr(destination)), start, i - start + 1)
end sub
end namespace
