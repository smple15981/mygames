class_name TestAssert
extends RefCounted


static func equal(actual: Variant, expected: Variant, label: String) -> String:
    if actual == expected:
        return ""
    return "%s: expected %s, got %s" % [label, expected, actual]


static func truthy(value: bool, label: String) -> String:
    return "" if value else "%s: expected true" % label
