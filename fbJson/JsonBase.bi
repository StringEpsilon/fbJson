/'	
	This Source Code Form is subject to the terms of the Mozilla Public
	License, v. 2.0. If a copy of the MPL was not distributed with this
	file, You can obtain one at http://mozilla.org/MPL/2.0/. 
'/

#include once "JsonDatatype.bi"
#include once "fbJsonInternals.bas"

type JsonBase extends object
	protected:
		_dataType as jsonDataType = jsonNull
		_value as string
		_error as string
		_children as JsonBase ptr ptr = 0
		_parent as JsonBase ptr = 0
		_key as string
		_count as integer = -1
		
		declare sub Parse(jsonString as ubyte ptr, endIndex as integer)
		declare sub SetMalformed()
		declare function AppendChild(newChild as JsonBase ptr, override as boolean = false) as boolean
		declare sub setErrorMessage(errorCode as fbJsonInternal.jsonError, jsonstring as byte ptr, position as uinteger)
	public:
		declare static function ParseJson(inputString as string) byref as JsonBase
		declare constructor()
		declare constructor(byref jsonString as string)
		
		declare destructor()
				
		declare property Count() as integer
		declare property DataType() as jsonDataType
		
		declare property Parent() byref as JsonBase
		
		declare operator LET(A as JsonBase)
		
		declare sub Parse(byref jsonString as string)
			
		declare function ContainsKey(byref key as string) as boolean
		
		declare function getError() as string
end type
