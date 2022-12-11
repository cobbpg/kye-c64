.encoding "ascii"

.var charColors = LoadBinary("graphics/kye - CharAttribs_L1.bin")
.var charSet = LoadBinary("graphics/kye - Chars.bin")
.var textCharSet = LoadBinary("graphics/text - Chars.bin")
.var playerSprites = LoadBinary("graphics/kye - Sprites.bin")

.namespace Piece {
	.label Walls = $100
	.label Dead = $80
	.label Active = $24

	.label Sliders = Active
	.label Rockies = Sliders + 4
	.label Bouncers = Rockies + 4
	.label AutoSlider = Bouncers + 4
	.label AutoRocky = AutoSlider + 4
	.label Blackhole = AutoRocky + 4
	.label BlackholeFull = Blackhole + 4
	.label Monsters = BlackholeFull + 4
	.label Stickers = Monsters + 10
	.label Timers = Stickers + 2
	.label Unused = Timers + 10

	.label Empty = $00
	.label Kye = $01
	.label WallStart = $03
	.label WallEnd = $19
	.label Wall1 = Walls + 1
	.label Wall2 = Walls + 2
	.label Wall3 = Walls + 3
	.label Wall4 = Walls + 4
	.label Wall5 = Walls + 5
	.label Wall6 = Walls + 6
	.label Wall7 = Walls + 7
	.label Wall8 = Walls + 8
	.label Wall9 = Walls + 9
	.label Earth = $1e
	.label Diamond = $02
	.label BlockSquare = $1d
	.label BlockRound = $1f
	.label SliderUp = Sliders + 3
	.label SliderDown = Sliders + 1
	.label SliderLeft = Sliders + 2
	.label SliderRight = Sliders + 0
	.label StickerLR = Stickers + 1
	.label StickerTB = Stickers + 0
	.label BouncerUp = Bouncers + 3
	.label BouncerDown = Bouncers + 1
	.label BouncerLeft = Bouncers + 2
	.label BouncerRight = Bouncers + 0
	.label RockyUp = Rockies + 3
	.label RockyDown = Rockies + 1
	.label RockyLeft = Rockies + 2
	.label RockyRight = Rockies + 0
	.label Twister = Monsters + 8
	.label Gnasher = Monsters + 0
	.label Blob = Monsters + 2
	.label Virus = Monsters + 4
	.label Spike = Monsters + 6
	.label AntiClocker = $21
	.label Clocker = $20
	.label DoorLR = $19
	.label DoorRL = $1b
	.label DoorUD = $1a
	.label DoorDU = $1c
	.label Timer0 = Timers + 9
	.label Timer1 = Timers + 8
	.label Timer2 = Timers + 7
	.label Timer3 = Timers + 6
	.label Timer4 = Timers + 5
	.label Timer5 = Timers + 4
	.label Timer6 = Timers + 3
	.label Timer7 = Timers + 2
	.label Timer8 = Timers + 1
	.label Timer9 = Timers + 0
}

.namespace Frequency {
	.label IdleTickFrames = 6
	.label StartMoveTickFrames = 12
	.label MoveTickFrames = 3
	.label DiamondAnimationFrames = 3
	.label DeathTickFrames = 3

	.label Sliders = 1
	.label Rockies = 1
	.label Bouncers = 5
	.label AutoSlider = 7
	.label AutoRocky = 7
	.label Blackhole = 5
	.label BlackholeFull = 5
	.label Monsters = 3
	.label Stickers = 1
	.label Timers = 30
}

