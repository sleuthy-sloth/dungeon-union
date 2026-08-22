extends RefCounted

static func run(t: TestCase) -> void:
    var root := AppRoot.new()
    t.equal(root.current_mode, &"boot", "app starts in boot mode")
    root.change_mode(&"workplace")
    t.equal(root.current_mode, &"workplace", "mode transition is stored")
