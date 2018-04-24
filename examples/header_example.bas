/'	
	This Source Code Form is subject to the terms of the Mozilla Public
	License, v. 2.0. If a copy of the MPL was not distributed with this
	file, You can obtain one at http://mozilla.org/MPL/2.0/. 
'/

#define fbJSON_debug

' This example includes the whole source of fbJson into the programm, 
' instead of just using the headers and a dll / shared object.

#include once "../fbJson.bas"

dim as jsonItem foo = jsonItem("[1,2,3,4,5,6,7,8,9,10]")

print foo.toString()
