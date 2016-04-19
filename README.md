# fbJson

A small JSON library written in FreeBASIC

## Stability

Current stable is 0.13. Tested with fbc 1.05

I still work on the internals of jsonItem quite a bit. I do not recommend using unlabeled commits. The API however should not change dramatically.

Please report all issues.

## The code ##

The main parser ( `jsonTime.Parse()` ) is written do to as little allocations, string comparisons and concatinations as possible.

This code is deliberatly ugly for the sake of performance. I even had to use GOTO to make the errorhandling somewhat acceptable.

## API

#### JsonItem

`jsonItem()` 
Initilizes an empty item (of type `null` )

`jsonItem(string)`
Initializes a the item with a JSON-string to parse.

`jsonItem[string]` 
Returns the child element with the corresponding key.

`jsonItem[integer]` 
Returns the nth child of the item.

`jsonItem.Count` 
Gets the number of children.

`jsonItem.DataType` 
Gets the datatype of the item.

`jsonItem.Value as string` 
Gets or sets the value of the item (as string). Also sets the datatype. Returns an emptry string on objects and arrays.

`jsonItem.AddItem(string, jsonItem) as boolean` 
Adds an item with a key (only on jsonObjects).

`jsonItem.AddItem(string, string) as boolean` 
Adds a value with a key (only on jsonObjects).

`jsonItem.AddItem(string) as boolean` 
Adds an item (only on jsonArrays). Returns true if successful.

`jsonItem.AddItem(string) as boolean` 
Adds a value (only on jsonArrays). Returns true if successful.

`jsonItem.RemoveItem(string) as boolean` 
Removes the child with the given key. Returns true if successful.

`jsonItem.RemoveItem(integer) as boolean` 
Removes the Nth child. Returns true if successful.

`jsonItem.ContainsKey(string) as boolean` 
Returns true if the item is an object that contains the given key.

`jsonItem.ToString() as string` 
Creates a string representation of the Item and all it's children.

#### JsonDocument

Inherits from JsonItem

`jsonDocument.ReadFile(string) as boolean`
Loads the JSON-file from the given path. Returns true if successful.

`jsonDocument.WriteFile(string [, boolean = true]) as boolean`
Writes the content of the item to a give path. Returns true if successful. Second parameter turns overwriting files on or off (default is on).