.var pieceCodes = Hashtable()
.eval pieceCodes.put($20, Piece.Empty)
.eval pieceCodes.put($4b, Piece.Kye)
.eval pieceCodes.put($31, Piece.Wall1)
.eval pieceCodes.put($32, Piece.Wall2)
.eval pieceCodes.put($33, Piece.Wall3)
.eval pieceCodes.put($34, Piece.Wall4)
.eval pieceCodes.put($35, Piece.Wall5)
.eval pieceCodes.put($36, Piece.Wall6)
.eval pieceCodes.put($37, Piece.Wall7)
.eval pieceCodes.put($38, Piece.Wall8)
.eval pieceCodes.put($39, Piece.Wall9)
.eval pieceCodes.put($65, Piece.Earth)
.eval pieceCodes.put($2a, Piece.Diamond)
.eval pieceCodes.put($62, Piece.BlockSquare)
.eval pieceCodes.put($42, Piece.BlockRound)
.eval pieceCodes.put($75, Piece.SliderUp)
.eval pieceCodes.put($64, Piece.SliderDown)
.eval pieceCodes.put($6c, Piece.SliderLeft)
.eval pieceCodes.put($72, Piece.SliderRight)
.eval pieceCodes.put($73, Piece.StickerTB)
.eval pieceCodes.put($53, Piece.StickerLR)
.eval pieceCodes.put($55, Piece.BouncerUp)
.eval pieceCodes.put($44, Piece.BouncerDown)
.eval pieceCodes.put($4c, Piece.BouncerLeft)
.eval pieceCodes.put($52, Piece.BouncerRight)
.eval pieceCodes.put($5e, Piece.RockyUp)
.eval pieceCodes.put($76, Piece.RockyDown)
.eval pieceCodes.put($3c, Piece.RockyLeft)
.eval pieceCodes.put($3e, Piece.RockyRight)
.eval pieceCodes.put($54, Piece.Twister)
.eval pieceCodes.put($45, Piece.Gnasher)
.eval pieceCodes.put($43, Piece.Blob)
.eval pieceCodes.put($7e, Piece.Virus)
.eval pieceCodes.put($5b, Piece.Spike)
.eval pieceCodes.put($61, Piece.AntiClocker)
.eval pieceCodes.put($63, Piece.Clocker)
.eval pieceCodes.put($41, Piece.AutoSlider)
.eval pieceCodes.put($46, Piece.AutoRocky)
.eval pieceCodes.put($48, Piece.Blackhole)
.eval pieceCodes.put($66, Piece.DoorLR)
.eval pieceCodes.put($67, Piece.DoorRL)
.eval pieceCodes.put($68, Piece.DoorUD)
.eval pieceCodes.put($69, Piece.DoorDU)
.eval pieceCodes.put($7d, Piece.Timer3)
.eval pieceCodes.put($7c, Piece.Timer4)
.eval pieceCodes.put($7b, Piece.Timer5)
.eval pieceCodes.put($7a, Piece.Timer6)
.eval pieceCodes.put($79, Piece.Timer7)
.eval pieceCodes.put($78, Piece.Timer8)
.eval pieceCodes.put($77, Piece.Timer9)

.var wallCodes = Hashtable()
.eval wallCodes.put($10, $0f, $11, $0f, $12, $10, $13, $0f, $14, $10)
.eval wallCodes.put($20, $17, $21, $17, $22, $17, $23, $17, $24, $17)
.eval wallCodes.put($30, $11, $31, $11, $32, $11, $33, $11, $34, $11)
.eval wallCodes.put($40, $14, $41, $14, $42, $15, $43, $14, $44, $15)
.eval wallCodes.put($50, $03, $51, $04, $52, $05, $53, $06, $54, $07)
.eval wallCodes.put($60, $16, $61, $16, $62, $16, $63, $16, $64, $16)
.eval wallCodes.put($70, $08, $71, $09, $72, $0a, $73, $0b, $74, $0c)
.eval wallCodes.put($80, $12, $81, $12, $82, $12, $83, $13, $84, $13)
.eval wallCodes.put($90, $0d, $91, $0d, $92, $0d, $93, $0e, $94, $0e)

.function IsConnecting(code, exclusion1, exclusion2) {
	.return code != exclusion1 && code != exclusion2 && code >= Piece.Walls
}

