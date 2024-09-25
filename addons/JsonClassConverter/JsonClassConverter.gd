extends Node
class_name JsonClassConverter

## Checks if dir exists
static func check_dir(path: String) -> void:
	if !DirAccess.dir_exists_absolute(path):
		DirAccess.make_dir_absolute(path)

#region Json to Class

static func json_file_to_dict(file_path: String, security_key: String = ""):
	var file: FileAccess
	if FileAccess.file_exists(file_path):
		if security_key.length() == 0:
			file = FileAccess.open(file_path, FileAccess.READ)
		else:
			file = FileAccess.open_encrypted_with_pass(file_path, FileAccess.READ, security_key)
		if not file:
			return null
		var parsed_results: Variant = JSON.parse_string(file.get_as_text())
		file.close()
		if parsed_results is Dictionary or parsed_results is Array:
			return parsed_results
	return null

## Load json to class from a file
static func json_file_to_class(file_path: String, security_key: String = "") -> Object:
	var parsed_results = json_file_to_dict(file_path, security_key)
	return json_to_class(parsed_results)


## Convert a JSON string to class
static func json_string_to_class(json_string: String) -> Object:
	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_string)
	assert(parse_result == Error.OK, "bad json")
	return json_to_class(json.data)


static func typed_value(value: Variant) -> Variant:
	if typeof(value) == Variant.Type.TYPE_STRING:
		return str_to_var(value)
		
	if typeof(value) == Variant.Type.TYPE_DICTIONARY:
		return json_to_class(value)
	
	if typeof(value) == Variant.Type.TYPE_ARRAY:
		var arr = []
		for subval in value:
			arr.append(typed_value(subval))
		return arr
	
	return value

## Convert a JSON dictionary into a class
static func json_to_class(json: Dictionary):
	var obj: Variant = {}
	var is_dict = true

	for key in json.keys():
		var value: Variant = json[key]
		
		if key == "ScriptName":
			is_dict = false
			var castClass = get_gdscript(value)
			obj = castClass.new()# as Object
			continue
		
		if is_dict:
			if typeof(key) == Variant.Type.TYPE_STRING:
				key = str_to_var(key)
			#if key.is_valid_int():
				#key = int(key)
			obj[typed_value(key)] = typed_value(value)
		else:
			obj.set(key, typed_value(value))
	
	return obj
	
	

static func get_gdscript(hint_class: String) -> GDScript:
	for className: Dictionary in ProjectSettings.get_global_class_list():
		if className. class == hint_class:
			return load(className.path)
	return null
	

#endregion

#region Class to Json
##Stores json to a file, returns if success
static func store_json_file(file_name: String, dir: String, data: Dictionary, security_key: String = "") -> bool:
	check_dir(dir)
	var file: FileAccess
	if security_key.length() == 0:
		file = FileAccess.open(dir + file_name, FileAccess.WRITE)
	else:
		file = FileAccess.open_encrypted_with_pass(dir + file_name, FileAccess.WRITE, security_key)
	if not file:
		printerr("Error writing to a file")
		return false
	var json_string: String = JSON.stringify(data, "\t")
	file.store_string(json_string)
	file.close()
	return true

## Convert a class into JSON string
static func class_to_json_string(_class: Object) -> String:
	return JSON.stringify(class_to_json(_class))

## Convert class to JSON dictionary
static func class_to_json(_class: Object) -> Dictionary:
	var dictionary: Dictionary = {}
	dictionary["ScriptName"] = _class.get_script().get_global_name()
	var properties: Array = _class.get_property_list()
	for property: Dictionary in properties: # Typed loop variable 'property'
		var property_name: String = property["name"]
		if property_name == "script":
			continue
		var property_value: Variant = _class.get(property_name)
		if not property_name.is_empty() and property.usage >= PROPERTY_USAGE_SCRIPT_VARIABLE and property.usage & PROPERTY_USAGE_STORAGE > 0:
			if property_value is Array:
				dictionary[property_name] = convert_array_to_json(property_value)
			elif property_value is Dictionary:
				dictionary[property_name] = convert_dictionary_to_json(property_value)
			elif property["type"] == TYPE_OBJECT and property_value != null and property_value.get_property_list():
				dictionary[property.name] = class_to_json(property_value)
			else:
				dictionary[property_name] = var_to_str(property_value)
	return dictionary

# Helper function to recursively convert arrays
static func convert_array_to_json(array: Array) -> Array:
	var json_array: Array = []
	for element: Variant in array: # element's type is inferred to be Variant
		if element is Object:
			json_array.append(class_to_json(element))
		elif element is Array:
			json_array.append(convert_array_to_json(element))
		elif element is Dictionary:
			json_array.append(convert_dictionary_to_json(element))
		else:
			json_array.append(element)
	return json_array

# Helper function to recursively convert dictionaries
static func convert_dictionary_to_json(dictionary: Dictionary) -> Dictionary:
	var json_dictionary: Dictionary = {}
	for key: Variant in dictionary.keys(): # key's type is inferred to be Variant
		var value: Variant = dictionary[key]
		key = var_to_str(key)
		if value is Object:
			json_dictionary[key] = class_to_json(value)
		elif value is Array:
			json_dictionary[key] = convert_array_to_json(value)
		elif value is Dictionary:
			json_dictionary[key] = convert_dictionary_to_json(value)
		else:
			json_dictionary[key] = value
	return json_dictionary
#endregion
