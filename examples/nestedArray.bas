#define fbJson_DEBUG
#include once "../fbJsonItem.bi"

dim as jsonItem flatArray = jsonItem("[[1,2,3,4],[4,3,2,1],[4,3,2,1]]")

print "---------"

for i as integer = 0 to flatArray.Count 
	print "[]", i
	for j as integer = 0 to flatArray[i].Count 
		print flatArray[i][j].value
	next
next

