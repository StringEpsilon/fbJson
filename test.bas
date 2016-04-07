

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
? "Check length of first array"
AssertEqual(4, item[0].Count)
? "Check length of second array"
AssertEqual(4, item[1].Count)
? "Check length of third array"
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
