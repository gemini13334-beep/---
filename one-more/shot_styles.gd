extends RefCounted

enum Form { LANCE, PAIR, FORK, NOVA, HELIX, BURST }
enum { CORE, HALO, SHAPE, RECOIL }

const AUTO := -2
const PLAIN := -1
const STYLES := {
	PLAIN: ["#ffe7a0","#f99230",Form.LANCE,1.0],
	0: ["#fff0a5","#ff9c32",Form.PAIR,0.68],
	1: ["#fff3db","#efbd75",Form.FORK,0.60],
	2: ["#b4faff","#4cbbcd",Form.HELIX,0.78],
	3: ["#b5edff","#328fe9",Form.NOVA,1.18],
	4: ["#fff6d3","#e88644",Form.LANCE,1.30],
	5: ["#c8ddf1","#8a9dab",Form.NOVA,1.12],
	6: ["#caf8ff","#48d6fa",Form.LANCE,0.73],
	7: ["#d8ffc8","#72c872",Form.NOVA,0.82],
	8: ["#e1f2ff","#738acb",Form.BURST,1.23],
	9: ["#fff1a6","#ffca3d",Form.FORK,1.0],
	10: ["#bce7ff","#4e72fd",Form.FORK,1.24],
	11: ["#ead9ff","#a35ed9",Form.PAIR,0.72],
	12: ["#ebcdff","#a046ff",Form.HELIX,0.91],
	13: ["#ffdbc1","#ed4335",Form.PAIR,1.12],
	14: ["#ffeac1","#ff6239",Form.BURST,1.08],
	15: ["#ffdeb1","#e39a3f",Form.NOVA,1.32],
	100: ["#d1f9ff","#4d9aff",Form.NOVA,1.26],
	101: ["#bdffe7","#40bbba",Form.HELIX,0.82],
	110: ["#fff4b9","#ff651f",Form.BURST,1.45],
	111: ["#f0ddff","#a23fff",Form.HELIX,1.16],
	112: ["#c4ffe5","#53cbc3",Form.NOVA,0.93],
}

static func validated(id: int) -> int:
	return id if STYLES.has(id) else PLAIN

static func choose(ranks: Dictionary, serial: int) -> int:
	var regular: Array[int] = []
	var synthesized: Array[int] = []
	for id in ranks:
		if not STYLES.has(id) or int(ranks[id]) <= 0:
			continue
		if id >= 110:
			synthesized.append(id)
		else:
			regular.append(id)
	if synthesized.is_empty():
		return PLAIN if regular.is_empty() else regular[serial%regular.size()]
	if regular.is_empty():
		return synthesized[serial%synthesized.size()]
	var pair := serial >> 1
	return synthesized[pair%synthesized.size()] if serial%2 == 0 else regular[pair%regular.size()]
