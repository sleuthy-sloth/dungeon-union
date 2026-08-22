class_name TestCase
extends RefCounted

var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func equal(actual: Variant, expected: Variant, message: String) -> void:
    check(actual == expected, "%s: expected %s, got %s" % [message, expected, actual])
