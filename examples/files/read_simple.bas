#include once "../../fbJson.bi"

dim as jsonDocument document
if ( document.ReadFile("simple_file.json") = false ) then end

for i as integer = 0 to document.Count -1
	if ( document[i].Datatype <> jsonObject and document[i].Datatype <> jsonArray ) then
		print document[i].key, document[i].value
	end if
next

