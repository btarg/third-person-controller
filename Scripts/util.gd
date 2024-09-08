class_name Util

static func print_rainbow(text: String) -> void:
    print_rich("[rainbow freq=1.0 sat=0.8 val=0.8]%s[/rainbow]" % text)

static func get_enum_name(enum_dict: Dictionary, value: int) -> String:
    for key: String in enum_dict.keys():
        if enum_dict[key] == value:
            return key
    return "[ERR no enum key %d]" % value

static func get_letter(index: int) -> String:
    var alphabet: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    if index >= 0:
        if index < alphabet.length():
            return alphabet.substr(index, 1)
        else:
            return str(index - alphabet.length() + 1)
    return ""