.function LoadLevelPack(file) {
	.var levelPack = List()
	.var data = LoadBinary(file)
	.var line = 0
	.var i = 0
	.var levelIndex = 0
	.while (true) {
		.var start = 0
		.var title = List()
		.var description = List()
		.var board = List()
		.var titleLine = 1 + levelIndex * 23
		.var descLine = titleLine + 1
		.var dataLine = titleLine + 3
		.while (start == 0 && i < data.getSize()) {
			.var c = data.uget(i)
			.if (c == 10) {
				.eval line++
				.if (line == dataLine) .eval start = i + 1
			} else {
				.if (line == titleLine && c >= ' ') .eval title.add(c)
				.if (line == descLine && c >= ' ') .eval description.add(c)
			}
			.eval i++
		}
		.if (start > 0) {
			.eval levelIndex++
			.var activeObjects = 0
			.var pi = start;
			.var pieces = List()
			.for (var y = 0; y < 20; y++) {
				.for (var x = 0; x < 30 && pi < data.getSize(); x++) {
					.eval pieces.add(pieceCodes.get(data.uget(pi)))
					.eval pi++
				}
				.while (pi < data.getSize() && data.uget(pi) >= ' ') .eval pi++
				.while (pi < data.getSize() && data.uget(pi) < ' ') .eval pi++
			}
			.if (pieces.size() == 600) {
				.for (var y = 0; y < 20; y++) {
					.for (var x = 0; x < 30; x++) {
						.var code = pieces.get(y * 30 + x)
						.if (code >= Piece.Walls) {
							.var nr = x < 29 && IsConnecting(pieces.get(y * 30 + x + 1), Piece.Wall4, 0)
							.var nl = y < 19 && IsConnecting(pieces.get(y * 30 + x + 30), Piece.Wall8, 0)
							.var nd = y < 19 && x < 29 && IsConnecting(pieces.get(y * 30 + x + 31), Piece.Wall4, Piece.Wall8)
							.var ofs = nr ? (nl ? (nd ? 0 : 1) : 3) : (nl ? 2 : 4)
							.eval code = wallCodes.get(((code & $0f) << 4) + ofs)
						}
						.if (code >= Piece.Active && code < Piece.Unused) {
							.eval activeObjects++
						}
						.eval board.add(code)
					}
				}
				.if (activeObjects < 256) {
					.var level = Hashtable()
					.eval level.put("title", title)
					.eval level.put("description", description)
					.eval level.put("board", board)
					.eval level.put("activeObjects", activeObjects)
					.eval levelPack.add(level)
				} else {
					.print "Skipping " + file + " level " + levelIndex + " with " + activeObjects + " active objects"
				}
			}
		} else {
			.return levelPack
		}
	}
}

.function RunLengthEncode(board) {
	.var result = List()
	.var prevTile = -1
	.var count = 0
	.for (var i = 0; i < board.size(); i++) {
		.var t = board.get(i)
		.if (t != prevTile || count >= 65) {
			.if (prevTile >= 0) {
				.if (count > 1) {
					.if (prevTile > 0) {
						.eval result.add((count - 2) | $c0, prevTile)
					} else {
						.eval result.add((count - 2) | $80)
					}
				} else {
					.eval result.add(prevTile)
				}
			}
			.eval prevTile = t
			.eval count = 1
		} else {
			.eval count++
		}
	}
	.if (count > 1) {
		.if (prevTile > 0) {
			.eval result.add((count - 2) | $c0, prevTile)
		} else {
			.eval result.add((count - 2) | $80)
		}
	} else {
		.eval result.add(prevTile)
	}
	.return result
}

.var levelPackPointers = List()

.macro IncludeLevelPackPointers() {
	.var count = levelPackPointers.size()

		.byte count

	.for (var i = 0; i < count; i++) {
		.word levelPackPointers.get(i)
	}	
}

.macro IncludeLevelPack(title, file) {
	.var set = LoadLevelPack(file)
	.var count = set.size()

	LevelPack:	
		MakeString(title + " (" + count + ")")
		.byte count

	.for (var i = 0; i < count; i++) {
		.word Levels[i].Data
	}

	Levels: .for (var i = 0; i < count; i++) {
		.var level = set.get(i)
		//.print "Adding level " + i + " (active objects: " + level.get("activeObjects") + ")"
		
		Data: IncludeLevel(level)
	}

	.eval levelPackPointers.add(LevelPack)
}

