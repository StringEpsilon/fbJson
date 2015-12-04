#define fbJson_DEBUG
#include once "../fbJsonItem.bi"

dim as jsonItem flatArray = jsonItem("[[1,2,3,4],[4,3,2,1],[5,6,7,8]]")

for i as integer = 0 to flatArray.Count 
	for j as integer = 0 to flatArray[i].Count 
		print flatArray[i][j].value
	next
	print 
next

