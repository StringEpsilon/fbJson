#define fbJson_DEBUG
#include once "../fbJson.bi"

dim as jsonDocument document
if (document.ReadFile("complextest.json") = false) then end

print document["Window"]["Listbox"]["Dimensions"]["h"].value
print document["Window"]["Listbox"]["Dimensions"]["w"].value
print document["Window"]["Listbox"]["Dimensions"]["x"].value
print document["Window"]["Listbox"]["Dimensions"]["y"].value
print document["Window"]["Listbox"]["Elements"][0].value

sleep

print
print "---------"
print

print document.ToString()