.macro IncludeLevel(level) {
	.var title = level.get("title").lock()
	.var description = level.get("description")
	.var board = level.get("board")
	.var innerBoard = List()
	.for (var i = 1; i < 19; i++) {
		.for (var j = 1; j < 29; j++) {
			.eval innerBoard.add(board.get(i * 30 + j))
		}		
	}
	.var innerRle = RunLengthEncode(innerBoard)
	//.print "Compression: " + board.size() + " -> " + innerRle.size()

	Title:
		MakeStringFromList(UncapitaliseText(title))

	Description:
		MakeStringFromList(description)

	Board:
		.fill innerRle.size(), innerRle.get(i)
}

.namespace Colors {
	.label Border = WHITE
	.label Background = WHITE
	.label Underlay = YELLOW
	.label Kye = charColors.get(Piece.Kye)
	.label KyeOutline = BLACK
	.label Diamond = charColors.get(Piece.Diamond)
	.label Slider = charColors.get(Piece.Sliders)
	.label Rocky = charColors.get(Piece.Rockies)
	.label Bouncer = charColors.get(Piece.Bouncers)
	.label BlackholeFull = charColors.get(Piece.BlackholeFull)
	.label Door = charColors.get(Piece.DoorLR)
}

.define pieceTimings {
	.var pieceTimings = Hashtable()

	.eval pieceTimings.put(Piece.Timer0, Frequency.Timers)
	.eval pieceTimings.put(Piece.Timer1, Frequency.Timers)
	.eval pieceTimings.put(Piece.Timer2, Frequency.Timers)
	.eval pieceTimings.put(Piece.Timer3, Frequency.Timers)
	.eval pieceTimings.put(Piece.Timer4, Frequency.Timers)
	.eval pieceTimings.put(Piece.Timer5, Frequency.Timers)
	.eval pieceTimings.put(Piece.Timer6, Frequency.Timers)
	.eval pieceTimings.put(Piece.Timer7, Frequency.Timers)
	.eval pieceTimings.put(Piece.Timer8, Frequency.Timers)
	.eval pieceTimings.put(Piece.Timer9, Frequency.Timers)

	.eval pieceTimings.put(Piece.Twister, Frequency.Monsters)
	.eval pieceTimings.put(Piece.Twister + 1, Frequency.Monsters)
	.eval pieceTimings.put(Piece.Gnasher, Frequency.Monsters)
	.eval pieceTimings.put(Piece.Gnasher + 1, Frequency.Monsters)
	.eval pieceTimings.put(Piece.Blob, Frequency.Monsters)
	.eval pieceTimings.put(Piece.Blob + 1, Frequency.Monsters)
	.eval pieceTimings.put(Piece.Virus, Frequency.Monsters)
	.eval pieceTimings.put(Piece.Virus + 1, Frequency.Monsters)
	.eval pieceTimings.put(Piece.Spike, Frequency.Monsters)
	.eval pieceTimings.put(Piece.Spike + 1, Frequency.Monsters)

	.eval pieceTimings.put(Piece.Blackhole, Frequency.Blackhole)
	.eval pieceTimings.put(Piece.Blackhole + 1, Frequency.Blackhole)
	.eval pieceTimings.put(Piece.Blackhole + 2, Frequency.Blackhole)
	.eval pieceTimings.put(Piece.Blackhole + 3, Frequency.Blackhole)
	.eval pieceTimings.put(Piece.BlackholeFull, Frequency.BlackholeFull)
	.eval pieceTimings.put(Piece.BlackholeFull + 1, Frequency.BlackholeFull)
	.eval pieceTimings.put(Piece.BlackholeFull + 2, Frequency.BlackholeFull)
	.eval pieceTimings.put(Piece.BlackholeFull + 3, Frequency.BlackholeFull)

	.eval pieceTimings.put(Piece.SliderUp, Frequency.Sliders)
	.eval pieceTimings.put(Piece.SliderLeft, Frequency.Sliders)
	.eval pieceTimings.put(Piece.SliderDown, Frequency.Sliders)
	.eval pieceTimings.put(Piece.SliderRight, Frequency.Sliders)

	.eval pieceTimings.put(Piece.RockyUp, Frequency.Rockies)
	.eval pieceTimings.put(Piece.RockyLeft, Frequency.Rockies)
	.eval pieceTimings.put(Piece.RockyDown, Frequency.Rockies)
	.eval pieceTimings.put(Piece.RockyRight, Frequency.Rockies)

	.eval pieceTimings.put(Piece.BouncerUp, Frequency.Bouncers)
	.eval pieceTimings.put(Piece.BouncerDown, Frequency.Bouncers)
	.eval pieceTimings.put(Piece.BouncerLeft, Frequency.Bouncers)
	.eval pieceTimings.put(Piece.BouncerRight, Frequency.Bouncers)

	.eval pieceTimings.put(Piece.StickerLR, Frequency.Stickers)
	.eval pieceTimings.put(Piece.StickerTB, Frequency.Stickers)

	.eval pieceTimings.put(Piece.AutoSlider, Frequency.AutoSlider)
	.eval pieceTimings.put(Piece.AutoSlider + 1, Frequency.AutoSlider)
	.eval pieceTimings.put(Piece.AutoSlider + 2, Frequency.AutoSlider)
	.eval pieceTimings.put(Piece.AutoSlider + 3, Frequency.AutoSlider)
	.eval pieceTimings.put(Piece.AutoRocky, Frequency.AutoRocky)
	.eval pieceTimings.put(Piece.AutoRocky + 1, Frequency.AutoRocky)
	.eval pieceTimings.put(Piece.AutoRocky + 2, Frequency.AutoRocky)
	.eval pieceTimings.put(Piece.AutoRocky + 3, Frequency.AutoRocky)
}

