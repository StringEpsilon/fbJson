#include once "../../fbJson.bi"

dim as jsonDocument array = jsonDocument()

for i as integer = 0 to 9
	array.AddItem("Item " & i)
next

print array.ToString

