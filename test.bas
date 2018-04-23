/'	
	This Source Code Form is subject to the terms of the Mozilla Public
	License, v. 2.0. If a copy of the MPL was not distributed with this
	file, You can obtain one at http://mozilla.org/MPL/2.0/. 
'/
'#define fbJSON_debug

sub AssertEqual overload (expected as integer, result as integer) 
	if ( expected <> result ) then
		print "Assert failed: Expected "& expected &" but got: "& result
		end -1
	end if
end sub

sub AssertEqual(expected as string, result as string) 
	if ( expected <> result ) then
		print "Assert failed: Expected "& expected &" but got: "& result
		end -1
	end if
end sub

#include once "fbJson.bi"

dim as jsonItem item

Print "#0 - Test special keys"

item = jsonItem(chr(255) + "{"""": true}")
assertEqual(malformed, item.Datatype)

item = jsonItem("{""\u2665"":""Foo""}")
assertequal("♥", item[0].key)
item = jsonItem("{""\\uD83E\uDDC0"":""Foo""}")
assertequal("🧀", item[0].key)

item = jsonItem("{"""":""Foo""}")
assertequal("", item[0].key)

print "[OK]"

print "Test empty object"
item = jsonItem("{}")
AssertEqual(jsonObject, item.Datatype)
print "[OK]"
print

print "Test empty array"
item = jsonItem("[]")

AssertEqual(jsonArray, item.Datatype)
print "[OK]"
print

print "Test simple key value object"
item = jsonItem("{""key"": ""value""}")

AssertEqual(jsonObject, item.Datatype)
AssertEqual("key", item[0].key)
AssertEqual("value", item["key"].value)
print "[OK]"
print

print "Test simple array, all datatypes"
item = jsonItem("[ 1 , true , false , null , ""string"", [], {} ]")

AssertEqual(jsonArray, item.Datatype)
AssertEqual(7, item.Count)
AssertEqual(jsonNumber, item[0].Datatype)
AssertEqual(jsonBool, item[1].Datatype)
AssertEqual(jsonBool, item[2].Datatype)
AssertEqual(jsonNull, item[3].Datatype)
AssertEqual(jsonString, item[4].Datatype)
AssertEqual(jsonArray, item[5].Datatype)
AssertEqual(jsonObject, item[6].Datatype)

print "[OK]"
print

print "Test simple object, all datatypes"

item = jsonItem("{ ""number"":1 , ""bool1"": true , ""bool2"": false , ""null"": null , ""string"": ""string"", ""object"": {}, ""array"": [] }")

AssertEqual(jsonObject, item.Datatype)
AssertEqual(7, item.Count)
AssertEqual(jsonNumber, item["number"].Datatype)
AssertEqual(jsonBool, item["bool1"].Datatype)
AssertEqual(jsonBool, item["bool2"].Datatype)
AssertEqual(jsonNull, item["null"].Datatype)
AssertEqual(jsonString, item["string"].Datatype)
AssertEqual(jsonObject, item["object"].Datatype)
AssertEqual(jsonArray, item["array"].Datatype)

print "[OK]"
print

print "Test nested object with arrays"

item = jsonItem("{ ""object"": { ""array"": [1,2,3], ""array2"": [3,4,5], ""array3"": [6,7,8]}, ""string"": ""string""}")

AssertEqual(jsonObject, item.Datatype)
AssertEqual(2, item.Count)
AssertEqual(jsonObject, item["object"].Datatype)
AssertEqual(3, item["object"].Count)
AssertEqual(jsonString, item["string"].Datatype)
AssertEqual("string", item["string"].value)

print "[OK]"
print



print "Test nested object with objects"

item = jsonItem("{ ""object"": { ""nested1"": { ""string"": ""string""}, ""nested2"": { ""string"": ""string""}, ""nested3"": { ""string"": ""string""}} }")

AssertEqual(jsonObject, item.Datatype)
AssertEqual(1, item.Count)
AssertEqual(jsonObject, item["object"].Datatype)
AssertEqual(3, item["object"].Count)
AssertEqual(jsonObject, item["object"]["nested1"].Datatype)
AssertEqual(jsonObject, item["object"]["nested2"].Datatype)
AssertEqual(jsonObject, item["object"]["nested3"].Datatype)


print "[OK]"
print

print "Test malformed object: {""foo"":bar}"
item = jsonItem("{""foo"":bar}")
AssertEqual(malformed, item.DataType)
print "[OK]"
print

print "Test nested array"
item = jsonItem("[[1,2,3,4],[4,3,2,1],[5,6,7,8]]")

AssertEqual(jsonArray, item.Datatype)
AssertEqual(3, item.Count)
AssertEqual(4, item[0].Count)
AssertEqual(4, item[1].Count)
AssertEqual(4, item[2].Count)
AssertEqual("8", item[2][3].value)

print "[OK]"
print

print "Test nested structures"

item = jsonItem("{""foo"": { },	""bar"": [ ],""objects"": [{},{},{}],""arrays"":[[],[],[]]}")

assertEqual(jsonObject, item.Datatype)
assertEqual(4, item.Count)
assertEqual(jsonObject, item["foo"].datatype)
assertEqual(jsonArray, item["bar"].datatype)
assertEqual(jsonArray, item["objects"].datatype)
assertEqual(3, item["objects"].Count)
assertEqual(3, item["arrays"].Count)
assertEqual(jsonObject, item["objects"][0].datatype)
assertEqual(jsonObject, item["objects"][1].datatype)
assertEqual(jsonObject, item["objects"][2].datatype)

