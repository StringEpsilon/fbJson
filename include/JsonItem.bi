#include once "JsonDatatype.bi"

type jsonItem
	protected:
		_dataType as jsonDataType = jsonNull
		_value as string
		_children(any) as jsonItem ptr
		_error as string
		_parent as jsonItem ptr
		
		declare sub Parse(byref jsonString as string, startIndex as integer, endIndex as integer)
		
		declare function AppendChild(newChild as jsonItem ptr) as boolean
		declare function AppendChild(key as string, newChild as jsonItem ptr) as boolean
	public:
		
		key as string
		
		declare constructor()
		declare constructor(byref jsonString as string)
		
		declare destructor()
		
		declare property Value(byref newValue as string)
		declare property Value() as string
		
		declare property Count() as integer
		declare property DataType() as jsonDataType
		
		declare operator [](key as string) byref as jsonItem
		declare operator [](index as integer) byref as jsonItem
		
		declare property Parent() byref as jsonItem
		
		declare operator LET(A as jsonItem)
		
		declare function ToString(level as integer = 0) as string
		
		declare function AddItem(key as string, value as string) as boolean
		declare function AddItem(key as string, item as jsonItem) as boolean
		
		declare function AddItem(value as string) as boolean
		declare function AddItem(item as jsonItem) as boolean
					
		declare function RemoveItem(key as string) as boolean
		declare function RemoveItem(index as integer) as boolean
		
		declare function ContainsKey(key as string) as boolean	
end type
