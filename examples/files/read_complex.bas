#include once "../../fbJson.bi"

dim as jsonDocument document
if (document.ReadFile("complex_file.json") = false) then end

' Manual access:

print document["Window"]["Listbox"]["Dimensions"]["h"].value
print document["Window"]["Listbox"]["Dimensions"]["w"].value
print document["Window"]["Listbox"]["Dimensions"]["x"].value
print document["Window"]["Listbox"]["Dimensions"]["y"].value
print document["Window"]["Listbox"]["Elements"][0].value

sleep

print
print "---------"
print

' All array elements of "Label":

print document["Window"]["Label"].ToString()
