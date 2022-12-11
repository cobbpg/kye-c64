.function Map(params) {
	.eval params = params + ","
	.var map = Hashtable()
	.var name = ""
	.var value = ""
	.var inValue = false
	.for (var i = 0; i < params.size(); i++) {
		.var c = params.charAt(i)
		.if (c == ',') {
			.eval map.put(name, value)
			.eval name = ""
			.eval value = ""
			.eval inValue = false
		} else .if (c == '=') {
			.eval inValue = true
		} else .if (c != ' ') {
			.if (inValue) {
				.eval value = value + c
			} else {
				.eval name = name + c
			}
		}
	}
	.return map
}

.function ArgHigh(arg) {
	.var type = arg.getType()
	.return CmdArgument(type, type == AT_IMMEDIATE ? >arg.getValue() : arg.getValue() + 1)
}

.pseudocommand movb src : dst {
	lda src
	sta dst
}

.pseudocommand movw src : dst {
	lda src
	sta dst
	lda ArgHigh(src)
	sta ArgHigh(dst)
}

.pseudocommand addw src : dst {
		clc
		lda dst
		adc src
		sta dst
		lda ArgHigh(dst)
		adc ArgHigh(src)
		sta ArgHigh(dst)
}

.namespace System {
	.label ZeroPage = $00
	.label MemoryMap = $01
	.label NmiVector = $fffa
	.label IrqVector = $fffe
}

.namespace VIC {
	.label SpriteX0 = $d000
	.label SpriteY0 = $d001
	.label SpriteX1 = $d002
	.label SpriteY1 = $d003
	.label SpriteX2 = $d004
	.label SpriteY2 = $d005
	.label SpriteX3 = $d006
	.label SpriteY3 = $d007
	.label SpriteX4 = $d008
	.label SpriteY4 = $d009
	.label SpriteX5 = $d00a
	.label SpriteY5 = $d00b
	.label SpriteX6 = $d00c
	.label SpriteY6 = $d00d
	.label SpriteX7 = $d00e
	.label SpriteY7 = $d00f
	.label SpriteXHigh = $d010
	.label SpriteXExpand = $d01d
	.label SpriteYExpand = $d017
	.label SpriteEnable = $d015
	.label SpritePriority = $d01b
	.label SpriteColorMode = $d01c
	.label SpriteMultiColor1 = $d025
	.label SpriteMultiColor2 = $d026
	.label SpriteColor0 = $d027
	.label SpriteColor1 = $d028
	.label SpriteColor2 = $d029
	.label SpriteColor3 = $d02a
	.label SpriteColor4 = $d02b
	.label SpriteColor5 = $d02c
	.label SpriteColor6 = $d02d
	.label SpriteColor7 = $d02e

	.label RasterLine = $d012

	.label ScreenControl1 = $d011
	.label ScreenControl2 = $d016
	.label MemorySetup = $d018
	.label InterruptStatus = $d019
	.label InterruptControl = $d01a

	.label BorderColor = $d020
	.label BackgroundColor = $d021
	.label ExtraBackgroundColor1 = $d022
	.label ExtraBackgroundColor2 = $d023
	.label ExtraBackgroundColor3 = $d024

	.label ColorRam = $d800
}

.namespace SID {
	.label VolumeAndFilter = $d418
}

.namespace CIA1 {
	.label KeyMatrixCols = $dc00
	.label KeyMatrixRows = $dc01
	.label Joy2 = $dc00
	.label Joy1 = $dc01
	.label PortADataDir = $dc02
	.label PortBDataDir = $dc03
	.label InterruptStatus = $dc0d
}

.namespace CIA2 {
	.label PortAVicBank	 = $dd00
	.label PortADataDir = $dd02
	.label TimerA = $dd04
	.label InterruptStatus = $dd0d
	.label TimerAControl = $dd0e
}

.function MemoryMap(mode) {
	.if (mode == "ram")    .return %00110100
	.if (mode == "io")     .return %00110101
	.if (mode == "kernal") .return %00110110
	.if (mode == "basic")  .return %00110111
	.return 0
}

.function ScreenControl1(params) {
	.var map = Map(params)
	.var keys = map.keys()
	.var result = 0
	.for (var i = 0; i < keys.size(); i++) {
		.var key = keys.get(i)
		.var value = map.get(key)
		.if (key == "mode") {
			.eval result = result | (value == "text" ? $10 : value == "bitmap" ? $30 : value == "ecm" ? $50 : 0)
		}
		.if (key == "vertical_scroll") {
			.eval result = result | (value.asNumber() & 7)
		}
		.if (key == "screen_height") {
			.eval result = result | (value == "25" ? $08 : 0)
		}
		.if (key == "raster_msb") {
			.eval result = result | (value == "1" ? $80 : 0)
		}
	}
	.return result
}

.function ScreenControl2(params) {
	.var map = Map(params)
	.var keys = map.keys()
	.var result = 0
	.for (var i = 0; i < keys.size(); i++) {
		.var key = keys.get(i)
		.var value = map.get(key)
		.if (key == "horizontal_scroll") {
			.eval result = result | (value.asNumber() & 7)
		}
		.if (key == "screen_width") {
			.eval result = result | (value == "40" ? $08 : 0)
		}
		.if (key == "multicolor") {
			.eval result = result | (value == "on" ? $10 : 0)
		}
	}
	.return result
}

.function MemorySetup(params) {
	.var map = Map(params)
	.var keys = map.keys()
	.var result = 0
	.for (var i = 0; i < keys.size(); i++) {
		.var key = keys.get(i)
		.var value = map.get(key)
		.if (key == "screen") {
			.eval result = result | (((value.asNumber(16) & $3fff) >> 10) << 4)
		}
		.if (key == "charset") {
			.eval result = result | (((value.asNumber(16) & $3fff) >> 11) << 1)
		}
		.if (key == "bitmap") {
			.eval result = result | (value == "1" ? 8 : 0)
		}
	}
	.return result
}

.function GetSpriteXHigh(x0, x1, x2, x3, x4, x5, x6, x7) {
	.return ((x0 >> 8) & $01) | ((x1 >> 7) & $02) | ((x2 >> 6) & $04) | ((x3 >> 5) & $08) | ((x4 >> 4) & $10) | ((x5 >> 3) & $20) | ((x6 >> 2) & $40) | ((x7 >> 1) & $80)
}

.function GetBitmapColor(foreground, background) {
	.return background | (foreground << 4)
}

.macro SetVicBank(bank) {
		lda CIA2.PortADataDir
		ora #$03
		sta CIA2.PortADataDir
		lda CIA2.PortAVicBank
		and #$fc
		ora #(bank ^ 3)
		sta CIA2.PortAVicBank	
}