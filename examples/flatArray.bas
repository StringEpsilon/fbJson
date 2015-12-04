#define fbJson_DEBUG
#include once "../fbJsonItem.bi"

dim as jsonItem flatArray = jsonItem("[1,2,3,4,5,6,7]")

for i as integer = 0 to flatArray.Count 
	? flatArray[i].value
next
