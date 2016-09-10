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

function DeEscapeString(byref escapedString as string) as boolean
	dim as uinteger length = len(escapedString)-1

	dim as uinteger trimSize = 0	
	for i as uinteger = 0 to length
		' 92 is backslash
		if ( escapedString[i] = 92 ) then
			if ( i < length ) then
				select case as const escapedString[i-trimsize+1]
				case 34, 92, 47: ' " \ /
					' Nothing to do here.
				case 98 ' b
					escapedString[i-trimsize+1] = 8 ' backspace
				case 102 ' f
					escapedString[i-trimsize+1] = 12
				case 110 ' n
					escapedString[i-trimsize+1] = 10
				case 114 ' r
					escapedString[i-trimsize+1] = 13
				case 116 ' t
					escapedString[i-trimsize+1] = 9 ' tab
				case 117 ' u
					' TO DO: Escape unicode sequences.
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