.define pushablePieces {
	.var pushablePieces = Hashtable()

	.eval pushablePieces.put(Piece.BlockSquare, true)
	.eval pushablePieces.put(Piece.BlockRound, true)

	.eval pushablePieces.put(Piece.SliderUp, true)
	.eval pushablePieces.put(Piece.SliderDown, true)
	.eval pushablePieces.put(Piece.SliderLeft, true)
	.eval pushablePieces.put(Piece.SliderRight, true)

	.eval pushablePieces.put(Piece.RockyUp, true)
	.eval pushablePieces.put(Piece.RockyDown, true)
	.eval pushablePieces.put(Piece.RockyLeft, true)
	.eval pushablePieces.put(Piece.RockyRight, true)

	.eval pushablePieces.put(Piece.BouncerUp, true)
	.eval pushablePieces.put(Piece.BouncerDown, true)
	.eval pushablePieces.put(Piece.BouncerLeft, true)
	.eval pushablePieces.put(Piece.BouncerRight, true)

	.eval pushablePieces.put(Piece.StickerLR, true)
	.eval pushablePieces.put(Piece.StickerTB, true)

	.eval pushablePieces.put(Piece.Clocker, true)
	.eval pushablePieces.put(Piece.AntiClocker, true)

	.eval pushablePieces.put(Piece.AutoSlider, true)
	.eval pushablePieces.put(Piece.AutoSlider + 1, true)
	.eval pushablePieces.put(Piece.AutoSlider + 2, true)
	.eval pushablePieces.put(Piece.AutoSlider + 3, true)
	.eval pushablePieces.put(Piece.AutoRocky, true)
	.eval pushablePieces.put(Piece.AutoRocky + 1, true)
	.eval pushablePieces.put(Piece.AutoRocky + 2, true)
	.eval pushablePieces.put(Piece.AutoRocky + 3, true)

	.eval pushablePieces.put(Piece.Timer0, true)
	.eval pushablePieces.put(Piece.Timer1, true)
	.eval pushablePieces.put(Piece.Timer2, true)
	.eval pushablePieces.put(Piece.Timer3, true)
	.eval pushablePieces.put(Piece.Timer4, true)
	.eval pushablePieces.put(Piece.Timer5, true)
	.eval pushablePieces.put(Piece.Timer6, true)
	.eval pushablePieces.put(Piece.Timer7, true)
	.eval pushablePieces.put(Piece.Timer8, true)
	.eval pushablePieces.put(Piece.Timer9, true)

	.eval pushablePieces.put(Piece.Twister, true)
	.eval pushablePieces.put(Piece.Twister + 1, true)
	.eval pushablePieces.put(Piece.Gnasher, true)
	.eval pushablePieces.put(Piece.Gnasher + 1, true)
	.eval pushablePieces.put(Piece.Blob, true)
	.eval pushablePieces.put(Piece.Blob + 1, true)
	.eval pushablePieces.put(Piece.Virus, true)
	.eval pushablePieces.put(Piece.Virus + 1, true)
	.eval pushablePieces.put(Piece.Spike, true)
	.eval pushablePieces.put(Piece.Spike + 1, true)

	.eval pushablePieces.put(Piece.BlackholeFull, true)
	.eval pushablePieces.put(Piece.BlackholeFull + 1, true)
	.eval pushablePieces.put(Piece.BlackholeFull + 2, true)
	.eval pushablePieces.put(Piece.BlackholeFull + 3, true)
}

