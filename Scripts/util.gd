class_name Util

static func print_rainbow(text: String) -> void:
    print_rich("[rainbow freq=1.0 sat=0.8 val=0.8]%s[/rainbow]" % text)

static func get_letter(index: int) -> String:
    var alphabet: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    if index >= 0:
        if index < alphabet.length():
            return alphabet.substr(index, 1)
        else:
            return str(index - alphabet.length() + 1)
    return ""

## Swap elements in an array at indices i and j
static func swap(array: Array, i: int, j: int) -> void:
    var temp = array[i]
    array[i] = array[j]
    array[j] = temp

## Sort an array based on another array's values
static func sort_arrays_by_values(values: Array, keys: Array, ascending: bool) -> void:
    for i in range(values.size() - 1):
        for j in range(i + 1, values.size()):
            if (ascending and values[i] > values[j]) or (not ascending and values[i] < values[j]):
                swap(values, i, j)
                swap(keys, i, j)

## Sort a dictionary by values in ascending or descending order
static func sort_dictionary_values(dict: Dictionary, ascending: bool = false) -> Dictionary:
    var values = dict.values()
    var keys = dict.keys()
    sort_arrays_by_values(values, keys, ascending)
    var sorted_dict: Dictionary = {}
    for i in range(values.size()):
        sorted_dict[keys[i]] = values[i]
    return sorted_dict