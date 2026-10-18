extends Resource
class_name ChatDialogue

## 一段对话的台词，按顺序显示。
## 约定：偶数下标 = 发起方说，奇数下标 = 对方说。
@export_multiline var lines: Array[String] = []
