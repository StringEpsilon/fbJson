/'	
	This Source Code Form is subject to the terms of the Mozilla Public
	License, v. 2.0. If a copy of the MPL was not distributed with this
	file, You can obtain one at http://mozilla.org/MPL/2.0/. 
'/

#include once "JsonItem.bi"
#include once "JsonBase.bas"
#include once "StringFunctions.bi"

constructor JsonItem()
	base()
	' Nothing to do
end constructor

constructor JsonItem(byref jsonString as string)
	base(jsonstring)
end constructor

destructor JsonItem()
	base.destructor()
end destructor

operator JsonItem.[](newKey as string) byref as JsonItem	
	if ( this._datatype = jsonObject and this._count > -1 ) then
		for i as integer = 0 to this._count
			if ( this._children[i]->_key = newkey ) then
				return *cast(JsonItem ptr,this._children[i])
			end if
		next
	end if
	
	#ifdef fbJSON_debug
		print "fbJSON Error: Key '"& key & "' not found in object "& this.key
		end -1
	#endif
	return *new JsonItem()
end operator

operator JsonItem.[](index as integer) byref as JsonItem
	if ( index <= this._count ) then
		return *cast(JsonItem ptr,this._children[index])
	end if
	
	#ifdef fbJSON_debug
		print "fbJSON Error: "& index & " out of bounds in "& this.key &". Actual size is "& this.count
		end -1
	#else
		return *new JsonItem()
	#endif
end operator

property JsonItem.Key() as string
	return this._key
end property

property JsonItem.Key(newkey as string)
	if ( this._key = newKey ) then return

	if ( this.Parent.ContainsKey(newKey) ) then return
	
	this._key = newKey
end property

property JsonItem.datatype() as jsonDataType
	return this._dataType
end property

property JsonItem.Count() as integer
	return this._count + 1
end property

property JsonItem.Value( byref newValue as string)
	using fbJsonInternal
	
	' TODO: Optimize this, according to the parser optimizations
	
	' First, handle strings in quotes:
	select case as const newValue[0]
	case jsonToken.Quote
		if ( newValue[len(newValue)-1] = jsonToken.Quote ) then
			this._dataType = jsonString
			this._value = mid(newValue,2, len(newValue)-2)
			if ( DeEscapeString(this._value) = false ) then
				this.setMalformed()
			end if
		else
			this.setMalformed()
		end if
	case 45, 48,49,50,51,52,53,54,55,56,57 '-, 0 - 9
		if (isValidDouble(newValue) ) then
			this._datatype = jsonNumber
			this._value = str(cdbl(newValue))
		else			
			this._datatype = jsonString
			this._value = newValue
				
			if ( DeEscapeString(this._value) = false ) then
				this.setMalformed()
			end if
		end if
	case 110,78, 102,70, 116,84 ' n, f, t
		select case lcase(newValue)
		case "null"
			this._value = newValue
			this._dataType = jsonNull
		case "true", "false"
			this._value = newValue
			this._dataType = jsonBool
		case else:
			' strict vs. nonstrict mode?
			this._datatype = jsonString
			this._value = newValue
				
			if ( DeEscapeString(this._value) = false ) then
				this.setMalformed()
			end if
		end select
	case else
		this._dataType = jsonString
		this._value = newValue
		if ( DeEscapeString(this._value) = false ) then
			this.setMalformed()
		end if
	end select
end property

property JsonItem.Value() as string
	return this._value
end property

function JsonItem.AddItem(newKey as string, newValue as string) as boolean
	if ( len(newKey) = 0 orElse this.containsKey(newKey) ) then
		return false
	end if
	
	if ( this._datatype = jsonNull ) then
		this._datatype = jsonObject
	end if
	
	if ( this._datatype = jsonObject ) then
		dim child as JsonItem ptr = new JsonItem
		child->Value = newValue
		child->_key = newKey
		return this.AppendChild(child)
	end if
	return false
end function

function JsonItem.AddItem(newKey as string, item as JsonItem) as boolean
	if ( len(newKey) = 0 orElse this.containsKey(newKey) ) then
		return false
	end if
	
	if ( this._datatype = jsonNull ) then
		this._datatype = jsonObject
	end if
	
	if ( this._datatype = jsonObject ) then
		dim child as JsonItem ptr = callocate(sizeof(JsonItem))
		*child = item
		child->_key = newKey
		return this.AppendChild(child)
	end if
	return false
end function

function JsonItem.AddItem(newValue as string) as boolean
	if ( this._datatype = jsonArray or this._datatype = jsonNull ) then
		this._datatype = jsonArray
		dim child as JsonItem ptr = new JsonItem
		child->value = newValue
		return this.AppendChild(child)
	end if
	return false
end function

function JsonItem.AddItem(item as JsonItem) as boolean
	if ( this._datatype = jsonArray or this._datatype = jsonNull ) then
		this._datatype = jsonArray
		dim child as JsonItem ptr = callocate(sizeof(JsonItem))
		*child = item
		return this.AppendChild(child) 		
	end if
	return false
end function

function JsonItem.RemoveItem(newKey as string) as boolean
	dim as integer index = -1
	
	if ( this._datatype = jsonObject ) then
		for i as integer = 0 to this._count
			if ( this._children[i]->_key = newkey ) then
				index = i
				exit for
			end if
		next
	end if
	
	return this.RemoveItem(index)
end function

function JsonItem.RemoveItem(index as integer) as boolean
	if ( index <= this._count andAlso index > -1 ) then
		delete this._children[index]
		if ( index < this.Count -1 ) then
			for i as integer = index to this._count 
				this._children[i] = this._children[i+1]
			next
		end if
		
		this._count -= 1
		this._children = reallocate(this._children, sizeof(jsonItem ptr) * this._count)
		
		return true
	end if
	return false
end function

function JsonItem.ToString(level as integer = 0) as string
	dim as string result
	
	' TODO: Clean up this mess.
	if ( this.datatype = jsonObject ) then
		result = "{"
	elseif ( this.datatype = jsonArray ) then
		result = "["
	elseif ( level = 0 ) then
		return this._value
	end if
		
	for i as integer = 0 to this._count 
		result += chr(10) + string((level +1) * 2, " ") 
		if ( this.datatype = jsonObject ) then
			result += """" & this[i]._key & """ : " 
		end if
		
		if ( this[i].Count >= 1 ) then
			result += this[i].toString(level+1)
		else
			if ( this[i].datatype = jsonString) then
				result += """" & this[i]._value & """"
			else
				result += this[i]._value
			end if
		end if
		if ( i < this.Count - 1 ) then
			result += ","
		else
			level -= 1
			result += chr(10)
		end if
		
	next
	
	
	if this.datatype = jsonObject  then
		result += string((level +1) * 2, " ")  + "}"
	elseif ( this.datatype = jsonArray ) then
		result +=  string((level +1) * 2, " ") +"]"
	end if
	
	return result
end function
