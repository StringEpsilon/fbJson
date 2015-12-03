#include once "fbJsonItem.bi"

dim as integer ff = freefile()

dim as string inputLine 
dim as string jsonFile

open "test.json" for input as #ff 
	while (not eof(ff))
		line input #ff, inputLine 
		jsonFile += inputLine + chr(10)
	wend
close #ff
trim(jsonFile, chr(10))

dim as jsonItem token = jsonItem(jsonFile)

' Access via key:
print token["firstName"].value
print token["lastName"].value
' Even accross multiple levels.
print token["phoneNumbers"][0]["number"].value
print


' Access via index:
for i as integer = 0 to token.count
	
	if ( token[i].Count >= 0 AND token[i].datatype = jsonObject) then
		print token[i].Key &" : {"
		for j as integer = 0 to token[i].Count
			print chr(9) & token[i][j].key & " = " & token[i][j].value
		next
		print "}"
	end if
next
