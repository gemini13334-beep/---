extends RefCounted
class_name TacticalLoot

const CASES := [
 {"name":"ОПЕРАТИВНЫЙ", "price":120, "bonus":0},
 {"name":"ЭЛИТНЫЙ", "price":360, "bonus":5},
 {"name":"ЛЕГЕНДАРНЫЙ", "price":900, "bonus":12}
]
const ITEMS := [
 {"name":"ГРАФИТ", "rarity":0, "weapon":0},
 {"name":"ПЕСЧАНЫЙ ШТОРМ", "rarity":0, "weapon":1},
 {"name":"СТАЛЬ", "rarity":0, "weapon":2},
 {"name":"АРКТИКА", "rarity":1, "weapon":0},
 {"name":"НЕОН", "rarity":1, "weapon":1},
 {"name":"СИГНАЛ", "rarity":1, "weapon":2},
 {"name":"ПОЛЯРНАЯ НОЧЬ", "rarity":2, "weapon":0},
 {"name":"ФАНТОМ", "rarity":2, "weapon":1},
 {"name":"РУБЕЖ", "rarity":2, "weapon":2},
 {"name":"ЗОЛОТОЙ ПРИКАЗ", "rarity":3, "weapon":0},
 {"name":"АЛЫЙ ПРОТОКОЛ", "rarity":3, "weapon":2},
 {"name":"СПЕКТР 2099", "rarity":4, "weapon":1},
 {"name":"ВОРОН", "rarity":0, "weapon":3},
 {"name":"МАЛАХИТ", "rarity":1, "weapon":4},
 {"name":"КРАСНЫЙ КАРП", "rarity":2, "weapon":3},
 {"name":"ФИЛИГРАНЬ", "rarity":3, "weapon":4},
 {"name":"МЕРЗЛОТА", "rarity":1, "weapon":3},
 {"name":"ФОРСАЖ", "rarity":4, "weapon":4}
]
const RARITY_NAMES := ["ОБЫЧНЫЙ","РЕДКИЙ","ЭПИЧЕСКИЙ","ЛЕГЕНДАРНЫЙ","УЛЬТРАРЕДКИЙ"]
const RARITY_COLORS := ["#99a5af","#5aa8ff","#bb76ff","#ffc36b","#ff667c"]
const DUPLICATE_CREDITS := [25,65,160,400,1000]

static func roll(case_index:int,misses:int,rng:RandomNumberGenerator)->Dictionary:
 var bonus:int=int(CASES[case_index]["bonus"])
 var rarity:=0
 if misses>=19:
  rarity=2
 else:
  var chance:float=rng.randf_range(0.0,100.0)
  var ultra:float=1.0+float(bonus)*0.08
  var legendary:float=5.0+float(bonus)*0.25
  var epic:float=12.0+float(bonus)*0.5
  var rare:float=27.0
  if chance<ultra: rarity=4
  elif chance<ultra+legendary: rarity=3
  elif chance<ultra+legendary+epic: rarity=2
  elif chance<ultra+legendary+epic+rare: rarity=1
 var pool:Array[int]=[]
 for i in range(ITEMS.size()):
  if int(ITEMS[i]["rarity"])==rarity:
   pool.append(i)
 var item_id:int=pool[rng.randi_range(0,pool.size()-1)]
 return {"id":item_id,"rarity":rarity,"misses":0 if rarity>=2 else misses+1}