.namespace Text {
	.label UpperCodeBase = 1
	.label LowerCodeBase = 27
	.label NumberCodeBase = 53
	.label Terminator = $ff
}

.function UncapitaliseText(list) {
	.var result = List()
	.var prevNotSpace = false
	.for (var i = 0; i < list.size(); i++) {
		.var c = list.get(i)
		.eval result.add(prevNotSpace && c >= 'A' && c <= 'Z' ? c + 32 : c)
		.eval prevNotSpace = c != ' '
	}
	.return result
}

.define charCodes {
	.var baseCharCodes = " ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789.,:!?-'()&/@"
	.var charCodes = Hashtable()
	.for (var i = 0; i < baseCharCodes.size(); i++) {
		.eval charCodes.put(baseCharCodes.charAt(i) * 1, i)
	}
	.var codeA = charCodes.get('A' * 1)
	.var codeE = charCodes.get('E' * 1)
	.var codeI = charCodes.get('I' * 1)
	.var codeO = charCodes.get('O' * 1)
	.var codeU = charCodes.get('U' * 1)
	.var codeSmallA = charCodes.get('a' * 1)
	.var codeSmallE = charCodes.get('e' * 1)
	.var codeSmallI = charCodes.get('i' * 1)
	.var codeSmallO = charCodes.get('o' * 1)
	.var codeSmallU = charCodes.get('u' * 1)
	.for (var i = $c0; i < $c7; i++) .eval charCodes.put(i, codeA)
	.for (var i = $c8; i < $cc; i++) .eval charCodes.put(i, codeE)
	.for (var i = $cc; i < $d0; i++) .eval charCodes.put(i, codeI)
	.for (var i = $d2; i < $d7; i++) .eval charCodes.put(i, codeO)
	.for (var i = $d9; i < $dd; i++) .eval charCodes.put(i, codeU)
	.for (var i = $e0; i < $e7; i++) .eval charCodes.put(i, codeSmallA)
	.for (var i = $e8; i < $ec; i++) .eval charCodes.put(i, codeSmallE)
	.for (var i = $ec; i < $f0; i++) .eval charCodes.put(i, codeSmallI)
	.for (var i = $f2; i < $f7; i++) .eval charCodes.put(i, codeSmallO)
	.for (var i = $f9; i < $fd; i++) .eval charCodes.put(i, codeSmallU)
}

.macro MakeStringFromList(list) {
	.for (var i = 0; i < list.size(); i++) {
		.var c = list.get(i) * 1
		.if (charCodes.containsKey(c)) {
			.byte charCodes.get(c)
		} else {
			.print "Unkonwn character " + toHexString(c)
		}
	}
	.byte Text.Terminator
}

.macro MakeString(text) {
	.var list = List()
	.for (var i = 0; i < text.size(); i++) {
		.eval list.add(text.charAt(i))
	}
	MakeStringFromList(list)
}

.define textCharWidths {
	.var textCharWidths = List()

	.for (var i = 0; i < textCharSet.getSize(); i += 16) {
		.var onBits = 0
		.for (var j = 0; j < 16; j++) {
			.eval onBits = onBits | textCharSet.get(i + j)
		}
		.var width = 1
		.while (onBits != 0) {
			.eval width++;
			.eval onBits = (onBits << 1) & $ff
		}
		.eval textCharWidths.add(width > 1 ? width : 3)
	}
}

