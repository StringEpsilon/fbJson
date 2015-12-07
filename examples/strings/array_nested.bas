#define fbJson_DEBUG
#include once "../../fbJson.bi"

dim as jsonItem flatArray = jsonItem("[[1,2,3,4],[4,3,2,1],[5,6,7,8]]")

for i as integer = 0 to flatArray.Count -1
	for j as integer = 0 to flatArray[i].Count -1
		print flatArray[i][j].value
	next
	print 
next
