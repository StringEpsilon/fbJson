/'	
	This Source Code Form is subject to the terms of the Mozilla Public
	License, v. 2.0. If a copy of the MPL was not distributed with this
	file, You can obtain one at http://mozilla.org/MPL/2.0/. 
'/

#include once "JsonBase.bi"
#ifndef fbJson_HeaderLib
	#inclib "fbJson"
#endif

type JsonItem extends JsonBase
	public:
		declare constructor()
		declare constructor(byref jsonString as string)
		
		declare destructor()
		
		declare property Key () as string
		declare property Key (value as string)
		
		declare property Value(byref newValue as string)
		declare property Value() as string
		
		declare property Count() as integer
		declare property DataType() as jsonDataType
		
		declare operator [](key as string) byref as JsonItem
		declare operator [](index as integer) byref as JsonItem
				
		'declare operator LET(A as JsonItem)
		
		declare function ToString(level as integer = 0) as string
		
		declare function AddItem(key as string, value as string) as boolean
		declare function AddItem(key as string, item as JsonItem) as boolean
		
		declare function AddItem(value as string) as boolean
		declare function AddItem(item as JsonItem) as boolean
					
		declare function RemoveItem(key as string) as boolean
		declare function RemoveItem(index as integer) as boolean
end type
