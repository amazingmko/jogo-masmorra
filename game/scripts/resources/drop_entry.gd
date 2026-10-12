class_name DropEntry
extends Resource
## Uma linha de uma tabela de drop: qual item, com que chance e em que quantidade.

@export var item_id: StringName
## Chance relativa. Um item com peso 20 cai duas vezes mais que um com peso 10.
@export_range(1, 10000) var weight: int = 10
@export_range(1, 999) var min_qty: int = 1
@export_range(1, 999) var max_qty: int = 1
