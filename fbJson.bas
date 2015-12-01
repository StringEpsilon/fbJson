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
print token["Foo"].value
' Even accross multiple levels.
print "Inhaber Name: " & token["Inhaber"]["Name"].value
print
print

' Access via index:
for i as integer = 0 to ubound(token.children)
	print i & chr(9) & token[i].key & " = " & token[i].value
	if ubound(token.children(i)->children) >= 0 then
		for j as integer = 0 to ubound(token.children(i)->children)
			print chr(9) & j & chr(9) & token[i][j].key & " = " & token[i][j].value
		next
	end if
next