assertEqual(jsonArray, item["arrays"][0].datatype)
assertEqual(jsonArray, item["arrays"][1].datatype)
assertEqual(jsonArray, item["arrays"][2].datatype)

print "[OK]"
print

print "Test malformed object: {""foo"":}"


item = jsonItem("{""foo"": }")
AssertEqual(malformed, item.DataType)
print "[OK]"
print

print "#2 - test malformed string: {""key"":""}"

item = jsonItem("{""key"":""}")
assertEqual(malformed, item.Datatype)
print "[OK]"

print "#2 - test malformed string 2: {""key"":""value\n}"

item = jsonItem("{""key"":""value\n}")
assertEqual(malformed, item.Datatype)
print "[OK]"


print "#1 - Testing positive signed number : {""key"": +4.44}"

item = jsonItem("{""key"":+4.44}")
assertEqual(malformed, item.Datatype)

print "[OK]"

print "#1 - Testing negative signed number : {""key"":-4.44}"

item = jsonItem("{""key"":-4.44}")
assertEqual(jsonObject, item.Datatype)
assertEqual(jsonNumber, item["key"].Datatype)
assertEqual("-4.44", item["key"].Value)

print "[OK]"

print "#5 - Testing flat value - string : ""value"""

item = jsonItem("""value""")
assertEqual(jsonString, item.Datatype)
assertEqual("value", item.Value)

print "#5 - Testing strings - \uXXXX and surrogate pairs"
item = jsonItem("""\u2665123456""")
assertEqual("♥123456", item.value)
item = jsonItem("""\uD83E\uDDC0123456""")
assertEqual("🧀123456", item.value)

print "[OK]"

print "#5 - Testing flat value - boolean"

item = jsonItem("true")
assertEqual(jsonBool, item.Datatype)
assertEqual("true", item.Value)

item = jsonItem("false")
assertEqual(jsonBool, item.Datatype)
assertEqual("false", item.Value)

print "[OK]"

print "#5 - Testing flat value - null"

item = jsonItem("null")
assertEqual(jsonNull, item.Datatype)
assertEqual("null", item.Value)

print "[OK]"


print "#5 - Testing flat value - numbers"

item = jsonItem("1000000")
assertEqual(jsonNumber, item.Datatype)
assertEqual("1000000", item.Value)

item = jsonItem("10.000001")
assertEqual(jsonNumber, item.Datatype)
assertEqual("10.000001", item.Value)

item = jsonItem("12.3456789")
assertEqual(jsonNumber, item.Datatype)
assertEqual("12.3456789", item.Value)

item = jsonItem("-12.3456789")
assertEqual(jsonNumber, item.Datatype)
assertEqual("-12.3456789", item.Value)

item = jsonItem("[12.00000000]")
assertEqual("12", item[0].value)
assertEqual(jsonNumber, item[0].Datatype)

item = jsonItem("[+12.3456789]")
assertEqual(malformed, item.Datatype)

item = jsonItem("{""foo"": NaN}")
assertEqual(malformed, item.Datatype)

item = jsonItem("[-NaN]")
assertEqual(malformed, item.Datatype)
'/

item = jsonItem("{""foo"": [Infinity]}")
assertEqual(malformed, item.Datatype)
assertEqual(malformed, item[0].Datatype)



item = jsonItem("[-Infinity]")
assertEqual(malformed, item.Datatype)

item = jsonItem("[0E+]")
assertEqual(malformed, item.Datatype)

item = jsonItem("[.2e-3]")
assertEqual(malformed, item.Datatype)

print "[OK]"

print "#6 - Array structure"

item = jsonItem("[,1]")
assertEqual(malformed, item.Datatype)

item = jsonItem("["": 1]]")
assertEqual(malformed, item.Datatype)

item = jsonItem("[1,1,1")
assertEqual(malformed, item.Datatype)

print "#7 - Objects"

item = jsonItem("{"""":""a""}")
assertEqual(jsonObject, item.Datatype)
assertEqual("a", item[0].value)
assertEqual("a", item[""].value)
print "[OK]"

print "#8 - Strings"

item = jsonItem("""\""\\/\b\f\n\r\t""")
assertEqual(jsonString, item.Datatype)

item = jsonItem("[""\")
assertEqual(malformed, item.Datatype)

item = jsonItem("")
assertEqual(malformed, item.Datatype)

print "[OK]"

dim as string invalidUTF8 (0 to 6) = { _
	!"\195\28", _
	!"\160\161", _
	!"\226\28\161", _
	!"\226\82\28",   _ 
	!"\240\28\140\188", _
	!"\240\90\28\188", _
	!"\240\28\140\28" _
}


for i as integer = 0 to 6
	print "Testing invalid strings #"& i
	item = jsonItem(""""& invalidUTF8(i) & """")
	assertEqual(malformed, item.Datatype)
next

dim as string validUTF8 (0 to 4) = { _
	!"\195\177", _
	!"\226\130\161", _
	!"\240\144\140\188"_
}



for i as integer = 0 to 4
	print "Testing valid string #"& i
	item = jsonItem(""""& validUTF8(i) & """")
	? item.getError()
	assertEqual(jsonString, item.Datatype)
next




    


