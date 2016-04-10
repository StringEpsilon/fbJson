#include "crt.bi"

'#define fbJSON_debug

namespace fbJsonInternal

' Allows us to interact directly with the FB-Internal string-structure.
' Don't use it, unless you know what you're doing.
type fbStringStruct
    dim as byte ptr stringData
    dim as integer length
    dim as integer size
end type


sub FastMid(byref destination as string, byref source as byte ptr, start as uinteger, length as uinteger)
	' I DO NOT recommend using this as a drop-in replacement for MID(). 
	' If FB changes it's internal string format, this breaks.
	' I also can't guarantee that it won't leak in all cases.
	' It does not leak in this json-parser.
		
	dim as fbStringStruct ptr destinationPtr = cast(fbStringStruct ptr, @destination)	
	' Setting the length and size of the string, so the runtime knows how to handle it properly.
	destinationPtr->length = length
	destinationPtr->size = length * sizeof(byte)
	' Allocating the memory manually is what safes the time here. Using "Space(x)" would work
	' And it would set length and size correctly - but it's slower.
	destinationPtr->stringData = allocate(destinationPtr->size)
	
	' Copy the raw memory-chunk we want from the source to our destination.
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
					'escapedString[i-trimsize+1] = escapedString[i-trimsize+1]
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
		escapedString = left(escapedString, length - trimSize+1)
	end if
	return true
end function

end namespace
