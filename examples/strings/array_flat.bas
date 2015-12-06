#define fbJson_DEBUG
#include once "../fbJson.bi"

dim as jsonItem array = jsonItem("[1,2,3,4,5,6,7]")

for i as integer = 0 to array.Count 
	print array[i].value & " ";
next