.function GetUnderlayRowBits(byte) {
	.return ((byte & $80) >> 4) | ((byte & $20) >> 3) | ((byte & $08) >> 2)
}

.var underlaysByChar = List()
.for (var i = $80; i < $100; i++) {
	.var base = i << 3
	.var r1 = GetUnderlayRowBits(charSet.get(base + 1))
	.var r2 = GetUnderlayRowBits(charSet.get(base + 2))
	.var r3 = GetUnderlayRowBits(charSet.get(base + 3))
	.var r4 = GetUnderlayRowBits(charSet.get(base + 4))
	.var r5 = GetUnderlayRowBits(charSet.get(base + 5))
	.var bits = r1 | (r2 << 4) | (r3 << 8) | (r4 << 12) | (r5 << 16)
	.eval underlaysByChar.add(bits)
}

.var underlayIndicesByImage = Hashtable()
.var underlayIndicesByChar = List()
.var underlays = List()
.for (var i = 0; i < $80; i++) {
	.var bits = underlaysByChar.get(i)
	.if (underlayIndicesByImage.containsKey(bits)) {
		.eval underlayIndicesByChar.add(underlayIndicesByImage.get(bits))
	} else {
		.var index = underlayIndicesByImage.keys().size()
		.eval underlayIndicesByImage.put(bits, index)
		.eval underlayIndicesByChar.add(index)
		.eval underlays.add(bits)
	}
}

.while (underlays.size() < 16) {
	.eval underlays.add(0)
}

.macro IncludeUnderlays(shift) {
	.for (var i = 0; i < 16; i++) {
		.for (var j = 0; j < 16; j++) {
			.var bits1 = (underlays.get(i) >> shift) & $0f
			.var bits2 = (underlays.get(j) >> shift) & $0f
			.byte (bits1 << 4) | bits2
		}
	}	
}

.macro IncludePlayerSprites() {
	.var partDirsX = List()
	.var partDirsY = List()
	.eval partDirsX.add(-1.25)
	.eval partDirsX.add(2.25)
	.eval partDirsX.add(2)
	.eval partDirsX.add(-1.25)
	.eval partDirsX.add(-3)
	.eval partDirsY.add(-2.75)
	.eval partDirsY.add(-1.75)
	.eval partDirsY.add(2)
	.eval partDirsY.add(2.25)
	.eval partDirsY.add(0)
	.for (var i = 0; i < 8; i++) {
		.var sprite = List()
		
		.for (var j = 0; j < $80; j++) {
			.eval sprite.add(0)
		}
		.for (var j = 0; j < 5; j++) {
			.var dx = round(partDirsX.get(j) * i / 3)
			.var dy = round(partDirsY.get(j) * i / 3)
			.var si = 22
			.var ti = 22 + floor(dx / 8) + dy * 3
			.var sh = mod(dx + 8, 8)
			.for (var k = 0; k < 7; k++) {
				.var b1 = playerSprites.uget(((j + 1) << 7) + si + k * 3)
				.var b2 = playerSprites.uget(((j + 1) << 7) + si + k * 3 + 64)
				.var ti1 = ti + k * 3
				.var ti2 = ti + k * 3 + 64
				.eval sprite.set(ti1, sprite.get(ti1) | (b1 >> sh))
				.eval sprite.set(ti1 + 1, sprite.get(ti1 + 1) | (b1 << (8 - sh)))
				.eval sprite.set(ti2, sprite.get(ti2) | (b2 >> sh))
				.eval sprite.set(ti2 + 1, sprite.get(ti2 + 1) | (b2 << (8 - sh)))
			}
		}
		.for (var j = 0; j < $80; j++) {
			.byte sprite.get(j)
		}
	}
}

.pseudocommand center_x parentWidth : childWidth  {
	sec
	lda parentWidth
	sbc childWidth
	sta I
	lda ArgHigh(parentWidth)
	sbc ArgHigh(childWidth)
	lsr
	ror I
	ldx I	
}