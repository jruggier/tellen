class_name DialogueCommand
extends RefCounted
## One parsed line of a dialogue script.

enum Type { LINE, BG, MUSIC, SFX, SHOW, HIDE, EXPR, ITEM, HIDE_ITEM, CHOICE, LABEL, GOTO, IF, SET, WAIT, END }

var type: Type = Type.LINE
## Source line number (1-based), for error messages.
var line_number: int = 0
## LINE: speaker id (upper case) / SHOW, HIDE, EXPR: character id.
var speaker: String = ""
## LINE / SHOW / EXPR: expression.
var expression: String = ""
## LINE: the spoken text.
var text: String = ""
## BG / MUSIC / SFX / ITEM: asset or item id. LABEL / GOTO / IF: label.
## SET / IF: flag name.
var target: String = ""
## SHOW: left, center or right.
var position: String = ""
## IF: true when the condition is negated (@if !flag).
var negate: bool = false
## SET: value to store.
var value: Variant = true
## WAIT: seconds.
var seconds: float = 0.0
## CHOICE: options as {"text", "label"}.
var options: Array[Dictionary] = []
## IF / SET: flag name.
var flag: String = ""
