/'	
	This Source Code Form is subject to the terms of the Mozilla Public
	License, v. 2.0. If a copy of the MPL was not distributed with this
	file, You can obtain one at http://mozilla.org/MPL/2.0/. 
'/

#define fbJSON_debug

' This example imports just the header files into the test program and loads the actual code of the library as a dll / shared object.

' For this example to work, you need to compile the file "fbJson.bas" in the root directory with the "-lib" parameter:
' # fbc -lib fbJson.bas

' Libpath tells the linker to search the libfbJson.a in the root dir of the repository
#libpath "../"
#include once "../fbJson.bi"

dim as jsonItem foo = jsonItem("[1,2,3,4,5,6,7,8,9,10]")

print foo.toString()
