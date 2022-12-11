#import "system.asm"
#import "data.asm"

.const LEVEL_PACK_INDEX = 0
.const LEVEL_INDEX = 0
.const SHOW_TITLE_SCREEN = true
.const SHOW_LEVEL_PICKER = true
.const START_ON_FIRE = false

.macro SetCurrentColorPtr(screenPtr) {
		lda screenPtr
		sta ColorPtr
		lda screenPtr + 1
		eor #>(Screen.Address ^ VIC.ColorRam)
		sta ColorPtr + 1	
}

.macro SetScreenPtrRowY() {
		lda RowAddressesLow,y
		sta ScreenPtr
		lda RowAddressesHigh,y
		sta ScreenPtr + 1
}

.macro DisplayFixedText(textPtr, charX, charY, offsetX, spacing) {
		ldx #charX
		ldy #charY
		jsr SetTargetCharPtrByPosition
		movw #textPtr : TextPtr
		ldx #offsetX
		ldy #spacing
		jsr DisplayText
}

.macro SetFixedTargetCharPtrByCode(code) {
		movw #(CharSet + code * 8) : TargetCharPtr
}

* = $02 "Global Variables" virtual

RandomIndex1:	.byte 0
RandomIndex2:	.byte 0
I:	.byte 0
J:	.byte 0
K:	.byte 0
L:	.byte 0
UX:	.byte 0
UY:	.byte 0
RX:	.byte 0
RY:	.byte 0
PX:	.byte 0
PY:	.byte 0
Tile:	.byte 0
RollDirs:	.byte 0
Counter:	.byte 0
FrameCounter:	.byte 0

LevelPackPtr:	.word 0
LevelPtr:	.word 0
ScreenPtr:	.word 0
ScreenPtrBackup:	.word 0
ColorPtr:	.word 0
SourcePtr:	.word 0
TargetPtr:	.word 0
FarScreenPtr:	.word 0
IndexPtr:	.word 0
StickerFieldPtr:	.word 0
TextPtr:	.word 0
TargetCharLeftPtr:
TargetCharPtr:	.word 0
TargetCharBottomPtr:	.word 0
TargetCharRightPtr:	.word 0
UnderlayBasePtr:	.word 0

.namespace Text {
	CurrentShift:	.byte 0
	LeftByte:	.byte 0
	RightByte:	.byte 0
	CharOffsetHigh:	.byte 0
	Width:	.word 0

	.label StatusBarWidth = 20

	.label TitleBarBaseCode = Piece.Unused
	.label StatusBarBaseCode = TitleBarBaseCode + 80
	.label DiamondsBaseCode = StatusBarBaseCode + 8
	.label LivesBaseCode = StatusBarBaseCode + 18

	.label DiamondBase = CharSet + (Piece.Diamond << 3)

	.label BitShiftTables = $b000
}

.namespace Screen {
	.label Address = $0400
	.label Width = 40
	.label Height = 25
}

.namespace Underlay {
	.label SpriteStartY = 7 // Picked to avoid interference from badlines
	.label Y = 71 - SpriteStartY
	.label X = (Level.ScreenX + 3) * 8
	.label X1 = Underlay.X + 48 * 0
	.label X2 = Underlay.X + 48 * 1
	.label X3 = Underlay.X + 48 * 2
	.label X4 = Underlay.X + 48 * 3
	.label X5 = Underlay.X + 48 * 4
}

.namespace Level {
	.label ScreenX = 5
	.label ScreenY = 3
	.label Width = 30
	.label Height = 20
	.label InnerWidth = Width - 2
	.label InnerHeight = Height - 2
	.label ScreenOffset = ScreenY * Screen.Width + ScreenX
	.label StickerOrigin = Screen.Width * 2 + 2
	.label FreeObjectIndex = $ff

	ObjectCount:	.byte 0
	ObjectIndex:	.byte 0
	DefragNeeded:	.byte 0
	Diamonds:	.word 0
	RockySide:	.byte 0
	TileUnderPlayer:	.byte 0
	RevealedTile:	.byte 0

	DiamondAnimationFrame:	.byte 0
	DiamondAnimationCounter:	.byte 0

	.label State = $e000

	.label ObjectIndices = State
	.label StickerField = State + $400

	.label ObjectCounters = State + $800
	.label ObjectTypes = State + $900
	.label ObjectXs = State + $a00
	.label ObjectYs = State + $b00
	.label ObjectStates = State + $c00
}

.namespace Input {
	.label StateMask = $7f
	.label CounterMask = $1f
	.label DirectionMask = $80
	.label TriggerMask = $40
	.label RepeatMask = $20

	.label StateIdle = $00
	.label StateFirstTrigger = TriggerMask
	.label StateNextTrigger = TriggerMask | RepeatMask

	Buffer:	.byte 0
	// State bits: %btfccccc, where b = direction, t = trigger, f = first/next, c = frame counter
	HorizontalState:	.byte 0
	VerticalState:	.byte 0
	// Copies of the state made on trigger frames (c = 0), acknowledged by update logic so no input is missed
	HorizontalTrigger:	.byte 0
	VerticalTrigger:	.byte 0
}

.namespace Player {
	X:	.byte 0
	Y:	.byte 0
	StartX:	.byte 0
	StartY:	.byte 0
	Lives:	.byte 0
	TargetTile:	.byte 0
	DeathPhase:	.byte 0

	.label ForceUpdate = $ff
}

.namespace PauseMenu {
	.label SpriteY = 232
	.label ItemsCount = 3

	Active:	.byte 0
	Index:	.byte 0
	CurrentX:	.byte 0
	TargetX:	.byte 0
	FadeIndex:	.byte 0
}

.namespace Menu {
	.label Sprites = $da80
	.label Colors = $dc00
	.label Bitmap = $e000
	.label ContentsY = 7
	.label LevelPacksX = 4
	.label LevelsX = 24
	.label LevelsY = ContentsY + 3
	.label LevelsCount = 7
	.label PackTitleWidth = 18
	.label LevelTitleWidth = 14

	Active:	.byte 0
	PackIndex:	.byte 0
	LevelIndex:	.byte 0
	CurrentPane:	.byte 0
	ScrollIndicators:	.byte 0

	RefreshingLevelIndex:	.byte 0
	RefreshingLevelTargetIndex:	.byte 0
	LevelFadeStates:	.fill LevelsCount, 0
}

.print "Unused charset memory: " + ($100 - (Text.StatusBarBaseCode + 40)) * 8

* = $0801 "Basic Upstart"

BasicUpstart(Init)

* = $080d "Main"

Init:
	sei

	movb #MemoryMap("io") : System.MemoryMap

	movb #ScreenControl1("mode=off") : VIC.ScreenControl1
	movb #Colors.Border : VIC.BorderColor
	movb #Colors.Background : VIC.BackgroundColor

	// Disable all interrupts
	movw #NonMaskableInterrupt : System.NmiVector
	lda #0
	sta CIA2.TimerAControl // Stop timer
	sta CIA2.TimerA
	sta CIA2.TimerA + 1
	lda #%10000001
	sta CIA2.InterruptStatus
	lda #%00000001
	sta CIA2.TimerAControl // Start timer (fires immediately)
	lda #%01111111
	sta CIA1.InterruptStatus
	jsr InitFrameInterrupt

	lda #0
	sta VIC.SpriteEnable
	sta Input.HorizontalState
	sta Input.VerticalState
	sta Menu.CurrentPane
	jsr InitMusic
	lda #LEVEL_PACK_INDEX
	sta Menu.PackIndex
	lda #LEVEL_INDEX
	sta Menu.LevelIndex

.if (START_ON_FIRE) {
		lda #$10
	!:	bit CIA1.Joy2
		bne !-
	!:	bit CIA1.Joy2
		beq !-
}

	cli

	.if (SHOW_TITLE_SCREEN) {
			jmp ShowTitleScreen
	} else .if (SHOW_LEVEL_PICKER) {
			jmp ShowLevelPicker
	} else {
			jmp StartLevel
	}

InitFrameInterrupt: {
		lda #0
		sta VIC.RasterLine // Interrupt at the start of the next frame
		lda #%00000001
		sta VIC.InterruptControl // Enable raster interrupts
		movw #FrameInterrupt : System.IrqVector
		rts
}

FrameInterrupt: {
		pha
		stx XBackup
		sty YBackup
		movb System.MemoryMap : MemoryMapBackup
		movb #MemoryMap("io") : System.MemoryMap
		jsr ProcessInput
		jsr PlayMusicFrame
		inc FrameCounter
		lda Menu.Active
		beq InitGameFrame
		jmp Done
	InitGameFrame:
		lda #%11111000
		sta VIC.SpritePriority
		jsr UpdatePlayerSprite
		lda #((UnderlaySprites >> 6) + 0 * 8)
		sta Screen.Address + $3fb
		lda #((UnderlaySprites >> 6) + 1 * 8)
		sta Screen.Address + $3fc
		lda #((UnderlaySprites >> 6) + 2 * 8)
		sta Screen.Address + $3fd
		lda #((UnderlaySprites >> 6) + 3 * 8)
		sta Screen.Address + $3fe
		lda #((UnderlaySprites >> 6) + 4 * 8)
		sta Screen.Address + $3ff
		lda #Underlay.Y
		sta VIC.SpriteY3
		sta VIC.SpriteY4
		sta VIC.SpriteY5
		sta VIC.SpriteY6
		sta VIC.SpriteY7
		lda #(Underlay.Y + 1)
		sta VIC.RasterLine
		movw #UnderlayMoveInterrupt : System.IrqVector
		dec Level.DiamondAnimationCounter
		bpl Done
		lda #(Frequency.DiamondAnimationFrames - 1)
		sta Level.DiamondAnimationCounter
		ldx Level.DiamondAnimationFrame
		inx
		cpx #6
		bcc !+
		ldx #0
	!:	stx Level.DiamondAnimationFrame
		txa
		asl
		asl
		asl
		tax
		lda DiamondFrames,x
		sta Text.DiamondBase
		lda DiamondFrames + 1,x
		sta Text.DiamondBase + 1
		lda DiamondFrames + 2,x
		sta Text.DiamondBase + 2
		lda DiamondFrames + 3,x
		sta Text.DiamondBase + 3
		lda DiamondFrames + 4,x
		sta Text.DiamondBase + 4
		lda DiamondFrames + 5,x
		sta Text.DiamondBase + 5
		lda DiamondFrames + 6,x
		sta Text.DiamondBase + 6
	Done:
		asl VIC.InterruptStatus
	.label XBackup = * + 1
		ldx #0
	.label YBackup = * + 1
		ldy #0
	.label MemoryMapBackup = * + 1
		lda #0
		sta System.MemoryMap
		pla
	@NonMaskableInterrupt:
		rti
}

UnderlayMoveInterrupt: {
		pha
		lda VIC.SpriteY3
		clc
		adc #21
		cmp #(Underlay.Y + 21 * 8)
		bcs EndFrame
		sta VIC.SpriteY3
		sta VIC.SpriteY4
		sta VIC.SpriteY5
		sta VIC.SpriteY6
		sta VIC.SpriteY7
		sta VIC.RasterLine
		movw #UnderlayUpdateInterrupt : System.IrqVector
		jmp Done
	EndFrame:
		lda PauseMenu.Active
		bne ShowPauseMenu
		sta VIC.RasterLine
		movw #FrameInterrupt : System.IrqVector
		jmp Done
	ShowPauseMenu:
		lda #(PauseMenu.SpriteY - 2)
		sta VIC.RasterLine
		movw #PauseMenuInterrupt : System.IrqVector
	Done:
		asl VIC.InterruptStatus
		pla
		rti
}

UnderlayUpdateInterrupt: {
		pha
		inc Screen.Address + $3fb
		inc Screen.Address + $3fc
		inc Screen.Address + $3fd
		inc Screen.Address + $3fe
		inc Screen.Address + $3ff
		lda VIC.SpriteY3
		clc
		adc #04
		sta VIC.RasterLine
		movw #UnderlayMoveInterrupt : System.IrqVector
		asl VIC.InterruptStatus
		pla
		rti
}

PauseMenuInterrupt: {
		pha
		lda PauseMenu.Active
		beq Done
		lda #PauseMenu.SpriteY
		sta VIC.SpriteY1
		lda #Colors.Background
		sta VIC.SpriteColor1
		lda PauseMenu.CurrentX
		sta VIC.SpriteX1
		clc
		adc Level.DiamondAnimationFrame
		sta VIC.SpriteX2
		lda #((PauseSprites >> 6) + 1)
		sta Screen.Address + $3f9
		lda #%11111011
		sta VIC.SpritePriority
		lda #GetSpriteXHigh(0, 0, 0, Underlay.X1, Underlay.X2, Underlay.X3, Underlay.X4, Underlay.X5)
		sta VIC.SpriteXHigh
	Done:
		lda #0
		sta VIC.RasterLine
		movw #FrameInterrupt : System.IrqVector
		asl VIC.InterruptStatus
		pla
		rti
}

SetupSprites: {
		lda #0
		sta VIC.SpriteX0
		sta VIC.SpriteX1
		sta VIC.SpriteX2

		lda #PauseMenu.SpriteY
		sta VIC.SpriteY2

		lda #Underlay.X1
		sta VIC.SpriteX3
		lda #Underlay.X2
		sta VIC.SpriteX4
		lda #Underlay.X3
		sta VIC.SpriteX5
		lda #Underlay.X4
		sta VIC.SpriteX6
		lda #Underlay.X5
		sta VIC.SpriteX7
		lda #GetSpriteXHigh(0, 0, 0, Underlay.X1, Underlay.X2, Underlay.X3, Underlay.X4, Underlay.X5)
		sta VIC.SpriteXHigh

		lda #Colors.KyeOutline
		sta VIC.SpriteColor0
		lda #Colors.Kye
		sta VIC.SpriteColor1

		lda #Colors.Underlay
		sta VIC.SpriteColor3
		sta VIC.SpriteColor4
		sta VIC.SpriteColor5
		sta VIC.SpriteColor6
		sta VIC.SpriteColor7

		lda #LIGHT_BLUE
		sta VIC.SpriteMultiColor1
		lda #CYAN
		sta VIC.SpriteMultiColor2
		lda #PURPLE
		sta VIC.SpriteColor2

		lda #((PlayerSprites >> 6) + 1)
		sta Screen.Address + $3f8
		lda #((PlayerSprites >> 6) + 0)
		sta Screen.Address + $3f9
		lda #((PauseSprites >> 6) + 0)
		sta Screen.Address + $3fa

		lda #0
		sta VIC.SpriteYExpand
		lda #%00000100
		sta VIC.SpriteColorMode

		lda #%11111000
		sta VIC.SpriteXExpand
		sta VIC.SpritePriority
		lda #%11111111
		sta VIC.SpriteEnable

		lda #(Level.Height - 1)
		sta PY
	Rows:
		lda #((Level.Width - 2) / 2)
		sta PX
	Row:
		ldx PX
		ldy PY
		jsr RefreshUnderlayTilePair
		dec PX
		bpl Row
		dec PY
		bpl Rows

		rts
}

// Skip over X strings at the beginning of the currently active level data and return the offset in Y.
SkipLevelDataText: {
		ldy #0
	Loop:
		lda (LevelPtr),y
		iny
		cmp #Text.Terminator
		bne Loop
		dex
		bne Loop
		rts
}

SetupScreen: {
		movb #MemoryMap("ram") : System.MemoryMap

		lda #0
		sta FrameCounter
		sta RandomIndex1
		sta RandomIndex2
		sta Level.DiamondAnimationFrame
		sta Level.DiamondAnimationCounter

		movw #(Screen.Address + Screen.Width) : ScreenPtr
		lda #Screen.Width
		ldx #Text.TitleBarBaseCode
		jsr PrepareTextArea
		SetFixedTargetCharPtrByCode(Text.TitleBarBaseCode)
		lda #Screen.Width
		jsr ClearTextArea
		ldx #1
		jsr SkipLevelDataText
		sty I
		clc
		lda LevelPtr
		adc I
		sta TextPtr
		lda LevelPtr + 1
		adc #0
		sta TextPtr + 1
		jsr MeasureText
		SetFixedTargetCharPtrByCode(Text.TitleBarBaseCode)
		center_x #320 : Text.Width
		ldy #0
		jsr DisplayText

		movw #StatusBarText : TextPtr
		jsr UpdateStatusBarText
		jsr UpdateDiamondCount
		jsr UpdateLivesCount

		movb #MemoryMap("io") : System.MemoryMap

		rts
}

RefreshUnderlayTilePair: {
		stx UX
		sty UY

		stx I
		asl I
		clc
		lda RowAddressesLow,y
		adc I
		sta ScreenPtr
		lda RowAddressesHigh,y
		adc #0
		sta ScreenPtr + 1
		ldy #0
		lda (ScreenPtr),y
		tax
		lda TopNybbles,x
		sta J
		iny
		lda (ScreenPtr),y
		tax
		lda BottomNybbles,x
		ora J
		sta J

		ldx UX
		ldy UY
		clc
		lda UnderlayColumnAddressesLow,x
		adc UnderlayRowOffsetsLow,y
		sta UnderlayBasePtr
		lda UnderlayColumnAddressesHigh,x
		adc UnderlayRowOffsetsHigh,y
		sta UnderlayBasePtr + 1
		ldx UnderlayFillTypes,y
		beq FillUnderlaySingle
		lda UnderlayFillAddressesLow,x
		sta FillAddress
		lda UnderlayFillAddressesHigh,x
		sta FillAddress + 1
		ldx J
		ldy #0
	.label FillAddress = * + 1
		jmp FillUnderlaySingle

	@FillUnderlaySingle:
		ldx J
		ldy #0
		lda UnderlayImagesRow1,x
		sta (UnderlayBasePtr),y
		iny
		iny
		iny
		lda UnderlayImagesRow2,x
		sta (UnderlayBasePtr),y
		iny
		iny
		iny
		lda UnderlayImagesRow3,x
		sta (UnderlayBasePtr),y
		iny
		iny
		iny
		lda UnderlayImagesRow4,x
		sta (UnderlayBasePtr),y
		iny
		iny
		iny
		lda UnderlayImagesRow5,x
		sta (UnderlayBasePtr),y
		rts

	@FillUnderlayRow17:
		lda UnderlayImagesRow1,x
		sta (UnderlayBasePtr),y
		iny
		iny
		iny
		lda UnderlayImagesRow2,x
		sta (UnderlayBasePtr),y
		iny
		iny
		iny
		lda UnderlayImagesRow3,x
		sta (UnderlayBasePtr),y
		iny
		iny
		iny
		lda UnderlayImagesRow4,x
		sta (UnderlayBasePtr),y
		iny
		iny
		iny
		iny
		lda UnderlayImagesRow5,x
		sta (UnderlayBasePtr),y
		rts

	@FillUnderlayRow18:
		lda UnderlayImagesRow1,x
		sta (UnderlayBasePtr),y
		iny
		iny
		iny
		lda UnderlayImagesRow2,x
		sta (UnderlayBasePtr),y
		iny
		iny
		iny
		lda UnderlayImagesRow3,x
		sta (UnderlayBasePtr),y
		iny
		iny
		iny
		iny
		lda UnderlayImagesRow4,x
		sta (UnderlayBasePtr),y
		iny
		iny
		iny
		lda UnderlayImagesRow5,x
		sta (UnderlayBasePtr),y
		rts

	@FillUnderlayRow19:
		lda UnderlayImagesRow1,x
		sta (UnderlayBasePtr),y
		iny
		iny
		iny
		lda UnderlayImagesRow2,x
		sta (UnderlayBasePtr),y
		iny
		iny
		iny
		iny
		lda UnderlayImagesRow3,x
		sta (UnderlayBasePtr),y
		iny
		iny
		iny
		lda UnderlayImagesRow4,x
		sta (UnderlayBasePtr),y
		iny
		iny
		iny
		lda UnderlayImagesRow5,x
		sta (UnderlayBasePtr),y
		rts

	@FillUnderlayRow20:
		lda UnderlayImagesRow1,x
		sta (UnderlayBasePtr),y
		iny
		iny
		iny
		iny
		lda UnderlayImagesRow2,x
		sta (UnderlayBasePtr),y
		iny
		iny
		iny
		lda UnderlayImagesRow3,x
		sta (UnderlayBasePtr),y
		iny
		iny
		iny
		lda UnderlayImagesRow4,x
		sta (UnderlayBasePtr),y
		iny
		iny
		iny
		lda UnderlayImagesRow5,x
		sta (UnderlayBasePtr),y
		rts
}

StartLevel: {
		jsr WaitForBottom
		movb #MemoryMap("io") : System.MemoryMap
		movb #ScreenControl1("mode=off") : VIC.ScreenControl1

		jsr LoadLevel
		jsr InitObjects
		jsr SetupSprites
		jsr SetupScreen
		
		jsr WaitForBottom
		SetVicBank(0)
		movb #MemorySetup("screen=400,charset=2000") : VIC.MemorySetup
		movb #ScreenControl1("mode=text,screen_height=25,vertical_scroll=0") : VIC.ScreenControl1
		lda #0
		sta PauseMenu.Active
		sta Menu.Active
		jsr ResetInput

	GameLoop:
		jsr Update
		jmp GameLoop
}

// Fill 1000 bytes at TargetPtr with the value in A.
FillScreenBuffer: {
		ldx #<1000
		ldy #>1000
}

// Fill YX bytes at TargetPtr with the value in A.
FillBuffer: {
		stx CountLow
		sty CountHigh
	.label CountHigh = * + 1
		ldx #0
		beq OuterDone
	Outer:
		ldy #0
	Inner:
		sta (TargetPtr),y
		iny
		bne Inner
		inc TargetPtr + 1
		dex
		bne Outer
	OuterDone:
	.label CountLow = * + 1
		ldy #0
		beq Done
	LastPage:
		dey
		sta (TargetPtr),y
		bne LastPage
	Done:
		rts
}

// Build active object list and lookup tables. Sets carry upon return if there are too many objects on the level.
InitObjects: {
		lda #3
		sta Player.Lives

		lda #Piece.Empty
		sta Level.TileUnderPlayer
		lda #0
		sta Player.DeathPhase

		lda #0
		sta Level.Diamonds
		sta Level.Diamonds + 1

		movw #Level.ObjectIndices : TargetPtr
		lda #Level.FreeObjectIndex
		jsr FillScreenBuffer

		lda #1
		ldx #0
		sta Counter
	CheckRows:
		ldy Counter
		lda RowAddressesLow,y
		sta ScreenPtr
		sta IndexPtr
		lda RowAddressesHigh,y
		sta ScreenPtr + 1
		lda ObjectIndexRowAddressesHigh,y
		sta IndexPtr + 1
		ldy #1
	CheckTiles:
		lda (ScreenPtr),y
		cmp #Piece.Active
		bcc Inactive
		sta Level.ObjectTypes,x
		txa
		sta (IndexPtr),y
		tya
		sta Level.ObjectXs,x
		lda Counter
		sta Level.ObjectYs,x
		lda #0
		sta Level.ObjectStates,x
		sty I
		ldy Level.ObjectTypes,x
		lda ActivePieceTimings - Piece.Active,y
		sta Level.ObjectCounters,x
		ldy I
		inx
		bne NextTile
		sec
		rts
	Inactive:
		cmp #Piece.Kye
		bne !+
		sty Player.X
		sty Player.StartX
		lda Counter
		sta Player.Y
		sta Player.StartY
		jmp NextTile
	!:	cmp #Piece.Diamond
		bne NextTile
		sed
		clc
		lda Level.Diamonds
		adc #1
		sta Level.Diamonds
		lda Level.Diamonds + 1
		adc #0
		sta Level.Diamonds + 1
		cld
	NextTile:
		iny
		cpy #Level.InnerWidth + 1
		bne CheckTiles
		inc Counter
		ldy Counter
		cpy #Level.InnerHeight + 1
		bne CheckRows
		// Terminator
		lda #Piece.Empty
		sta Level.ObjectTypes,x
		stx Level.ObjectCount

		movw #Level.StickerField : TargetPtr
		lda #0
		jsr FillScreenBuffer

		ldx #0
	InitStickerField:
		lda Level.ObjectTypes,x
		beq Done
		cmp #Piece.StickerLR
		bne CheckVertical
		stx L
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		tax
		jsr AddHorizontalStickerField
		ldx L
		jmp NextSticker
	CheckVertical:
		cmp #Piece.StickerTB
		bne NextSticker
		stx L
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		tax
		jsr AddVerticalStickerField
		ldx L
	NextSticker:
		inx
		bne InitStickerField

	Done:
		clc
		rts
}

WaitForFireRelease: {
		lda #$10
	!:	bit Input.Buffer
		beq !-
	!:	bit Input.Buffer
		bne !-
		rts	
}

UpdatePauseMenu: {
		lda PauseMenu.CurrentX
		cmp PauseMenu.TargetX
		beq CheckInput
		bcc MoveRight

	MoveLeft:
		lda PauseMenu.CurrentX
		sec
		sbc PauseMenu.TargetX
		clc
		adc #3
		lsr
		lsr
		eor #$ff
		sec
		adc PauseMenu.CurrentX
		sta PauseMenu.CurrentX
		rts

	MoveRight:
		lda PauseMenu.TargetX
		sec
		sbc PauseMenu.CurrentX
		clc
		adc #3
		lsr
		lsr
		clc
		adc PauseMenu.CurrentX
		sta PauseMenu.CurrentX
		rts

	CheckInput:
		lda Input.Buffer
		lsr
		lsr

	CheckLeft:
		lsr
		bcc CheckRight
		ldx PauseMenu.Index
		beq Done
		dex
		stx PauseMenu.Index
		lda PauseMenuXs,x
		sta PauseMenu.TargetX
		rts

	CheckRight:
		lsr
		bcc CheckFire
		ldx PauseMenu.Index
		cpx #(PauseMenu.ItemsCount - 1)
		beq Done
		inx
		stx PauseMenu.Index
		lda PauseMenuXs,x
		sta PauseMenu.TargetX
		rts

	CheckFire:
		lsr
		bcc Done
		jsr WaitForFireRelease
		lda PauseMenu.Index
		beq Resume
		cmp #1
		beq Restart

	Quit:
		jsr WaitForBottom
		movb #ScreenControl1("mode=off") : VIC.ScreenControl1
		jmp ShowLevelPicker

	Resume:
		jsr WaitForBottom
		lda #0
		sta PauseMenu.Active
		sta VIC.SpriteX2
		jsr FadeOutStatusBar
		movw #StatusBarText : TextPtr
		jsr UpdateStatusBarText
		jsr UpdateDiamondCount
		jsr UpdateLivesCount
		jsr FadeInStatusBar
		jsr ResetInput
		rts

	Restart:
		jsr WaitForBottom
		lda #0
		sta PauseMenu.Active
		jmp StartLevel

	Done:
		rts
}

Update: {
		lda PauseMenu.Active
		beq StepGame
		jsr UpdatePauseMenu
		jsr WaitForNextFrame
		rts

	StepGame:
		jsr UpdatePlayer
		jsr CheckPlayerAlive
		jsr UpdateLevel
		jsr CheckPlayerAlive

		lda Player.DeathPhase
		beq HandleInput
		ldx #Frequency.DeathTickFrames
		jsr WaitFrames
		lda Player.DeathPhase
		cmp #7
		bcs RevivePlayer
		inc Player.DeathPhase
		rts

	RevivePlayer:
		lda Player.Lives
		beq HandleInput

		// TODO try to find a free spot (the original game spirals counterclockwise starting from bottom left corners)
		lda Player.StartX
		sta Player.X
		ldy Player.StartY
		sty Player.Y
		SetScreenPtrRowY()
		ldy Player.X
		lda #Piece.Kye
		sta (ScreenPtr),y
		lda #0
		sta Player.DeathPhase
		sta Level.TileUnderPlayer
		jsr ResetInput

	HandleInput:
		jsr CheckEndGame
		jsr WaitForNextFrame
		rts
}

CheckPlayerAlive: {
		ldy Player.Y
		dey
		clc
		lda RowAddressesLow,y
		adc Player.X
		sta ScreenPtr
		lda RowAddressesHigh,y
		adc #0
		sta ScreenPtr + 1
		ldy #0
		lda (ScreenPtr),y
		tax
		lda PieceFlags,x
		and #$20
		bne KillPlayer
		ldy #(Screen.Width - 1)
		lda (ScreenPtr),y
		tax
		lda PieceFlags,x
		and #$20
		bne KillPlayer
		ldy #(Screen.Width + 1)
		lda (ScreenPtr),y
		tax
		lda PieceFlags,x
		and #$20
		bne KillPlayer
		ldy #(Screen.Width * 2)
		lda (ScreenPtr),y
		tax
		lda PieceFlags,x
		and #$20
		bne KillPlayer
		rts
}

KillPlayer: {
		lda Player.DeathPhase
		bne !+

		lda #<SoundDeath
		ldy #>SoundDeath
		ldx #14
		jsr PlaySoundEffect

		dec Player.Lives
		jsr UpdateLivesCount
		inc Player.DeathPhase
		ldy Player.Y
		SetScreenPtrRowY()
		ldy Player.X
		lda Level.TileUnderPlayer
		sta (ScreenPtr),y
		SetCurrentColorPtr(ScreenPtr)
		lda #Colors.Door
		sta (ColorPtr),y
	!:	rts
}

UpdateLivesCount: {
		lda Player.Lives
		clc
		adc #Text.NumberCodeBase
		sta CountText
		lda #$ff
		sta CountText + 1

	DisplayCount:
		SetFixedTargetCharPtrByCode(Text.LivesBaseCode)
		lda #2
		jsr ClearTextArea
		movw #CountText : TextPtr
		SetFixedTargetCharPtrByCode(Text.LivesBaseCode)
		ldx #3
		ldy #0
		jsr DisplayText

		rts
}


UpdatePlayer: {
		lda #0
		lda Player.DeathPhase
		beq CheckMovement
		rts

	CheckMovement:
		lda #Piece.Empty
		sta Player.TargetTile

	CheckUp: {
			bit Input.VerticalTrigger
			bpl CheckDown
			bvc CheckDown
		!:	ldy Player.Y
			dey
			beq DoneVertical
			SetScreenPtrRowY()
			ldy Player.X
			lda (ScreenPtr),y
			beq Move
			cmp #Piece.Earth
			beq Move
			cmp #Piece.DoorDU
			bne !+
			sta Player.TargetTile
			jmp Move
		!:	cmp #Piece.Diamond
			bne CheckPush
			jsr EatDiamond
			jmp Move
		CheckPush:
			tay
			lda PieceFlags,y
			bmi Push
			cpy #Piece.Blackhole
			bcc DoneVertical
			cpy #Piece.Blackhole + 4
			bcs DoneVertical
			jmp KillPlayer
		Push:
			lda Player.X
			ldy Player.Y
			dey
			jsr PushTileUp
			bcc DoneVertical
		Move:
			lda Level.TileUnderPlayer
			sta Level.RevealedTile
			lda Player.X
			ldy Player.Y
			dec Player.Y
			jsr MoveTileUp
			lda Player.TargetTile
			sta Level.TileUnderPlayer
	}

	DoneVertical: {
			lda #Player.ForceUpdate
			sta FrameCounter
			lda #0
			sta Input.VerticalTrigger
			rts
	}

	CheckDown: {
			bmi CheckLeft
			bvc CheckLeft
		!:	ldy Player.Y
			cpy #Level.InnerHeight
			beq DoneVertical
			iny
			SetScreenPtrRowY()
			ldy Player.X
			lda (ScreenPtr),y
			beq Move
			cmp #Piece.Earth
			beq Move
			cmp #Piece.DoorUD
			bne !+
			sta Player.TargetTile
			jmp Move
		!:	cmp #Piece.Diamond
			bne CheckPush
			jsr EatDiamond
			jmp Move
		CheckPush:
			tay
			lda PieceFlags,y
			bmi Push
			cpy #Piece.Blackhole
			bcc DoneVertical
			cpy #Piece.Blackhole + 4
			bcs DoneVertical
			jmp KillPlayer
		Push:
			lda Player.X
			ldy Player.Y
			iny
			jsr PushTileDown
			bcc DoneVertical
		Move:
			lda Level.TileUnderPlayer
			sta Level.RevealedTile
			lda Player.X
			ldy Player.Y
			inc Player.Y
			jsr MoveTileDown
			lda Player.TargetTile
			sta Level.TileUnderPlayer
			jmp DoneVertical
	}

	CheckLeft: {
			bit Input.HorizontalTrigger
			bpl CheckRight
			bvc CheckRight
		!:	ldy Player.X
			dey
			beq DoneHorizontal
			ldy Player.Y
			SetScreenPtrRowY()
			ldy Player.X
			dey
			lda (ScreenPtr),y
			beq Move
			cmp #Piece.Earth
			beq Move
			cmp #Piece.DoorRL
			bne !+
			sta Player.TargetTile
			jmp Move
		!:	cmp #Piece.Diamond
			bne CheckPush
			jsr EatDiamond
			jmp Move
		CheckPush:
			tay
			lda PieceFlags,y
			bmi Push
			cpy #Piece.Blackhole
			bcc DoneHorizontal
			cpy #Piece.Blackhole + 4
			bcs DoneHorizontal
			jmp KillPlayer
		Push:
			lda Player.X
			ldy Player.Y
			sec
			sbc #1
			jsr PushTileLeft
			bcc DoneHorizontal
		Move:
			lda Level.TileUnderPlayer
			sta Level.RevealedTile
			lda Player.X
			ldy Player.Y
			dec Player.X
			jsr MoveTileLeft
			lda Player.TargetTile
			sta Level.TileUnderPlayer
	}

	DoneHorizontal: {
			lda #Player.ForceUpdate
			sta FrameCounter
			lda #0
			sta Input.HorizontalTrigger
			rts
	}

	CheckRight: {
			bmi CheckFire
			bvc CheckFire
		!:	ldy Player.X
			cpy #Level.InnerWidth
			beq DoneHorizontal
			ldy Player.Y
			SetScreenPtrRowY()
			ldy Player.X
			iny
			lda (ScreenPtr),y
			beq Move
			cmp #Piece.Earth
			beq Move
			cmp #Piece.DoorLR
			bne !+
			sta Player.TargetTile
			jmp Move
		!:	cmp #Piece.Diamond
			bne CheckPush
			jsr EatDiamond
			jmp Move
		CheckPush:
			tay
			lda PieceFlags,y
			bmi Push
			cpy #Piece.Blackhole
			bcc DoneHorizontal
			cpy #Piece.Blackhole + 4
			bcs DoneHorizontal
			jmp KillPlayer
		Push:
			lda Player.X
			ldy Player.Y
			clc
			adc #1
			jsr PushTileRight
			bcc DoneHorizontal
		Move:
			lda Level.TileUnderPlayer
			sta Level.RevealedTile
			lda Player.X
			ldy Player.Y
			inc Player.X
			jsr MoveTileRight
			lda Player.TargetTile
			sta Level.TileUnderPlayer
			jmp DoneHorizontal
	}

	CheckFire: {
			lda Input.Buffer
			and #%00010000
			beq Done
			jsr WaitForFireRelease
			jsr FadeOutStatusBar
			movw #PauseMenuText : TextPtr
			jsr UpdateStatusBarText
			lda #0
			sta PauseMenu.Index
			lda PauseMenuXs
			sta PauseMenu.CurrentX
			sta PauseMenu.TargetX
			jsr FadeInStatusBar
			jsr WaitForBottom
			lda #1
			sta PauseMenu.Active

		Done:
			rts
	}
}

UpdatePlayerSprite: {
		lda Player.X
		asl
		asl
		asl
		clc
		adc #(Level.ScreenX * 8 + 24 - 8)
		sta VIC.SpriteX0
		sta VIC.SpriteX1
		lda VIC.SpriteXHigh
		bcc PlayerLowX
	PlayerHighX:
		ora #$03
		jmp SetXHigh
	PlayerLowX:
		and #$fc
	SetXHigh:
		sta VIC.SpriteXHigh

		lda Player.Y
		asl
		asl
		asl
		clc
		adc #(Level.ScreenY * 8 + 50 - 10)
		sta VIC.SpriteY0
		sta VIC.SpriteY1

		lax Player.DeathPhase
		asl
		clc
		adc #(PlayerSprites >> 6)
		sta Screen.Address + $3f9
		adc #1
		sta Screen.Address + $3f8

		lda PlayerColors,x
		sta VIC.SpriteColor1
		lda PlayerOverlayColors,x
		sta VIC.SpriteColor0

		rts
}

CheckEndGame: {
		lda Level.Diamonds
		ora Level.Diamonds + 1
		beq Victory

		lda Player.Lives
		beq LevelLost

		rts

	LevelLost:
		movw #LostText : TextPtr
		jmp ShowFinalStatusMessage

	Victory:
		inc Menu.LevelIndex
		movw #VictoryText : TextPtr
		jmp ShowFinalStatusMessage
}

ShowFinalStatusMessage: {
		jsr FadeOutStatusBar
		jsr UpdateStatusBarText
		jsr FadeInStatusBar
		jsr WaitForFireRelease
		jmp StartLevel
}

* = * "Game Logic"

EatDiamond: {
		lda #<SoundDiamond
		ldy #>SoundDiamond
		ldx #14
		jsr PlaySoundEffect

		sed
		sec
		lda Level.Diamonds
		sbc #1
		sta Level.Diamonds
		lda Level.Diamonds + 1
		sbc #0
		sta Level.Diamonds + 1
		cld
		jmp UpdateDiamondCount
}

UpdateDiamondCount: {
		ldx #0

		lda Level.Diamonds + 1
		beq CheckTwoDigits

	ThreeDigits:
		clc
		adc #Text.NumberCodeBase
		sta CountText,x
		inx
		jmp TwoDigits

	CheckTwoDigits:
		lda Level.Diamonds
		cmp #$10
		bcc OneDigit

	TwoDigits:
		lda Level.Diamonds
		lsr
		lsr
		lsr
		lsr
		clc
		adc #Text.NumberCodeBase
		sta CountText,x
		inx

	OneDigit:
		lda Level.Diamonds
		and #$0f
		clc
		adc #Text.NumberCodeBase
		sta CountText,x
		inx
		lda #$ff
		sta CountText,x

	DisplayCount:
		SetFixedTargetCharPtrByCode(Text.DiamondsBaseCode)
		lda #4
		jsr ClearTextArea
		movw #CountText : TextPtr
		SetFixedTargetCharPtrByCode(Text.DiamondsBaseCode)
		ldx #1
		ldy #0
		jsr DisplayText

		rts
}

UpdateLevel: {
		ldx FrameCounter
		lda Input.HorizontalState
		ora Input.VerticalState
		bne CheckIfJustMoved
		cpx #Frequency.IdleTickFrames
		bcs Update
	SkipUpdate:
		rts

	CheckIfJustMoved:
		cpx #Player.ForceUpdate
		bne SkipUpdate

	Update:
		ldx #0
		stx FrameCounter
		stx Level.DefragNeeded
		lda #Piece.Empty
		sta Level.RevealedTile		
	ProcessObjects:
		lda Level.ObjectTypes,x
		beq ObjectsDone
		bmi ProcessNext
		dec Level.ObjectCounters,x
		beq ProcessObject
	ProcessNext:
		inx
		bne ProcessObjects

	ObjectsDone:
		lda Level.DefragNeeded
		beq Done
		ldx #0
	DefragStart:
		lda Level.ObjectTypes,x
		bmi FoundFirstDead
		inx
		bne DefragStart
	FoundFirstDead:
		txa
		tay
	Defrag:
		lda Level.ObjectTypes,y
		bpl Copy
		bne DefragNext
	Copy:
		lda	Level.ObjectTypes,y
		sta	Level.ObjectTypes,x
		beq Done
		lda	Level.ObjectCounters,y
		sta	Level.ObjectCounters,x
		lda	Level.ObjectStates,y
		sta	Level.ObjectStates,x
		lda	Level.ObjectXs,y
		sta	Level.ObjectXs,x
		sta PX
		lda	Level.ObjectYs,y
		sta	Level.ObjectYs,x
		sty I
		tay
		lda RowAddressesLow,y
		sta IndexPtr
		lda ObjectIndexRowAddressesHigh,y
		sta IndexPtr + 1
		ldy PX
		txa
		sta (IndexPtr),y
		ldy I
		inx
	DefragNext:
		iny
		bne Defrag
	Done:
		stx Level.ObjectCount
		rts

	ProcessObject:
		stx Level.ObjectIndex
		ldy Level.ObjectTypes,x
		lda ActivePieceTimings - Piece.Active,y
		sta Level.ObjectCounters,x
		lda UpdateAddressesLow - Piece.Active,y
		sta UpdateJump + 1
		lda UpdateAddressesHigh - Piece.Active,y
		sta UpdateJump + 2
	UpdateJump:
		jmp NextObject
	@NextObject:
		ldx Level.ObjectIndex
		jmp ProcessNext
}

// Increment horizontal sticker field around (X,Y).
AddHorizontalStickerField: {
		sec
		lda RowAddressesLow,y
		sbc #2
		sta Loop + 1
		lda StickerFieldRowAddressesHigh,y
		sbc #0
		sta Loop + 2
		txa
		clc
		adc #5
		sta I
	Loop:
		inc Level.StickerField,x
		inx
		cpx I
		bne Loop
		rts
}

// Decrement horizontal sticker field around (X,Y).
RemoveHorizontalStickerField: {
		sec
		lda RowAddressesLow,y
		sbc #2
		sta Loop + 1
		lda StickerFieldRowAddressesHigh,y
		sbc #0
		sta Loop + 2
		txa
		clc
		adc #5
		sta I
	Loop:
		dec Level.StickerField,x
		inx
		cpx I
		bne Loop
		rts
}

// Increment vertical sticker field around (X,Y).
AddVerticalStickerField: {
		stx I
		sec
		lda #(Screen.Width * 2)
		sbc I
		sta I
		sec
		lda RowAddressesLow,y
		sbc I
		sta Loop + 1
		lda StickerFieldRowAddressesHigh,y
		sbc #0
		sta Loop + 2
		ldx #0
	Loop:
		inc Level.StickerField,x
		txa
		clc
		adc #Screen.Width
		tax
		cpx #(Screen.Width * 5)
		bne Loop
		rts
}

// Decrement vertical sticker field around (X,Y).
RemoveVerticalStickerField: {
		stx I
		sec
		lda #(Screen.Width * 2)
		sbc I
		sta I
		sec
		lda RowAddressesLow,y
		sbc I
		sta Loop + 1
		lda StickerFieldRowAddressesHigh,y
		sbc #0
		sta Loop + 2
		ldx #0
	Loop:
		dec Level.StickerField,x
		txa
		clc
		adc #Screen.Width
		tax
		cpx #(Screen.Width * 5)
		bne Loop
		rts
}

// Find object at (A,Y), and return its index in X. Sets Z flag if there's no active object on the tile.
FindObjectByPosition: {
		sta I
		lda RowAddressesLow,y
		sta IndexPtr
		lda ObjectIndexRowAddressesHigh,y
		sta IndexPtr + 1
		ldy I
		lda (IndexPtr),y
		tax
		cpx #Level.FreeObjectIndex
		rts
}

// Create a new object of type A and place it at (X,Y). Doesn't handle stickers correctly.
AddNewObject: {
		stx I
		ldx Level.ObjectCount
		inc Level.ObjectCount
		bne Add
		dec Level.ObjectCount
		rts

	Add:
		sta Level.ObjectTypes,x
		sta J
		lda #0
		sta Level.ObjectTypes + 1,x
		tya
		sta Level.ObjectYs,x
		lda I
		sta Level.ObjectXs,x
		sty I
		ldy J
		lda ActivePieceTimings - Piece.Active,y
		clc
		adc #1
		sta Level.ObjectCounters,x

		ldy I
		lda RowAddressesLow,y
		sta ScreenPtr
		sta ColorPtr
		sta IndexPtr
		lda RowAddressesHigh,y
		sta ScreenPtr + 1
		eor #>(Screen.Address ^ Level.ObjectIndices)
		sta IndexPtr + 1
		eor #>(VIC.ColorRam ^ Level.ObjectIndices)
		sta ColorPtr + 1
		lda Level.ObjectTypes,x
		ldy Level.ObjectXs,x
		sta (ScreenPtr),y
		sta I
		txa
		sta (IndexPtr),y
		ldx I
		lda CharColors,x
		sta (ColorPtr),y

		rts
}

// Set C if the tile at (A,Y) can be pushed by the bouncers. Preserves A and Y.
CheckIfTileBounceable: {
		sta I
		sty J
		SetScreenPtrRowY()
		ldy I
		lda (ScreenPtr),y
		tay
		lda PieceFlags,y
		asl
		asl
		lda I
		ldy J
		rts
}

// Change the type of object X to A and reflect it on the screen too. Colour is not adjusted.
UpdateObjectType: {
		sta Level.ObjectTypes,x
		ldy Level.ObjectYs,x
		SetScreenPtrRowY()
		ldy Level.ObjectXs,x
		lda Level.ObjectTypes,x
		sta (ScreenPtr),y
		rts
}

// Clear the tile at (A,Y) and the mark the underlying object as dead if there is one.
ClearTile: {
		sta I
		lda RowAddressesLow,y
		sta ScreenPtr
		sta IndexPtr
		lda RowAddressesHigh,y
		sta ScreenPtr + 1
		eor #>(Screen.Address ^ Level.ObjectIndices)
		sta IndexPtr + 1
		ldy I
		lda #Piece.Empty
		sta (ScreenPtr),y
		lda (IndexPtr),y
		cmp #Level.FreeObjectIndex
		beq Done
		tax
		lda #Level.FreeObjectIndex
		sta (IndexPtr),y
		ldy Level.ObjectTypes,x
		lda #Piece.Dead
		sta Level.ObjectTypes,x
		sta Level.DefragNeeded
		cpy #Piece.StickerLR
		bne !+
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		tax
		jsr RemoveHorizontalStickerField
	!:	cpy #Piece.StickerTB
		bne Done
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		tax
		jsr RemoveVerticalStickerField
	Done:
		rts
}

// Refresh the colour of the tile at (A,Y) with the correct value.
RefreshTileColor: {
		sta I
		lda RowAddressesLow,y
		sta ScreenPtr
		sta ColorPtr
		lda RowAddressesHigh,y
		sta ScreenPtr + 1
		eor #>(Screen.Address ^ VIC.ColorRam)
		sta ColorPtr + 1
		ldy I
		lda (ScreenPtr),y
		tax
		lda CharColors,x
		sta (ColorPtr),y
		rts
}

// Move tile at (A,Y) upwards, including the underlying object if there is one.
MoveTileUp: {
		sty UY
		sta I
		lsr
		sta UX
		sec
		lda #Screen.Width
		sbc I
		sta I
		sec
		lda RowAddressesLow,y
		sbc I
		sta ScreenPtr
		sta IndexPtr
		sta ColorPtr
		lda RowAddressesHigh,y
		sbc #0
		sta ScreenPtr + 1
		eor #>(Screen.Address ^ Level.ObjectIndices)
		sta IndexPtr + 1
		eor #>(VIC.ColorRam ^ Level.ObjectIndices)
		sta ColorPtr + 1

	UpdateScreen:
		ldy #Screen.Width
		lda (ScreenPtr),y
		sta I
		lda Level.RevealedTile
		sta (ScreenPtr),y
		lda (ColorPtr),y
		sta J
		lda #Colors.Door
		sta (ColorPtr),y
		lda J
		ldy #0
		sta (ColorPtr),y
		lda I
		sta (ScreenPtr),y

	UpdateUnderlay:
		ldx UX
		ldy UY
		jsr RefreshUnderlayTilePair
		dec UY
		ldx UX
		ldy UY
		jsr RefreshUnderlayTilePair

	UpdateObject:
		ldy #Screen.Width
		lda (IndexPtr),y
		cmp #Level.FreeObjectIndex
		bne MoveObject
		rts

	MoveObject:
		tax
		dec Level.ObjectYs,x
		lda #Level.FreeObjectIndex
		sta (IndexPtr),y		
		ldy #0
		txa
		sta (IndexPtr),y

		lda Level.ObjectTypes,x
		cmp #Piece.StickerLR
		bne !+
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		tax
		stx J
		sty K
		iny
		jsr RemoveHorizontalStickerField
		ldx J
		ldy K
		jsr AddHorizontalStickerField
		rts
	!:	cmp #Piece.StickerTB
		bne Done
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		tax
		stx J
		sty K
		iny
		jsr RemoveVerticalStickerField
		ldx J
		ldy K
		jsr AddVerticalStickerField
		bne Done
	Done:
		rts
}

// Push tile at (A,Y) upwards if possible, and handle its consumption by a black hole.
// Set carry if the push succeeded. If the push failed, A contains the type of the blocker.
PushTileUp: {
		sta PX
		sty PY

		dey
		SetScreenPtrRowY()

		ldy PX
		lda (ScreenPtr),y
		beq Push
		cmp #Piece.Blackhole
		bcc Stay
		cmp #Piece.Blackhole + 4
		bcs Stay

	Consume:
		lda PX
		ldy PY
		jsr ClearTile
		lda PX
		ldy PY
		dey
		jsr FindObjectByPosition
		lda #Piece.BlackholeFull
		jsr UpdateObjectType
		lda PX
		ldy PY
		dey
		jsr RefreshTileColor
		lsr PX
		ldx PX
		ldy PY
		jsr RefreshUnderlayTilePair
		sec
		rts

	Push:
		lda PX
		ldy PY
		jsr MoveTileUp
		sec
		rts

	Stay:
		clc
		rts
}

// Move tile at (A,Y) downwards, including the underlying object if there is one.
MoveTileDown: {
		sty UY
		sta I
		lsr
		sta UX
		clc
		lda RowAddressesLow,y
		adc I
		sta ScreenPtr
		sta IndexPtr
		sta ColorPtr
		lda RowAddressesHigh,y
		adc #0
		sta ScreenPtr + 1
		eor #>(Screen.Address ^ Level.ObjectIndices)
		sta IndexPtr + 1
		eor #>(VIC.ColorRam ^ Level.ObjectIndices)
		sta ColorPtr + 1

	UpdateScreen:
		ldy #0
		lda (ScreenPtr),y
		sta I
		lda Level.RevealedTile
		sta (ScreenPtr),y
		lda (ColorPtr),y
		sta J
		lda #Colors.Door
		sta (ColorPtr),y
		lda J
		ldy #Screen.Width
		sta (ColorPtr),y
		lda I
		sta (ScreenPtr),y

	UpdateUnderlay:
		ldx UX
		ldy UY
		jsr RefreshUnderlayTilePair
		inc UY
		ldx UX
		ldy UY
		jsr RefreshUnderlayTilePair

	UpdateObject:
		ldy #0
		lda (IndexPtr),y
		cmp #Level.FreeObjectIndex
		bne MoveObject
		rts

	MoveObject:
		tax
		inc Level.ObjectYs,x
		lda #Level.FreeObjectIndex
		sta (IndexPtr),y		
		ldy #Screen.Width
		txa
		sta (IndexPtr),y

		lda Level.ObjectTypes,x
		cmp #Piece.StickerLR
		bne !+
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		tax
		stx J
		sty K
		dey
		jsr RemoveHorizontalStickerField
		ldx J
		ldy K
		jsr AddHorizontalStickerField
		rts
	!:	cmp #Piece.StickerTB
		bne Done
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		tax
		stx J
		sty K
		dey
		jsr RemoveVerticalStickerField
		ldx J
		ldy K
		jsr AddVerticalStickerField
		bne Done
	Done:
		rts
}

// Push tile at (A,Y) downwards if possible, and handle its consumption by a black hole.
// Set carry if the push succeeded. If the push failed, A contains the type of the blocker.
PushTileDown: {
		sta PX
		sty PY

		iny
		SetScreenPtrRowY()

		ldy PX
		lda (ScreenPtr),y
		beq Push
		cmp #Piece.Blackhole
		bcc Stay
		cmp #Piece.Blackhole + 4
		bcs Stay

	Consume:
		lda PX
		ldy PY
		jsr ClearTile
		lda PX
		ldy PY
		iny
		jsr FindObjectByPosition
		lda #Piece.BlackholeFull
		jsr UpdateObjectType
		lda PX
		ldy PY
		iny
		jsr RefreshTileColor
		lsr PX
		ldx PX
		ldy PY
		jsr RefreshUnderlayTilePair
		sec
		rts

	Push:
		lda PX
		ldy PY
		jsr MoveTileDown
		sec
		rts

	Stay:
		clc
		rts
}

// Move tile at (A,Y) leftwards, including the underlying object if there is one.
MoveTileLeft: {
		sty UY
		sta I
		sta UX
		dec I
		clc
		lda RowAddressesLow,y
		adc I
		sta ScreenPtr
		sta IndexPtr
		sta ColorPtr
		lda RowAddressesHigh,y
		adc #0
		sta ScreenPtr + 1
		eor #>(Screen.Address ^ Level.ObjectIndices)
		sta IndexPtr + 1
		eor #>(VIC.ColorRam ^ Level.ObjectIndices)
		sta ColorPtr + 1

	UpdateScreen:
		ldy #1
		lda (ScreenPtr),y
		sta I
		lda Level.RevealedTile
		sta (ScreenPtr),y
		lda (ColorPtr),y
		sta J
		lda #Colors.Door
		sta (ColorPtr),y
		lda J
		ldy #0
		sta (ColorPtr),y
		lda I
		sta (ScreenPtr),y

	UpdateUnderlay:
		lda UX
		lsr UX
		and #1
		beq UpdateTwoPairs
		ldx UX
		ldy UY
		jsr RefreshUnderlayTilePair
		jmp UpdateObject
	UpdateTwoPairs:
		ldx UX
		ldy UY
		jsr RefreshUnderlayTilePair
		dec UX
		ldx UX
		ldy UY
		jsr RefreshUnderlayTilePair

	UpdateObject:
		ldy #1
		lda (IndexPtr),y
		cmp #Level.FreeObjectIndex
		bne MoveObject
		rts

	MoveObject:
		tax
		dec Level.ObjectXs,x
		lda #Level.FreeObjectIndex
		sta (IndexPtr),y		
		ldy #0
		txa
		sta (IndexPtr),y

		lda Level.ObjectTypes,x
		cmp #Piece.StickerLR
		bne !+
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		tax
		stx J
		sty K
		inx
		jsr RemoveHorizontalStickerField
		ldx J
		ldy K
		jsr AddHorizontalStickerField
		rts
	!:	cmp #Piece.StickerTB
		bne Done
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		tax
		stx J
		sty K
		inx
		jsr RemoveVerticalStickerField
		ldx J
		ldy K
		jsr AddVerticalStickerField
		bne Done
	Done:
		rts
}

// Push tile at (A,Y) leftwards if possible, and handle its consumption by a black hole.
// Set carry if the push succeeded. If the push failed, A contains the type of the blocker.
PushTileLeft: {
		sta PX
		sty PY

		SetScreenPtrRowY()

		ldy PX
		dey
		lda (ScreenPtr),y
		beq Push
		cmp #Piece.Blackhole
		bcc Stay
		cmp #Piece.Blackhole + 4
		bcs Stay

	Consume:
		lda PX
		ldy PY
		jsr ClearTile
		lda PX
		ldy PY
		sec
		sbc #1
		jsr FindObjectByPosition
		lda #Piece.BlackholeFull
		jsr UpdateObjectType
		lda PX
		ldy PY
		sec
		sbc #1
		jsr RefreshTileColor
		lsr PX
		ldx PX
		ldy PY
		jsr RefreshUnderlayTilePair
		sec
		rts

	Push:
		lda PX
		ldy PY
		jsr MoveTileLeft
		sec
		rts

	Stay:
		clc
		rts
}

// Move tile at (A,Y) rightwards, including the underlying object if there is one.
MoveTileRight: {
		sty UY
		sta I
		sta UX
		clc
		lda RowAddressesLow,y
		adc I
		sta ScreenPtr
		sta IndexPtr
		sta ColorPtr
		lda RowAddressesHigh,y
		adc #0
		sta ScreenPtr + 1
		eor #>(Screen.Address ^ Level.ObjectIndices)
		sta IndexPtr + 1
		eor #>(VIC.ColorRam ^ Level.ObjectIndices)
		sta ColorPtr + 1

	UpdateScreen:
		ldy #0
		lda (ScreenPtr),y
		sta I
		lda Level.RevealedTile
		sta (ScreenPtr),y
		lda (ColorPtr),y
		sta J
		lda #Colors.Door
		sta (ColorPtr),y
		lda J
		ldy #1
		sta (ColorPtr),y
		lda I
		sta (ScreenPtr),y

	UpdateUnderlay:
		lda UX
		lsr UX
		and #1
		bne UpdateTwoPairs
		ldx UX
		ldy UY
		jsr RefreshUnderlayTilePair
		jmp UpdateObject
	UpdateTwoPairs:
		ldx UX
		ldy UY
		jsr RefreshUnderlayTilePair
		inc UX
		ldx UX
		ldy UY
		jsr RefreshUnderlayTilePair

	UpdateObject:
		ldy #0
		lda (IndexPtr),y
		cmp #Level.FreeObjectIndex
		bne MoveObject
		rts

	MoveObject:
		tax
		inc Level.ObjectXs,x
		lda #Level.FreeObjectIndex
		sta (IndexPtr),y		
		ldy #1
		txa
		sta (IndexPtr),y

		lda Level.ObjectTypes,x
		cmp #Piece.StickerLR
		bne !+
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		tax
		stx J
		sty K
		dex
		jsr RemoveHorizontalStickerField
		ldx J
		ldy K
		jsr AddHorizontalStickerField
		rts
	!:	cmp #Piece.StickerTB
		bne Done
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		tax
		stx J
		sty K
		dex
		jsr RemoveVerticalStickerField
		ldx J
		ldy K
		jsr AddVerticalStickerField
		bne Done
	Done:
		rts
}

// Push tile at (A,Y) rightwards if possible, and handle its consumption by a black hole.
// Set carry if the push succeeded. If the push failed, A contains the type of the blocker.
PushTileRight: {
		sta PX
		sty PY

		SetScreenPtrRowY()

		ldy PX
		iny
		lda (ScreenPtr),y
		beq Push
		cmp #Piece.Blackhole
		bcc Stay
		cmp #Piece.Blackhole + 4
		bcs Stay

	Consume:
		lda PX
		ldy PY
		jsr ClearTile
		lda PX
		ldy PY
		clc
		adc #1
		jsr FindObjectByPosition
		lda #Piece.BlackholeFull
		jsr UpdateObjectType
		lda PX
		ldy PY
		clc
		adc #1
		jsr RefreshTileColor
		lsr PX
		ldx PX
		ldy PY
		jsr RefreshUnderlayTilePair
		sec
		rts

	Push:
		lda PX
		ldy PY
		jsr MoveTileRight
		sec
		rts

	Stay:
		clc
		rts
}

// Check stickers acting on object X, and set the carry on return if it's stuck to one.
CheckNearbyStickers: {
		ldy Level.ObjectYs,x
		lda RowAddressesLow,y
		sta StickerFieldPtr
		lda StickerFieldRowAddressesHigh,y
		sta StickerFieldPtr + 1
		ldy Level.ObjectXs,x
		lda (StickerFieldPtr),y
		bne StickerNearby
		clc
		rts

	StickerNearby:
		ldy Level.ObjectYs,x
		sec
		lda RowAddressesLow,y
		sbc #Level.StickerOrigin
		sta ScreenPtr
		lda RowAddressesHigh,y
		sbc #0
		sta ScreenPtr + 1
		clc
		lda ScreenPtr
		adc Level.ObjectXs,x
		sta ScreenPtr
		lda ScreenPtr + 1
		adc #0
		sta ScreenPtr + 1

	CheckMoveDown:
		ldy #(Level.StickerOrigin + Screen.Width)
		lda (ScreenPtr),y
		bne CheckMoveUp
		ldy #(Level.StickerOrigin + Screen.Width * 2)
		lda (ScreenPtr),y
		cmp #Piece.StickerTB
		bne CheckMoveUp
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		jsr MoveTileDown
		sec
		rts

	CheckMoveUp:
		ldy #(Level.StickerOrigin - Screen.Width)
		lda (ScreenPtr),y
		bne CheckMoveRight
		ldy #(Level.StickerOrigin - Screen.Width * 2)
		lda (ScreenPtr),y
		cmp #Piece.StickerTB
		bne CheckMoveRight
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		jsr MoveTileUp
		sec
		rts

	CheckMoveRight:
		ldy #(Level.StickerOrigin + 1)
		lda (ScreenPtr),y
		bne CheckMoveLeft
		iny
		lda (ScreenPtr),y
		cmp #Piece.StickerLR
		bne CheckMoveLeft
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		jsr MoveTileRight
		sec
		rts

	CheckMoveLeft:
		ldy #(Level.StickerOrigin - 1)
		lda (ScreenPtr),y
		bne CheckDown
		dey
		lda (ScreenPtr),y
		cmp #Piece.StickerLR
		bne CheckDown
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		jsr MoveTileLeft
		sec
		rts

	CheckDown:
		ldy #(Level.StickerOrigin + Screen.Width)
		lda (ScreenPtr),y
		cmp #Piece.StickerTB
		beq Stuck

	CheckUp:
		ldy #(Level.StickerOrigin - Screen.Width)
		lda (ScreenPtr),y
		cmp #Piece.StickerTB
		beq Stuck

	CheckRight:
		ldy #(Level.StickerOrigin + 1)
		lda (ScreenPtr),y
		cmp #Piece.StickerLR
		beq Stuck

	CheckLeft:
		ldy #(Level.StickerOrigin - 1)
		lda (ScreenPtr),y
		cmp #Piece.StickerLR
		beq Stuck

	Free:
		clc
		rts

	Stuck:
		sec
		rts
}

UpdateSliderUp: {
		jsr CheckNearbyStickers
		bcs Done
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		jsr PushTileUp
		bcc UpdateSliderCommon
	Done:
		jmp NextObject
}

UpdateSliderDown: {
		jsr CheckNearbyStickers
		bcs Done
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		jsr PushTileDown
		bcc UpdateSliderCommon
	Done:
		jmp NextObject
}

UpdateSliderLeft: {
		jsr CheckNearbyStickers
		bcs Done
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		jsr PushTileLeft
		bcc UpdateSliderCommon
	Done:
		jmp NextObject
}

UpdateSliderRight: {
		jsr CheckNearbyStickers
		bcs Done
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		jsr PushTileRight
		bcc UpdateSliderCommon
	Done:
		jmp NextObject
}

UpdateSliderCommon: {
		ldx Level.ObjectIndex
		cmp #Piece.Clocker
		bne !+
		ldy Level.ObjectTypes,x
		lda PiecesRotatedAntiClockwise - Piece.Active,y
		jsr UpdateObjectType
		jmp NextObject
	!:	cmp #Piece.AntiClocker
		bne Done
		ldy Level.ObjectTypes,x
		lda PiecesRotatedClockwise - Piece.Active,y
		jsr UpdateObjectType
	Done:
		jmp NextObject	
}

UpdateRockyUp: {
		jsr CheckNearbyStickers
		bcs Done
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		jsr PushTileUp
		bcs Done
		jsr UpdateRockyCommon
		bne Roll

	Done:
		jmp NextObject

	Roll:
		tay
		lda PieceFlags,y
		and #%1100
		beq Done

		sta RollDirs
		ldx Level.ObjectIndex
		lda #(Screen.Width + 1)
		sec
		sbc Level.ObjectXs,x
		sta I
		ldy Level.ObjectYs,x
		sec
		lda RowAddressesLow,y
		sbc I
		sta ScreenPtr
		lda RowAddressesHigh,y
		sbc #0
		sta ScreenPtr + 1

	CheckLeft:
		ldy #Screen.Width
		lda (ScreenPtr),y
		bne LeftBlocked
		ldy #0
		lda (ScreenPtr),y
		beq CheckRight
	LeftBlocked:
		lda RollDirs
		and #%1000
		beq Done
		sta RollDirs
	CheckRight:
		ldy #(Screen.Width + 2)
		lda (ScreenPtr),y
		bne RightBlocked
		ldy #2
		lda (ScreenPtr),y
		beq PickRoll
	RightBlocked:
		lda RollDirs
		and #%0100
		beq Done
		sta RollDirs

	PickRoll:
		lda RollDirs
		cmp #%0100
		beq RollLeft
		cmp #%1000
		beq RollRight
		inc Level.RockySide
		lda Level.RockySide
		ror
		bcc RollLeft
		bcs RollRight

	RollLeft:
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		sta RX
		sty RY
		jsr MoveTileLeft
		dec RX
		lda RX
		ldy RY
		jsr MoveTileUp
		jmp NextObject

	RollRight:
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		sta RX
		sty RY
		jsr MoveTileRight
		inc RX
		lda RX
		ldy RY
		jsr MoveTileUp
		jmp NextObject
}

UpdateRockyDown: {
		jsr CheckNearbyStickers
		bcs Done
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		jsr PushTileDown
		bcs Done
		jsr UpdateRockyCommon
		bne Roll

	Done:
		jmp NextObject

	Roll:
		tay
		lda PieceFlags,y
		and #%0011
		beq Done

		sta RollDirs
		ldx Level.ObjectIndex
		lda #(Screen.Width + 1)
		sec
		sbc Level.ObjectXs,x
		sta I
		ldy Level.ObjectYs,x
		sec
		lda RowAddressesLow,y
		sbc I
		sta ScreenPtr
		lda RowAddressesHigh,y
		sbc #0
		sta ScreenPtr + 1

	CheckLeft:
		ldy #Screen.Width
		lda (ScreenPtr),y
		bne LeftBlocked
		ldy #(Screen.Width * 2)
		lda (ScreenPtr),y
		beq CheckRight
	LeftBlocked:
		lda RollDirs
		and #%0010
		beq Done
		sta RollDirs
	CheckRight:
		ldy #(Screen.Width + 2)
		lda (ScreenPtr),y
		bne RightBlocked
		ldy #(Screen.Width * 2 + 2)
		lda (ScreenPtr),y
		beq PickRoll
	RightBlocked:
		lda RollDirs
		and #%0001
		beq Done
		sta RollDirs

	PickRoll:
		lda RollDirs
		cmp #%0001
		beq RollLeft
		cmp #%0010
		beq RollRight
		inc Level.RockySide
		lda Level.RockySide
		ror
		bcc RollLeft
		bcs RollRight

	RollLeft:
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		sta RX
		sty RY
		jsr MoveTileLeft
		dec RX
		lda RX
		ldy RY
		jsr MoveTileDown
		jmp NextObject

	RollRight:
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		sta RX
		sty RY
		jsr MoveTileRight
		inc RX
		lda RX
		ldy RY
		jsr MoveTileDown
		jmp NextObject
}

UpdateRockyLeft: {
		jsr CheckNearbyStickers
		bcs Done
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		jsr PushTileLeft
		bcs Done
		jsr UpdateRockyCommon
		bne Roll

	Done:
		jmp NextObject

	Roll:
		tay
		lda PieceFlags,y
		and #%1010
		beq Done

		sta RollDirs
		ldx Level.ObjectIndex
		lda #(Screen.Width + 1)
		sec
		sbc Level.ObjectXs,x
		sta I
		ldy Level.ObjectYs,x
		sec
		lda RowAddressesLow,y
		sbc I
		sta ScreenPtr
		lda RowAddressesHigh,y
		sbc #0
		sta ScreenPtr + 1

	CheckUp:
		ldy #1
		lda (ScreenPtr),y
		bne UpBlocked
		ldy #0
		lda (ScreenPtr),y
		beq CheckDown
	UpBlocked:
		lda RollDirs
		and #%1000
		beq Done
		sta RollDirs
	CheckDown:
		ldy #(Screen.Width * 2 + 1)
		lda (ScreenPtr),y
		bne DownBlocked
		ldy #(Screen.Width * 2)
		lda (ScreenPtr),y
		beq PickRoll
	DownBlocked:
		lda RollDirs
		and #%0010
		beq Done
		sta RollDirs

	PickRoll:
		lda RollDirs
		cmp #%0010
		beq RollUp
		cmp #%1000
		beq RollDown
		inc Level.RockySide
		lda Level.RockySide
		ror
		bcc RollUp
		bcs RollDown

	RollUp:
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		sta RX
		sty RY
		jsr MoveTileUp
		lda RX
		ldy RY
		dey
		jsr MoveTileLeft
		jmp NextObject

	RollDown:
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		sta RX
		sty RY
		jsr MoveTileDown
		lda RX
		ldy RY
		iny
		jsr MoveTileLeft
		jmp NextObject
}

UpdateRockyRight: {
		jsr CheckNearbyStickers
		bcs Done
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		jsr PushTileRight
		bcs Done
		jsr UpdateRockyCommon
		bne Roll

	Done:
		jmp NextObject

	Roll:
		tay
		lda PieceFlags,y
		and #%0101
		beq Done

		sta RollDirs
		ldx Level.ObjectIndex
		lda #(Screen.Width + 1)
		sec
		sbc Level.ObjectXs,x
		sta I
		ldy Level.ObjectYs,x
		sec
		lda RowAddressesLow,y
		sbc I
		sta ScreenPtr
		lda RowAddressesHigh,y
		sbc #0
		sta ScreenPtr + 1

	CheckUp:
		ldy #1
		lda (ScreenPtr),y
		bne UpBlocked
		ldy #2
		lda (ScreenPtr),y
		beq CheckDown
	UpBlocked:
		lda RollDirs
		and #%0100
		beq Done
		sta RollDirs
	CheckDown:
		ldy #(Screen.Width * 2 + 1)
		lda (ScreenPtr),y
		bne DownBlocked
		ldy #(Screen.Width * 2 + 2)
		lda (ScreenPtr),y
		beq PickRoll
	DownBlocked:
		lda RollDirs
		and #%0001
		beq Done
		sta RollDirs

	PickRoll:
		lda RollDirs
		cmp #%0001
		beq RollUp
		cmp #%0100
		beq RollDown
		inc Level.RockySide
		lda Level.RockySide
		ror
		bcc RollUp
		bcs RollDown

	RollUp:
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		sta RX
		sty RY
		jsr MoveTileUp
		lda RX
		ldy RY
		dey
		jsr MoveTileRight
		jmp NextObject

	RollDown:
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		sta RX
		sty RY
		jsr MoveTileDown
		lda RX
		ldy RY
		iny
		jsr MoveTileRight
		jmp NextObject
}

UpdateRockyCommon: {
		ldx Level.ObjectIndex
		cmp #Piece.Clocker
		bne !+
		ldy Level.ObjectTypes,x
		lda PiecesRotatedAntiClockwise - Piece.Active,y
		jsr UpdateObjectType
		lda #0
		rts
	!:	cmp #Piece.AntiClocker
		bne Done
		ldy Level.ObjectTypes,x
		lda PiecesRotatedClockwise - Piece.Active,y
		jsr UpdateObjectType
		lda #0
	Done:
		rts
}

UpdateBouncerUp: {
		jsr CheckNearbyStickers
		bcs Done
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		jsr PushTileUp
		bcc Bounce
		jmp NextObject
	Bounce:
		ldx Level.ObjectIndex
		lda #Piece.BouncerDown
		jsr UpdateObjectType
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		lsr
		tax
		jsr RefreshUnderlayTilePair
		ldx Level.ObjectIndex
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		dey
		jsr CheckIfTileBounceable
		bcc Done
		jsr PushTileUp
	Done:
		jmp NextObject
}

UpdateBouncerDown: {
		jsr CheckNearbyStickers
		bcs Done
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		jsr PushTileDown
		bcc Bounce
		jmp NextObject
	Bounce:
		ldx Level.ObjectIndex
		lda #Piece.BouncerUp
		jsr UpdateObjectType
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		lsr
		tax
		jsr RefreshUnderlayTilePair
		ldx Level.ObjectIndex
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		iny
		jsr CheckIfTileBounceable
		bcc Done
		jsr PushTileDown
	Done:
		jmp NextObject
}

UpdateBouncerLeft: {
		jsr CheckNearbyStickers
		bcs Done
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		jsr PushTileLeft
		bcc Bounce
		jmp NextObject
	Bounce:
		ldx Level.ObjectIndex
		lda #Piece.BouncerRight
		jsr UpdateObjectType
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		lsr
		tax
		jsr RefreshUnderlayTilePair
		ldx Level.ObjectIndex
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		sec
		sbc #1
		jsr CheckIfTileBounceable
		bcc Done
		jsr PushTileLeft
	Done:
		jmp NextObject
}

UpdateBouncerRight: {
		jsr CheckNearbyStickers
		bcs Done
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		jsr PushTileRight
		bcc Bounce
		jmp NextObject
	Bounce:
		ldx Level.ObjectIndex
		lda #Piece.BouncerLeft
		jsr UpdateObjectType
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		lsr
		tax
		jsr RefreshUnderlayTilePair
		ldx Level.ObjectIndex
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		clc
		adc #1
		jsr CheckIfTileBounceable
		bcc Done
		jsr PushTileRight
	Done:
		jmp NextObject
}

UpdateEmptyBlackhole: {
		iny
		cpy #Piece.Blackhole + 4
		bcc !+
		ldy #Piece.Blackhole
	!:	tya
		jsr UpdateObjectType
		jmp NextObject
}

UpdateFullBlackhole: {
		iny
		cpy #Piece.BlackholeFull + 4
		bcc !+
		ldy #Piece.Blackhole
	!:	tya
		jsr UpdateObjectType
		SetCurrentColorPtr(ScreenPtr)
		ldy Level.ObjectTypes,x
		lda CharColors,y
		ldy Level.ObjectXs,x
		sta (ColorPtr),y
		jmp NextObject
}

UpdateTimer: {
		iny
		cpy #Piece.Timer0 + 1
		bcc !+
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		jsr ClearTile
		ldx Level.ObjectIndex
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		lsr
		tax
		jsr RefreshUnderlayTilePair
		jmp NextObject
	!:	tya
		jsr UpdateObjectType
		jmp NextObject
}

UpdateMonster: {
		tya
		eor #1
		jsr UpdateObjectType
		jsr CheckNearbyStickers
		bcs Stay
		jsr NextRandom
		bmi Wander

	Chase:
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		cpy Player.Y
		beq ChaseHorizontally

	ChaseVertically:
		bcc !+
		jsr PushTileUp
		ldx Level.ObjectIndex
		lda Level.ObjectXs,x
		bcc ChaseHorizontally
		jmp NextObject
	!:	jsr PushTileDown
		ldx Level.ObjectIndex
		lda Level.ObjectXs,x
		bcc ChaseHorizontally
		jmp NextObject

	ChaseHorizontally:	
		ldy Level.ObjectXs,x
		cpy Player.X
		ldy Level.ObjectYs,x
		bcc !+
		jsr PushTileLeft
		jmp NextObject
	!:	jsr PushTileRight
		jmp NextObject

	Wander:
		asl
		sta I
		and #$07
		beq Stay
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		bit I
		bmi WanderHorizontally

	WanderVertically:
		bvc !+
		jsr PushTileUp
		jmp NextObject
	!:	jsr PushTileDown
	Stay:
		jmp NextObject

	WanderHorizontally:
		bvc !+
		jsr PushTileLeft
		jmp NextObject
	!:	jsr PushTileRight
		jmp NextObject
}

UpdateStickerLR: {
		ldy Level.ObjectYs,x
		SetScreenPtrRowY()

	CheckLeft:
		ldy Level.ObjectXs,x
		dey
		lda (ScreenPtr),y
		bne CheckRight
		dey
		lda (ScreenPtr),y
		cmp #Piece.StickerLR
		beq CheckRight
		cmp #Piece.Kye
		bne PullFromLeft
	PullToPlayerLeft:
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		sta PX
		inc PX
		sty PY
		jsr MoveTileLeft
		ldy PY
		SetScreenPtrRowY()
		ldy PX
		lda (ScreenPtr),y
		cmp #Piece.StickerLR
		beq !+
		tay
		lda PieceFlags,y
		bpl !+
		lda PX
		ldy PY
		jsr MoveTileLeft
	!:	jmp NextObject		
	PullFromLeft:
		tay
		lda PieceFlags,y
		bpl CheckRight
		movw ScreenPtr : ScreenPtrBackup
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		sec
		sbc #2
		jsr MoveTileRight
		ldx Level.ObjectIndex
		movw ScreenPtrBackup : ScreenPtr

	CheckRight:
		ldy Level.ObjectXs,x
		iny
		lda (ScreenPtr),y
		bne Done
		iny
		lda (ScreenPtr),y
		cmp #Piece.StickerLR
		beq Done
		cmp #Piece.Kye
		bne PullFromRight
	PullToPlayerRight:
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		sta PX
		dec PX
		sty PY
		jsr MoveTileRight
		ldy PY
		SetScreenPtrRowY()
		ldy PX
		lda (ScreenPtr),y
		cmp #Piece.StickerLR
		beq !+
		tay
		lda PieceFlags,y
		bpl !+
		lda PX
		ldy PY
		jsr MoveTileRight
	!:	jmp NextObject		
	PullFromRight:
		tay
		lda PieceFlags,y
		bpl Done
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		clc
		adc #2
		jsr MoveTileLeft

	Done:
		jmp NextObject	
}

UpdateStickerTB: {
		lda #(Screen.Width * 2)
		sec
		sbc Level.ObjectXs,x
		sta I
		ldy Level.ObjectYs,x
		sec
		lda RowAddressesLow,y
		sbc I
		sta ScreenPtr
		lda RowAddressesHigh,y
		sbc #0
		sta ScreenPtr + 1

	CheckUp:
		ldy #Screen.Width
		lda (ScreenPtr),y
		bne CheckDown
		ldy #0
		lda (ScreenPtr),y
		cmp #Piece.StickerTB
		beq CheckDown
		cmp #Piece.Kye
		bne PullFromUp
	PullToPlayerUp:
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		sta PX
		sty PY
		inc PY
		jsr MoveTileUp
		ldy PY
		SetScreenPtrRowY()
		ldy PX
		lda (ScreenPtr),y
		cmp #Piece.StickerTB
		beq !+
		tay
		lda PieceFlags,y
		bpl !+
		lda PX
		ldy PY
		jsr MoveTileUp
	!:	jmp NextObject		
	PullFromUp:
		tay
		lda PieceFlags,y
		bpl CheckDown
		movw ScreenPtr : ScreenPtrBackup
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		dey
		dey
		jsr MoveTileDown
		ldx Level.ObjectIndex
		movw ScreenPtrBackup : ScreenPtr

	CheckDown:
		ldy #(Screen.Width * 3)
		lda (ScreenPtr),y
		bne Done
		ldy #(Screen.Width * 4)
		lda (ScreenPtr),y
		cmp #Piece.StickerTB
		beq Done
		cmp #Piece.Kye
		bne PullFromDown
	PullToPlayerDown:
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		sta PX
		sty PY
		dec PY
		jsr MoveTileDown
		ldy PY
		SetScreenPtrRowY()
		ldy PX
		lda (ScreenPtr),y
		cmp #Piece.StickerTB
		beq !+
		tay
		lda PieceFlags,y
		bpl !+
		lda PX
		ldy PY
		jsr MoveTileDown
	!:	jmp NextObject		
	PullFromDown:
		tay
		lda PieceFlags,y
		bpl Done
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		iny
		iny
		jsr MoveTileUp

	Done:
		jmp NextObject	
}

UpdateAutoSlider: {
		lda #Piece.Sliders
		jmp UpdateAutoCommon
}

UpdateAutoRocky: {
		lda #Piece.Rockies
		jmp UpdateAutoCommon
}

UpdateAutoCommon: {
		sta K
		lda PiecesRotatedAntiClockwise - Piece.Active,y
		jsr UpdateObjectType
		ldy Level.ObjectStates,x
		bmi !+
		iny
	!:	tya
		sta Level.ObjectStates,x
		cmp Level.ObjectYs,x
		beq !+
		bcs Armed
	!:	jmp NextObject

	Armed:
		ldy Level.ObjectYs,x
		dey
		clc
		lda RowAddressesLow,y
		adc Level.ObjectXs,x
		sta ScreenPtr
		lda RowAddressesHigh,y
		adc #0
		sta ScreenPtr + 1
		lda Level.ObjectTypes,x
		and #$03

	CheckRight:
		sta I
		bne CheckDown
		ldy #(Screen.Width + 1)
		lda (ScreenPtr),y
		bne Done
		ldy Level.ObjectYs,x
		lda Level.ObjectXs,x
		tax
		inx
		lda K
		jmp Shoot

	CheckDown:
		dec I
		bne CheckLeft
		ldy #(Screen.Width * 2)
		lda (ScreenPtr),y
		bne Done
		ldy Level.ObjectYs,x
		lda Level.ObjectXs,x
		tax
		iny
		lda K
		ora #$01
		jmp Shoot

	CheckLeft:
		dec I
		bne CheckUp
		ldy #(Screen.Width - 1)
		lda (ScreenPtr),y
		bne Done
		ldy Level.ObjectYs,x
		lda Level.ObjectXs,x
		tax
		dex
		lda K
		ora #$02
		jmp Shoot

	CheckUp:
		dec I
		bne CheckLeft
		ldy #0
		lda (ScreenPtr),y
		bne Done
		ldy Level.ObjectYs,x
		lda Level.ObjectXs,x
		tax
		dey
		lda K
		ora #$03

	Shoot:
		stx UX
		sty UY
		jsr AddNewObject
		lda #0
		ldx Level.ObjectIndex
		sta Level.ObjectStates,x
		lsr UX
		ldx UX
		ldy UY
		jsr RefreshUnderlayTilePair
	
	Done:
		jmp NextObject
}

* = $2000 "Graphics"

CharSet:
	.fill $80 << 3, charSet.get(i)
	//.fill $80 << 3, 0
	.fill 104 << 3, 0

UnderlaySprites:
	.fill 40 << 6, 0

PlayerSprites:
	IncludePlayerSprites()

PauseSprites:
	.import binary "graphics/pause - Sprites.bin" 

* = * "Frame Routines"

WaitForNextFrame: {
		lda FrameCounter
	Wait:
		cmp FrameCounter
		beq Wait
		rts
}

WaitFrames: {
	!:	jsr WaitForNextFrame
		dex
		bne !-
		rts	
}

WaitForBottom: {
		movb System.MemoryMap : MemoryMapBackup
		movb #MemoryMap("io") : System.MemoryMap
		lda #250
	Wait:
		cmp VIC.RasterLine
		bcs Wait
	.label MemoryMapBackup = * + 1
		movb #0 : System.MemoryMap
		rts
}

ProcessInput: {
		lda CIA1.Joy2
		eor #$ff // %000FRLDU
		sta Input.Buffer

	Horizontal: {
			lda #%00001100
			and Input.Buffer
			bne CheckChange

		Reset:
			// If there's no horizontal input, reset to idle state
			lda #Input.StateIdle
			sta Input.HorizontalState
			jmp Done

		CheckChange:
			// If we're idle or the direction changed since last time, immediately start the first trigger in the new direction
			ldx Input.HorizontalState
			cpx #Input.StateIdle
			beq StartFirstTrigger
			lsr
			lsr
			lsr
			ror
			eor Input.HorizontalState
			bmi StartFirstTrigger

		Continue:
			// Execute the state machine to emit repeated triggers in the current active direction
			lda Input.HorizontalState
			and #Input.StateMask
			cmp #Input.StateFirstTrigger
			bcc StartFirstTrigger
			cmp #Input.StateNextTrigger
			bcc FirstTrigger

		NextTrigger:
			cmp #(Input.StateNextTrigger + Frequency.MoveTickFrames)
			bcc AdvanceTrigger
		StartNextTrigger:
			lda Input.HorizontalState
			and #Input.DirectionMask
			ora #(Input.StateNextTrigger - 1)
			sta Input.HorizontalState
			sta Input.HorizontalTrigger
		AdvanceTrigger:
			inc Input.HorizontalState
			jmp Done

		FirstTrigger:
			cmp #(Input.StateFirstTrigger + Frequency.StartMoveTickFrames)
			bcc AdvanceTrigger
			bcs StartNextTrigger

		StartFirstTrigger:
			lda Input.Buffer
			lsr
			lsr
			lsr
			ror
			and #Input.DirectionMask
			ora #Input.StateFirstTrigger
			sta Input.HorizontalState
			sta Input.HorizontalTrigger

		Done:
	}

	Vertical: {
			lda #%00000011
			and Input.Buffer
			bne CheckChange

		Reset:
			// If there's no vertical input, reset to idle state
			lda #Input.StateIdle
			sta Input.VerticalState
			jmp Done

		CheckChange:
			// If we're idle or the direction changed since last time, immediately start the first trigger in the new direction
			ldx Input.VerticalState
			cpx #Input.StateIdle
			beq StartFirstTrigger
			lsr
			ror
			eor Input.VerticalState
			bmi StartFirstTrigger

		Continue:
			// Execute the state machine to emit repeated triggers in the current active direction
			lda Input.VerticalState
			and #Input.StateMask
			cmp #Input.StateFirstTrigger
			bcc StartFirstTrigger
			cmp #Input.StateNextTrigger
			bcc FirstTrigger

		NextTrigger:
			cmp #(Input.StateNextTrigger + Frequency.MoveTickFrames)
			bcc AdvanceTrigger
		StartNextTrigger:
			lda Input.VerticalState
			and #Input.DirectionMask
			ora #(Input.StateNextTrigger - 1)
			sta Input.VerticalState
			sta Input.VerticalTrigger
		AdvanceTrigger:
			inc Input.VerticalState
			jmp Done

		FirstTrigger:
			cmp #(Input.StateFirstTrigger + Frequency.StartMoveTickFrames)
			bcc AdvanceTrigger
			bcs StartNextTrigger

		StartFirstTrigger:
			lda Input.Buffer
			lsr
			ror
			and #Input.DirectionMask
			ora #Input.StateFirstTrigger
			sta Input.VerticalState
			sta Input.VerticalTrigger

		Done:
	}

		rts
}

ResetInput: {
		lda #Input.StateIdle
		sta Input.HorizontalState
		sta Input.VerticalState
		sta Input.HorizontalTrigger
		sta Input.VerticalTrigger
		rts
}

* = * "Status Bar"

FadeInStatusBar: {
		lda #$00
		sta FadeStatusBar.FadeDirection
		beq FadeStatusBar
}

FadeOutStatusBar: {
		lda #$07
		sta FadeStatusBar.FadeDirection
}

FadeStatusBar: {
		lda #0
		sta Counter
	Loop:
		lda Counter
	.label FadeDirection = * + 1
		eor #0
		tax
		lda MenuGradient,x
		ora #GetBitmapColor(Colors.Background, 0)
		tax
		lda #Text.StatusBarWidth
		movw #(VIC.ColorRam + Screen.Width * (Level.ScreenY + Level.Height) + (Screen.Width - Text.StatusBarWidth) / 2) : ColorPtr
		jsr SetTextAreaColor
		jsr WaitForNextFrame
		inc Counter
		lda Counter
		cmp #8
		bcc Loop		
		rts
}

UpdateStatusBarText: {
		movw #(Screen.Address + Screen.Width * (Level.ScreenY + Level.Height) + (Screen.Width - Text.StatusBarWidth) / 2) : ScreenPtr
		lda #Text.StatusBarWidth
		ldx #Text.StatusBarBaseCode
		jsr PrepareTextArea
		SetFixedTargetCharPtrByCode(Text.StatusBarBaseCode)
		lda #Text.StatusBarWidth
		jsr ClearTextArea
		jsr MeasureText
		SetFixedTargetCharPtrByCode(Text.StatusBarBaseCode)
		center_x #(Text.StatusBarWidth * 8) : Text.Width
		ldy #0
		jmp DisplayText
}

* = * "Load Level"

// Store the address of level pack A to LevelPackPtr
SetLevelPackPtr: {
		asl
		tay
		movw LevelPacks + 1,y : LevelPackPtr
		rts
}

// Update LevelPackPtr to point after the string it's currently pointing to
SkipLevelPackName: {
		ldy #0
	Loop:
		lda (LevelPackPtr),y
		iny
		cmp #Text.Terminator
		bne Loop
		sty I
		clc
		lda LevelPackPtr
		adc I
		sta LevelPackPtr
		lda LevelPackPtr + 1
		adc #0
		sta LevelPackPtr + 1
		rts
}

LoadLevel: {
		movb #MemoryMap("ram") : System.MemoryMap

		movw #Screen.Address : TargetPtr
		lda #0
		jsr FillScreenBuffer

		lda Menu.PackIndex
		jsr SetLevelPackPtr
		jsr SkipLevelPackName

		lda Menu.LevelIndex
		ldy #0
		cmp (LevelPackPtr),y
		bcc ValidIndex
		lda (LevelPackPtr),y
		sta Menu.LevelIndex
		dec Menu.LevelIndex
		jmp ShowLevelPicker

	ValidIndex:
		asl
		tay
		iny
		lda (LevelPackPtr),y
		sta LevelPtr
		iny
		lda (LevelPackPtr),y
		sta LevelPtr + 1		

		ldx #2
		jsr SkipLevelDataText
		sty I
		clc
		lda LevelPtr
		adc I
		sta SourcePtr
		lda LevelPtr + 1
		adc #0
		sta SourcePtr + 1
		lda #>Screen.Address
		sta CharScreenPtr + 1
		lda #(Level.ScreenOffset + Screen.Width + 1)
		sta CharScreenPtr
		ldy #0
		sty Counter
		lda #Level.InnerHeight
		sta PY
	FillRows:
		lda #Level.InnerWidth
		sta PX
	FillRow:
		lda Counter
		beq ReadNext
		dec Counter
		ldx Tile
		jmp Write
	ReadNext:
		lda (SourcePtr),y
		iny
		bne !+
		inc SourcePtr + 1
	!:	tax
		asl
		bcc Write
		bpl EmptyRun
		lda (SourcePtr),y
		sta Tile
		iny
		bne !+
		inc SourcePtr + 1
	!:	jmp SetCounter
	EmptyRun:
		lda #0
		sta Tile
	SetCounter:
		txa
		and #$3f
		clc
		adc #1
		sta Counter
		ldx Tile
	Write:
	.label CharScreenPtr = * + 1
		stx $ffff
		inc CharScreenPtr
		bne Next
		inc CharScreenPtr + 1
	Next:
		dec PX
		bne FillRow
		clc
		lda CharScreenPtr
		adc #(Screen.Width - Level.InnerWidth)
		sta CharScreenPtr
		lda CharScreenPtr + 1
		adc #0
		sta CharScreenPtr + 1
		dec PY
		bne FillRows

		lda #5
		sta Screen.Address + Level.ScreenOffset + Level.Width - 1
		sta Screen.Address + Level.ScreenOffset + Screen.Width + Level.Width - 1

		ldx #Level.InnerWidth
	FillTopBottom:
		ldy #6
		lda Screen.Address + Level.ScreenOffset + Screen.Width,x
		cmp #Piece.WallStart
		bcc EmitTopWall
		cmp #Piece.WallEnd
		bcs EmitTopWall
		ldy #4
		lda Screen.Address + Level.ScreenOffset + Screen.Width + 1,x
		cmp #Piece.WallStart
		bcc EmitTopWall
		cmp #Piece.WallEnd
		bcs EmitTopWall
		ldy #3
	EmitTopWall:
		tya
		sta Screen.Address + Level.ScreenOffset,x
		lda #6
		sta Screen.Address + Level.ScreenOffset + (Level.Height - 1) * Screen.Width,x
		dex
		bne FillTopBottom

		movw #(Screen.Address + Level.ScreenOffset) : ScreenPtr

		lda #(Level.Height - 1)
		sta Counter
	FillSides:
		ldx #5
		ldy #1
		lda (ScreenPtr),y
		cmp #Piece.WallStart
		bcc EmitLeftWall
		cmp #Piece.WallEnd
		bcs EmitLeftWall
		ldx #4
		ldy #(Screen.Width + 1)
		lda (ScreenPtr),y
		cmp #Piece.WallStart
		bcc EmitLeftWall
		cmp #Piece.WallEnd
		bcs EmitLeftWall
		ldx #3
	EmitLeftWall:
		txa
		ldy #0
		sta (ScreenPtr),y
		lda #5
		ldy #Level.Width - 1
		sta (ScreenPtr),y
		clc
		lda ScreenPtr
		adc #Screen.Width
		sta ScreenPtr
		bcc NextRow
		inc ScreenPtr + 1
	NextRow:
		dec Counter
		bne FillSides

		lda #6
		sta Screen.Address + Level.ScreenOffset + (Level.Height - 1) * Screen.Width
		lda #7
		sta Screen.Address + Level.ScreenOffset + (Level.Height - 1) * Screen.Width + Level.Width - 1

		movb #MemoryMap("io") : System.MemoryMap

		movw #VIC.ColorRam : TargetPtr
		lda #0
		jsr FillScreenBuffer

		movw #(Screen.Address + Level.ScreenY * Screen.Width + Level.ScreenX) : SourcePtr
		movw #(VIC.ColorRam + Level.ScreenY * Screen.Width + Level.ScreenX) : TargetPtr
		movb #Level.Height : Counter
	SetColorRows:
		ldy #(Level.Width - 1)
	SetColors:
		lda (SourcePtr),y
		tax
		lda CharColors,x
		sta (TargetPtr),y
		dey
		bpl SetColors
		clc
		lda SourcePtr
		adc #Screen.Width
		sta SourcePtr
		sta TargetPtr
		bcc !+
		inc SourcePtr + 1
		inc TargetPtr + 1
	!:	dec Counter
		bne SetColorRows

		rts		
}

* = * "Text Routines"

// Point TargetCharPtr at the bitmap position (X,Y), i.e. Menu.Bitmap + Y * 320 + X * 8
SetTargetCharPtrByPosition: {
		txa
		asl
		asl
		sta PX
		lda #(>Menu.Bitmap >> 1)
		asl PX
		rol
		sta UX
		sty PY
		tya
		asl
		asl
		clc
		adc PY
		sta UY
		lda #0
		lsr UY
		ror
		lsr UY
		ror
		adc PX
		sta TargetCharPtr
		lda UX
		adc UY
		sta TargetCharPtr + 1
		rts
}

// Point ColorPtr at characer position (X,Y), i.e. Menu.Colors + Y * 40 + X
SetMenuColorPtr: {
		sty PY
		tya
		asl
		asl
		clc
		adc PY
		asl
		asl
		rol PY
		asl
		rol PY
		clc
		stx PX
		adc PX
		sta ColorPtr
		lda PY
		and #3
		adc #0
		adc #>Menu.Colors
		sta ColorPtr + 1
		rts
}

// Prepare an area of the screen for showing text starting from code X for a width of A chars at ScreenPtr.
PrepareTextArea: {
		sta LoopCount
		clc
		lda ScreenPtr
		adc #Screen.Width
		sta FarScreenPtr
		lda ScreenPtr + 1
		adc #0
		sta FarScreenPtr + 1
		ldy #0
	Fill:
		txa
		sta (ScreenPtr),y
		clc
		adc #Screen.Width
		sta (FarScreenPtr),y
		inx
		iny
	Next:
	.label LoopCount = * + 1
		cpy #0
		bne Fill
		rts	
}

// Clear an A*8 x 16 pixel bitmap area at TargetCharPtr.
ClearTextArea: {
		sta Counter
		clc
		lda TargetCharPtr
		adc #<320
		sta TargetCharBottomPtr
		lda TargetCharPtr + 1
		adc #>320
		sta TargetCharBottomPtr + 1
	Loop:
		ldy #0
		tya
		ldx Counter
		cpx #$20
		bcs Clear
		txa
		asl
		asl
		asl
		tay
		lda #0
	Clear:
		dey
		sta (TargetCharPtr),y
		sta (TargetCharBottomPtr),y
		bne Clear
		inc TargetCharPtr + 1
		inc TargetCharBottomPtr + 1
		sec
		lda Counter
		sbc #$20
		sta Counter
		bpl Loop
		rts
}

// Set the color of an A x 2 character area at ColorPtr to X.
SetTextAreaColor: {
		sta Count
		txa
		ldy #0
	TopLoop:
		sta (ColorPtr),y
		iny
	.label Count = * + 1
		cpy #0
		bcc TopLoop
		clc
		tya
		adc #(Screen.Width - 1)
		tay
		txa
	BottomLoop:
		sta (ColorPtr),y
		dey
		cpy #Screen.Width
		bcs BottomLoop
		rts
}


// Measure the width of the text at TextPtr in pixels and store it in Text.Width.
MeasureText: {	
		lda TextPtr
		sta TextSourcePtr
		lda TextPtr + 1
		sta TextSourcePtr + 1
		ldx #0
		stx Text.Width
		stx Text.Width + 1
	Loop:
	.label TextSourcePtr = * + 1
		ldy $ffff,x
		bmi Done
		inx
		clc
		lda Text.Width
		adc TextCharWidths,y
		sta Text.Width
		bcc Loop
		inc Text.Width + 1
		jmp Loop
	Done:
		rts
}

// Display the text at TextPtr with bitwise OR in the screen area pointed by TargetCharPtr with a pixel offset of X and character spacing of Y.
DisplayText: {
		sty CharacterSpacing
		txa
		and #$07
		sta Text.CurrentShift
		txa
		and #$f8
		sta OffsetX

		lda TextPtr
		sta TextSourcePtr1
		sta TextSourcePtr2
		lda TextPtr + 1
		sta TextSourcePtr1 + 1
		sta TextSourcePtr2 + 1

		clc
		lda TargetCharLeftPtr
	.label OffsetX = * + 1
		adc #0
		sta TargetCharLeftPtr
		lda TargetCharLeftPtr + 1
		adc #0
		sta TargetCharLeftPtr + 1
		//clc
		lda TargetCharLeftPtr
		adc #8
		sta TargetCharRightPtr
		lda TargetCharLeftPtr + 1
		adc #0
		sta TargetCharRightPtr + 1
		lda #0
		sta Counter
	Write:
		ldx Counter
	.label TextSourcePtr1 = * + 1
		lda $ffff,x
		bpl WriteChar
		rts
	WriteChar:
		sta Text.CharOffsetHigh
		lda #0
		lsr Text.CharOffsetHigh
		ror
		lsr Text.CharOffsetHigh
		ror
		lsr Text.CharOffsetHigh
		ror
		lsr Text.CharOffsetHigh
		ror
		adc #<TextCharSet
		sta SourceCharTopPtr
		lda Text.CharOffsetHigh
		adc #>TextCharSet		
		sta SourceCharTopPtr + 1
		//sec
		lda SourceCharTopPtr
		//sbc #$38
		sbc #$37 // Subtract $38
		sta SourceCharBottomPtr
		lda SourceCharTopPtr + 1
		sbc #0
		sta SourceCharBottomPtr + 1
		ldy #2
	CopyCharTop: {
			lda #0
			sta Text.RightByte
		.label @SourceCharTopPtr = * + 1
			lda $ffff,y
			ldx Text.CurrentShift
		ShiftByte:
			dex
			bmi ShiftDone
			lsr
			ror Text.RightByte
			jmp ShiftByte
		ShiftDone:
			ora (TargetCharLeftPtr),y
			sta (TargetCharLeftPtr),y
			lda Text.RightByte
			ora (TargetCharRightPtr),y
			sta (TargetCharRightPtr),y
		Next:
			iny
			cpy #8
			bne CopyCharTop
	}
		inc TargetCharLeftPtr + 1
		inc TargetCharRightPtr + 1
		ldy #$40
	CopyCharBottom: {
			lda #0
			sta Text.RightByte
		.label @SourceCharBottomPtr = * + 1
			lda $ffff,y
			ldx Text.CurrentShift
		ShiftByte:
			dex
			bmi ShiftDone
			lsr
			ror Text.RightByte
			jmp ShiftByte
		ShiftDone:
			ora (TargetCharLeftPtr),y
			sta (TargetCharLeftPtr),y
			lda Text.RightByte
			ora (TargetCharRightPtr),y
			sta (TargetCharRightPtr),y
		Next:
			iny
			cpy #$47
			bne CopyCharBottom
	}
		dec TargetCharLeftPtr + 1
		dec TargetCharRightPtr + 1
	Advance:
		ldx Counter
	.label TextSourcePtr2 = * + 1
		lda $ffff,x
		tax
		clc
		lda Text.CurrentShift
		adc TextCharWidths,x
		clc
	.label CharacterSpacing = * + 1
		adc #0
	CheckAdvance:
		sta Text.CurrentShift
		cmp #8
		bcc NextChar
		clc
		lda TargetCharRightPtr
		sta TargetCharLeftPtr
		adc #8
		sta TargetCharRightPtr
		lda TargetCharRightPtr + 1
		sta TargetCharLeftPtr + 1
		adc #0
		sta TargetCharRightPtr + 1
		lda Text.CurrentShift
		sbc #7 // Subtract 8, as carry is always 0 at this point
		jmp CheckAdvance
	NextChar:
		inc Counter
		jmp Write
}

DisplayBoldText: {
		lda TextPtr
		sta TextPtrLow
		lda TextPtr + 1
		sta TextPtrHigh
		lda TargetCharPtr
		sta CharPtrLow
		lda TargetCharPtr + 1
		sta CharPtrHigh
		stx XOffset
		sty CharSpacing
		jsr DisplayText
	.label TextPtrLow = * + 1
		lda #0
		sta TextPtr
	.label TextPtrHigh = * + 1
		lda #0
		sta TextPtr + 1
	.label CharPtrLow = * + 1
		lda #0
		sta TargetCharPtr
	.label CharPtrHigh = * + 1
		lda #0
		sta TargetCharPtr + 1
	.label XOffset = * + 1
		ldx #0
		inx
	.label CharSpacing = * + 1
		ldy #0
		jmp DisplayText
}

* = * "Menu"

FadeInContents: {
		lda #$00
		sta FadeContents.FadeDirection
		beq FadeContents
}

FadeOutContents: {
		lda #$07
		sta FadeContents.FadeDirection
}

FadeContents: {
		movb #0 : Counter
	Loop:
		movw #(Menu.Colors + Screen.Width * Menu.ContentsY) : TargetPtr
		jsr WaitForBottom
		lda Counter
	.label FadeDirection = * + 1
		eor #0
		tax
		movb #MemoryMap("io") : System.MemoryMap
		lda KyeGradient,x
		sta VIC.SpriteColor1
		lda DiamondGgradient,x
		sta VIC.SpriteColor2
		lda UnderlayGradient,x
		sta VIC.SpriteColor3
		lda BlobGradient,x
		sta VIC.SpriteColor5
		lda MenuGradient,x
		sta VIC.SpriteColor0
		sta VIC.SpriteColor4
		asl
		asl
		asl
		asl
		ora #Colors.Background
		ldx #MemoryMap("ram")
		stx System.MemoryMap
		ldx #<(Screen.Width * (Screen.Height - Menu.ContentsY))
		ldy #>(Screen.Width * (Screen.Height - Menu.ContentsY))
		jsr FillBuffer
		inc Counter
		lda Counter
		cmp #8
		bcc Loop		
		rts
}

ClearScreenAndDrawTitle: {
		movb #MemoryMap("ram") : System.MemoryMap

		movw #Menu.Colors : TargetPtr
		lda #GetBitmapColor(BLACK, WHITE)
		ldx #<(Screen.Width * Menu.ContentsY)
		ldy #>(Screen.Width * Menu.ContentsY)
		jsr FillBuffer

		movw #(Menu.Colors + Screen.Width * Menu.ContentsY) : TargetPtr
		lda #GetBitmapColor(WHITE, WHITE)
		ldx #<(Screen.Width * (Screen.Height - Menu.ContentsY))
		ldy #>(Screen.Width * (Screen.Height - Menu.ContentsY))
		jsr FillBuffer

		movw #Menu.Bitmap : TargetPtr
		lda #0
		ldx #<8000
		ldy #>8000
		jsr FillBuffer

		jsr DrawTitle

		jsr WaitForBottom

		movb #MemoryMap("io") : System.MemoryMap
		SetVicBank(3)
		movb #MemorySetup("screen=" + toHexString(Menu.Colors) + ",bitmap=1") : VIC.MemorySetup
		movb #ScreenControl1("mode=bitmap,screen_height=25,vertical_scroll=3") : VIC.ScreenControl1
		rts
}

DrawTitle: {
		ldx #12
		ldy #1
		jsr SetTargetCharPtrByPosition
		lda #0
		sta Counter
		lda #5
		sta I
	DrawRows:
		lda #16
		sta J
		ldy #0
	DrawBlocks:
		ldx Counter
		lda TitleMap,x
		asl
		asl
		asl
		rol K
		clc
		adc #<TitleBlocks
		sta BlockBase
		lda K
		and #1
		adc #>TitleBlocks
		sta BlockBase + 1
		ldx #0
	DrawBlock:
	.label BlockBase = * + 1
		lda $ffff,x
		sta (TargetCharPtr),y
		iny
		inx
		cpx #8
		bcc DrawBlock
		inc Counter
		dec J
		bne DrawBlocks
		clc
		lda TargetCharPtr
		adc #<320
		sta TargetCharPtr
		lda TargetCharPtr + 1
		adc #>320
		sta TargetCharPtr + 1
		dec I
		bne DrawRows

	.label KyeLogoColors = Menu.Colors + Screen.Width * 2 + 13
		lda #GetBitmapColor(Colors.KyeOutline, Colors.Kye)
		sta KyeLogoColors
		sta KyeLogoColors + 1
		sta KyeLogoColors + 2
		sta KyeLogoColors + Screen.Width
		sta KyeLogoColors + Screen.Width + 1
		sta KyeLogoColors + Screen.Width + 2
		sta KyeLogoColors + Screen.Width * 2
		sta KyeLogoColors + Screen.Width * 2 + 1
		sta KyeLogoColors + Screen.Width * 2 + 2
		rts
}

ShowTitleScreen: {
		movb #1 : Menu.Active

		jsr ClearScreenAndDrawTitle

		movb #MemoryMap("ram") : System.MemoryMap

		DisplayFixedText(InstructionsText1, 8, 14, 0, 0)
		DisplayFixedText(InstructionsText2, 8, 16, 0, 0)
		DisplayFixedText(InstructionsText3, 8, 18, 0, 0)
		DisplayFixedText(StartText, 0, 22, 103, 0)
		DisplayFixedText(TitleText2, 0, 10, 40, 0)
		DisplayFixedText(TitleText1, 0, 8, 23, 0)

		movw #ColinGarbuttText : TextPtr
		ldx #6
		ldy #1
		jsr DisplayBoldText

		lda #((InstructionsSprites >> 6) + 0)
		sta Menu.Colors + $3f9
		lda #((InstructionsSprites >> 6) + 1)
		sta Menu.Colors + $3f8
		lda #((InstructionsSprites >> 6) + 2)
		sta Menu.Colors + $3fb
		lda #((InstructionsSprites >> 6) + 3)
		sta Menu.Colors + $3fa
		lda #((InstructionsSprites >> 6) + 4)
		sta Menu.Colors + $3fd
		lda #((InstructionsSprites >> 6) + 5)
		sta Menu.Colors + $3fc

		movb #MemoryMap("io") : System.MemoryMap

		lda #0
		sta VIC.SpriteColorMode
		sta VIC.SpriteXExpand
		sta VIC.SpriteYExpand
		ldx #5
		ldy #10
	InitSprites:
		lda #WHITE
		sta VIC.SpriteColor0,x
		lda #56
		sta VIC.SpriteX0,y
		dey
		dey
		dex
		bpl InitSprites
		lda #159
		sta VIC.SpriteY0
		sta VIC.SpriteY1
		lda #175
		sta VIC.SpriteY2
		sta VIC.SpriteY3
		lda #191
		sta VIC.SpriteY4
		sta VIC.SpriteY5
		lda #%00111111
		sta VIC.SpriteEnable

		jsr FadeInContents
		jsr WaitForFireRelease
		jsr FadeOutContents

		.if (SHOW_LEVEL_PICKER) {
				jmp ShowLevelPicker
		} else {
				jmp StartLevel
		}
}

PrintNames: {
		stx X
		sty Y
		movw Names : Names2
		movw Names : MaxCount
		lda #0
		sta Index
	Loop:
	.label Index = * + 1
		lda #0
	.label Count = * + 1
		cmp #0
		bcs Done
		clc
	.label Start = * + 1
		adc #0
	.label MaxCount = * + 1
		cmp $ffff
		bcs Done
		asl
		tay
		iny
	.label Names = * + 1
		lda $ffff,y
		sta TextPtr
		iny
	.label Names2 = * + 1
		lda $ffff,y
		sta TextPtr + 1
		lda Index
		asl
		clc
	.label Y = * + 1
		adc #0
		tay
	.label X = * + 1
		ldx #0
	.label TargetPtrLogic = * + 1
		jsr SetTargetCharPtrByPosition
		ldx #2
		ldy #0
		jsr DisplayText
		inc Index
		jmp Loop

	Done:
		rts
}

SetListItemActive: {
		movb #GetBitmapColor(WHITE, BLUE) : SetListItemColor.Color
		bne SetListItemColor
}

SetListItemInactive: {
		movb #GetBitmapColor(WHITE, GREY) : SetListItemColor.Color
		bne SetListItemColor
}

ResetListItem: {
		movb #GetBitmapColor(BLACK, WHITE) : SetListItemColor.Color
}

SetListItemColor: {
		lda Menu.CurrentPane
		bne UpdateLevelPane

	UpdateLevelPackPane:
		movb #Menu.PackTitleWidth : ItemWidth
		ldx #Menu.LevelPacksX		
		lda Menu.PackIndex
		bpl Update

	UpdateLevelPane:
		movb #Menu.LevelTitleWidth : ItemWidth
		ldx #Menu.LevelsX
		lda Menu.LevelIndex
		jsr WrapListIndex

	Update:
		asl
		clc
		adc #Menu.LevelsY
		tay
		jsr SetMenuColorPtr
	.label Color = * + 1
		ldx #0
	.label ItemWidth = * + 1
		lda #0
		jmp SetTextAreaColor
}

// Compute A mod Menu.LevelsCount
WrapListIndex: {
	Loop:
		cmp #Menu.LevelsCount
		bcs Next
		rts
	Next:
		sbc #Menu.LevelsCount
		jmp Loop
}

// Get the index of the first level shown in the list
GetFirstVisibleIndex: {
		lda Menu.LevelIndex
		jsr WrapListIndex
		eor #$ff
		sec
		adc Menu.LevelIndex
		rts
}

SwitchPackLevelList: {
		movb #0 : Menu.LevelIndex
}

RefreshPackLevelList: {
		lda Menu.PackIndex
		jsr SetLevelPackPtr
		jsr SkipLevelPackName
		sec
}

// Trigger level list update downwards if the carry is set, or upwards if it is cleared
UpdateLevelList: {
		lda #0
		ldx #Menu.LevelsCount
		bcs !+
		txa
		ldx #0
	!:	sta Menu.RefreshingLevelIndex
		stx Menu.RefreshingLevelTargetIndex

	UpdateScrollArrows:
		ldy #GetBitmapColor(WHITE, WHITE)
		jsr GetFirstVisibleIndex
		beq CheckLastPosition
		ldy #GetBitmapColor(BLACK, WHITE)
	CheckLastPosition:
		sty Menu.Colors + (Menu.LevelsY) * Screen.Width + Menu.LevelsX + Menu.LevelTitleWidth
		clc
		adc #Menu.LevelsCount
		ldy #0
		ldx #GetBitmapColor(WHITE, WHITE)
		cmp (LevelPackPtr),y
		bcs Done
		ldx #GetBitmapColor(BLACK, WHITE)
	Done:
		stx Menu.Colors + (Menu.LevelsY + Menu.LevelsCount * 2 - 1) * Screen.Width + Menu.LevelsX + Menu.LevelTitleWidth

		rts
}

ShowLevelPicker: {
		sei
		jsr InitFrameInterrupt
		jsr ResetInput
		ldx #$ff
		txs
		lda #1
		sta Menu.Active
		cli

		.if (SHOW_TITLE_SCREEN) {
				lda Menu.CurrentPane
				beq ClearContents
				jsr ClearScreenAndDrawTitle
				jmp Setup

			ClearContents:
				movw #(Menu.Bitmap + 320 * Menu.ContentsY) : TargetPtr
				lda #0
				ldx #<(8000 - 320 * Menu.ContentsY)
				ldy #>(8000 - 320 * Menu.ContentsY)
				jsr FillBuffer
		} else {
				jsr ClearScreenAndDrawTitle
		}

	Setup:
		movb #MemoryMap("io") : System.MemoryMap
		lda #0
		sta VIC.SpriteEnable
		movb #MemoryMap("ram") : System.MemoryMap

		ldx #Menu.LevelsCount
	InitFadeStates:
		dex
		sta Menu.LevelFadeStates,x
		bne InitFadeStates

		ldx #Menu.LevelPacksX
		ldy #Menu.ContentsY
		jsr SetTargetCharPtrByPosition
		movw #LevelPacksText : TextPtr
		ldx #2
		ldy #2
		jsr DisplayBoldText

		ldx #Menu.LevelsX
		ldy #Menu.ContentsY
		jsr SetTargetCharPtrByPosition
		movw #LevelsText : TextPtr
		ldx #2
		ldy #2
		jsr DisplayBoldText

		movw #LevelPacks : PrintNames.Names
		movb #0 : PrintNames.Start
		movb #Menu.LevelsCount : PrintNames.Count
		ldx #Menu.LevelPacksX
		ldy #Menu.LevelsY
		jsr PrintNames

		jsr FadeInContents
		jsr RefreshPackLevelList

	DrawScrollArrows: {
			ldy #5
			ldx #0
		Loop:
			lda ScrollArrowImage,y
			sta Menu.Bitmap + Menu.LevelsY * 320 + (Menu.LevelsX + Menu.LevelTitleWidth) * 8,y
			sta Menu.Bitmap + (Menu.LevelsY + Menu.LevelsCount * 2 - 1) * 320 + (Menu.LevelsX + Menu.LevelTitleWidth) * 8,x
			inx
			dey
			bpl Loop
	}

		lda Menu.CurrentPane
		beq !+
		dec Menu.CurrentPane
		jsr SetListItemInactive
		inc Menu.CurrentPane
	!:	jsr SetListItemActive

	MenuLoop:
		lda FrameCounter
		cmp #1
		bcs !+
		jmp CheckInput
	!:	movb #0 : FrameCounter

	UpdateFadeStates: {
			lda Menu.LevelIndex
			jsr WrapListIndex
			sta CurrentIndex
			ldy #0
		Loop:
			sty YBackup
			ldx Menu.LevelFadeStates,y
			cpx #7
			bcs Next
			inx
			stx Menu.LevelFadeStates,y
			lda Menu.CurrentPane
			beq Fade
		.label CurrentIndex = * + 1
			cpy #0
			beq Next
		Fade:
			lda MenuGradient,x
			asl
			asl
			asl
			asl
			ora #WHITE
			sta Color
			ldx #Menu.LevelsX
			tya
			asl
			adc #Menu.LevelsY
			tay
			jsr SetMenuColorPtr
			lda #Menu.LevelTitleWidth
		.label Color = * + 1
			ldx #0
			jsr SetTextAreaColor			
		Next:
		.label YBackup = * + 1
			ldy #0
			iny
			cpy #Menu.LevelsCount
			bcc Loop
	}

		lda Menu.RefreshingLevelIndex
		cmp Menu.RefreshingLevelTargetIndex
		beq CheckInput
		bcc UpdateRefreshingLevel
		dec Menu.RefreshingLevelIndex

	UpdateRefreshingLevel: {
			ldx Menu.RefreshingLevelIndex
			lda #0
			sta Menu.LevelFadeStates,x
			jsr GetFirstVisibleIndex
			clc
			adc Menu.RefreshingLevelIndex
			sta LevelIndex
			asl
			tay
			iny
			lda (LevelPackPtr),y
			sta TextPtr
			iny
			lda (LevelPackPtr),y
			sta TextPtr + 1
			ldx #Menu.LevelsX
			lda Menu.RefreshingLevelIndex
			asl
			adc #Menu.LevelsY
			tay
			jsr SetTargetCharPtrByPosition
			jsr SetMenuColorPtr
			movw TargetCharPtr : TargetCharRightPtr
			lda Menu.LevelIndex
			cmp LevelIndex
			beq !+
			lda #Menu.LevelTitleWidth
			ldx #GetBitmapColor(WHITE, WHITE)
			jsr SetTextAreaColor			
		!:	lda #Menu.LevelTitleWidth
			jsr ClearTextArea
		.label LevelIndex = * + 1
			lda #$ff
			ldy #0
			cmp (LevelPackPtr),y
			bcs Done
			movw TargetCharRightPtr : TargetCharPtr
			ldx #2
			jsr DisplayText
		Done:
			lda Menu.RefreshingLevelTargetIndex
			beq CheckInput
			inc Menu.RefreshingLevelIndex
	}

	CheckInput:

	CheckUp: {
			bit Input.VerticalTrigger
			bpl CheckDown
			bvc CheckDown
			lda Menu.CurrentPane
			bne CheckLevelUp

		CheckLevelPackUp:
			lda Menu.PackIndex
			beq Done
			jsr ResetListItem
			dec Menu.PackIndex
			jsr SetListItemActive
			jsr SwitchPackLevelList
			jmp Done

		CheckLevelUp:
			lda Menu.LevelIndex
			beq Done
			jsr ResetListItem
			lda Menu.LevelIndex
			dec Menu.LevelIndex
			jsr WrapListIndex
			cmp #0
			bne HighlightLevel
			clc
			jsr UpdateLevelList

		HighlightLevel:
			jsr SetListItemActive

		Done:
			lda #0
			sta Input.VerticalTrigger
			jmp MenuLoop
	}

	CheckDown: {
			bmi CheckLeft
			bvc CheckLeft
			lda Menu.CurrentPane
			bne CheckLevelDown

		CheckLevelPackDown:
			lda LevelPacks
			clc
			sbc Menu.PackIndex
			beq Done
			jsr ResetListItem
			inc Menu.PackIndex
			jsr SetListItemActive
			jsr SwitchPackLevelList
			jmp Done

		CheckLevelDown:
			ldy #0
			lda (LevelPackPtr),y
			clc
			sbc Menu.LevelIndex
			beq Done
			jsr ResetListItem
			inc Menu.LevelIndex
			lda Menu.LevelIndex
			jsr WrapListIndex
			cmp #0
			bne HighlightLevel
			sec
			jsr UpdateLevelList

		HighlightLevel:
			jsr SetListItemActive

		Done:
			lda #0
			sta Input.VerticalTrigger
			jmp MenuLoop
	}

	CheckLeft: {
			bit Input.HorizontalTrigger
			bpl CheckRight
			bvc CheckRight
			lda Menu.CurrentPane
			beq Done
			jsr SetListItemInactive
			dec Menu.CurrentPane
			jsr SetListItemActive

		Done:
			lda #0
			sta Input.HorizontalTrigger
			jmp MenuLoop
	}

	CheckRight: {
			bmi CheckFire
			bvc CheckFire
			lda Menu.CurrentPane
			bne Done
			jsr SetListItemInactive
			inc Menu.CurrentPane
			jsr SetListItemActive

		Done:
			lda #0
			sta Input.HorizontalTrigger
			jmp MenuLoop
	}

	CheckFire: {
			lda Input.Buffer
			and #%00010000
			beq Done
			lda Menu.CurrentPane
			beq Done
			jsr WaitForFireRelease
			jmp StartLevel

		Done:
			jmp MenuLoop
	}
}

NextRandom: {
		inc RandomIndex1
		bne !+
		inc RandomIndex2
	!:	ldy RandomIndex1
		lda Random,y
		ldy RandomIndex2
		eor Random + $100,y
		rts
}

// We need to make sure we have a zero at $3fff, so just .align $100 is not enough

* = $4000 "Music"

InitMusic:
.label PlayMusicFrame = InitMusic + 3
.label PlaySoundEffect = InitMusic + 6
#if NTSC
	.import binary "sound/music-ntsc.bin"
#else
	.import binary "sound/music-pal.bin"
#endif
SoundDeath:
	.import binary "sound/sfx-death.bin"
SoundDiamond:
	.import binary "sound/sfx-diamond.bin"

.align $100

* = * "Aligned Tables"

Random:
	.var random = List()
	.for (var i = 0; i < 256; i++) {
		.eval random.add(i)
	}
	.eval random.shuffle()
	.fill $100, random.get(i)
	.eval random.shuffle()
	.fill $100, random.get(i)

CharColors:
	.fill $80, charColors.get(i)

// Each piece has the following flag bits:
// - bit 0: the piece has a round top left corner
// - bit 1: the piece has a round top right corner
// - bit 2: the piece has a round bottom left corner
// - bit 3: the piece has a round bottom right corner
// - bit 5: touching this piece kills the player
// - bit 6: a bouncer can push this piece
// - bit 7: this piece is generally movable (the player can push it and stickers can pull it)
PieceFlags:
	.for (var i = 0; i < $80; i++) {
		.var flags = 0
		.if (i == Piece.BlockRound || (i >= Piece.Rockies && i < Piece.Rockies + 4)) {
			.eval flags = flags | $0f
		}
		.if (i >= 3 && i <= 24) {
			.var ch = i << 3
			.if ((charSet.get(ch) & $80) == 0) {
				.eval flags = flags | 1
			}
			.if ((charSet.get(ch) & $02) == 0) {
				.eval flags = flags | 2
			}
			.if ((charSet.get(ch + 6) & $80) == 0) {
				.eval flags = flags | 4
			}
			.if ((charSet.get(ch + 6) & $02) == 0) {
				.eval flags = flags | 8
			}
		}
		.if (i >= Piece.Monsters && i < Piece.Monsters + 10) {
			.eval flags = flags | $20
		}
		.if (pushablePieces.containsKey(i)) {
			.eval flags = flags | $40
			.if (i < Piece.BlackholeFull || i >= Piece.BlackholeFull + 4) {
				.eval flags = flags | $80
			}
		}
		.byte flags
	}

TopNybbles:
	.for (var i = 0; i < $80; i++) {
		.byte underlayIndicesByChar.get(i) << 4
	}

BottomNybbles:
	.for (var i = 0; i < $80; i++) {
		.byte underlayIndicesByChar.get(i)
	}

UnderlayImagesRow1:
	IncludeUnderlays(0)

UnderlayImagesRow2:
	IncludeUnderlays(4)

UnderlayImagesRow3:
	IncludeUnderlays(8)

UnderlayImagesRow4:
	IncludeUnderlays(12)

UnderlayImagesRow5:
	IncludeUnderlays(16)

TextCharSet:
	.fill textCharSet.getSize(), textCharSet.get(i)

* = * "Small Tables"

TextCharWidths:
	.fill textCharWidths.size(), textCharWidths.get(i)

PiecesRotatedClockwise:
	.for (var i = Piece.Active; i < Piece.Blackhole; i++) {
		.byte (i & $fc) | ((i + 1) & $03)
	}

PiecesRotatedAntiClockwise:
	.for (var i = Piece.Active; i < Piece.Blackhole; i++) {
		.byte (i & $fc) | ((i - 1) & $03)
	}

ActivePieceTimings:
	.for (var i = Piece.Active; i < Piece.Unused; i++) {
		.byte pieceTimings.get(i)
	}

.define updateAddresses {
	.var updateAddresses = Hashtable()

	.eval updateAddresses.put(Piece.Timer0, UpdateTimer)
	.eval updateAddresses.put(Piece.Timer1, UpdateTimer)
	.eval updateAddresses.put(Piece.Timer2, UpdateTimer)
	.eval updateAddresses.put(Piece.Timer3, UpdateTimer)
	.eval updateAddresses.put(Piece.Timer4, UpdateTimer)
	.eval updateAddresses.put(Piece.Timer5, UpdateTimer)
	.eval updateAddresses.put(Piece.Timer6, UpdateTimer)
	.eval updateAddresses.put(Piece.Timer7, UpdateTimer)
	.eval updateAddresses.put(Piece.Timer8, UpdateTimer)
	.eval updateAddresses.put(Piece.Timer9, UpdateTimer)

	.eval updateAddresses.put(Piece.Twister, UpdateMonster)
	.eval updateAddresses.put(Piece.Twister + 1, UpdateMonster)
	.eval updateAddresses.put(Piece.Gnasher, UpdateMonster)
	.eval updateAddresses.put(Piece.Gnasher + 1, UpdateMonster)
	.eval updateAddresses.put(Piece.Blob, UpdateMonster)
	.eval updateAddresses.put(Piece.Blob + 1, UpdateMonster)
	.eval updateAddresses.put(Piece.Virus, UpdateMonster)
	.eval updateAddresses.put(Piece.Virus + 1, UpdateMonster)
	.eval updateAddresses.put(Piece.Spike, UpdateMonster)
	.eval updateAddresses.put(Piece.Spike + 1, UpdateMonster)

	.eval updateAddresses.put(Piece.Blackhole, UpdateEmptyBlackhole)
	.eval updateAddresses.put(Piece.Blackhole + 1, UpdateEmptyBlackhole)
	.eval updateAddresses.put(Piece.Blackhole + 2, UpdateEmptyBlackhole)
	.eval updateAddresses.put(Piece.Blackhole + 3, UpdateEmptyBlackhole)
	.eval updateAddresses.put(Piece.BlackholeFull, UpdateFullBlackhole)
	.eval updateAddresses.put(Piece.BlackholeFull + 1, UpdateFullBlackhole)
	.eval updateAddresses.put(Piece.BlackholeFull + 2, UpdateFullBlackhole)
	.eval updateAddresses.put(Piece.BlackholeFull + 3, UpdateFullBlackhole)

	.eval updateAddresses.put(Piece.SliderUp, UpdateSliderUp)
	.eval updateAddresses.put(Piece.SliderLeft, UpdateSliderLeft)
	.eval updateAddresses.put(Piece.SliderDown, UpdateSliderDown)
	.eval updateAddresses.put(Piece.SliderRight, UpdateSliderRight)

	.eval updateAddresses.put(Piece.RockyUp, UpdateRockyUp)
	.eval updateAddresses.put(Piece.RockyLeft, UpdateRockyLeft)
	.eval updateAddresses.put(Piece.RockyDown, UpdateRockyDown)
	.eval updateAddresses.put(Piece.RockyRight, UpdateRockyRight)

	.eval updateAddresses.put(Piece.BouncerUp, UpdateBouncerUp)
	.eval updateAddresses.put(Piece.BouncerDown, UpdateBouncerDown)
	.eval updateAddresses.put(Piece.BouncerLeft, UpdateBouncerLeft)
	.eval updateAddresses.put(Piece.BouncerRight, UpdateBouncerRight)

	.eval updateAddresses.put(Piece.StickerLR, UpdateStickerLR)
	.eval updateAddresses.put(Piece.StickerTB, UpdateStickerTB)

	.eval updateAddresses.put(Piece.AutoSlider, UpdateAutoSlider)
	.eval updateAddresses.put(Piece.AutoSlider + 1, UpdateAutoSlider)
	.eval updateAddresses.put(Piece.AutoSlider + 2, UpdateAutoSlider)
	.eval updateAddresses.put(Piece.AutoSlider + 3, UpdateAutoSlider)

	.eval updateAddresses.put(Piece.AutoRocky, UpdateAutoRocky)
	.eval updateAddresses.put(Piece.AutoRocky + 1, UpdateAutoRocky)
	.eval updateAddresses.put(Piece.AutoRocky + 2, UpdateAutoRocky)
	.eval updateAddresses.put(Piece.AutoRocky + 3, UpdateAutoRocky)
}

UpdateAddressesLow:
	.for (var i = Piece.Active; i < Piece.Unused; i++) {
		.byte updateAddresses.containsKey(i) ? <updateAddresses.get(i) : <NextObject
	}

UpdateAddressesHigh:
	.for (var i = Piece.Active; i < Piece.Unused; i++) {
		.byte updateAddresses.containsKey(i) ? >updateAddresses.get(i) : >NextObject
	}

RowAddressesLow:
	.for (var i = 0; i <= Level.Height; i++) {
		.byte <(Screen.Address + Level.ScreenOffset + i * Screen.Width)
	}

RowAddressesHigh:
	.for (var i = 0; i <= Level.Height; i++) {
		.byte >(Screen.Address + Level.ScreenOffset + i * Screen.Width)
	}

ObjectIndexRowAddressesHigh:
	.for (var i = 0; i <= Level.Height; i++) {
		.byte >(Level.ObjectIndices + Level.ScreenOffset + i * Screen.Width)
	}

StickerFieldRowAddressesHigh:
	.for (var i = 0; i <= Level.Height; i++) {
		.byte >(Level.StickerField + Level.ScreenOffset + i * Screen.Width)
	}

UnderlayColumnAddressesLow:
	.for (var i = 0; i < Level.Width / 2; i++) {
		.byte <(UnderlaySprites + floor(i / 3) * $40 * 8 + mod(i, 3))
	}

UnderlayColumnAddressesHigh:
	.for (var i = 0; i < Level.Width / 2; i++) {
		.byte >(UnderlaySprites + floor(i / 3) * $40 * 8 + mod(i, 3))
	}

.var underlayRowOffsets = List()
.var underlayRowSprite = 0
.var underlayRowSpriteOffset = (Underlay.SpriteStartY + 1) * 3
.var underlayFillTypes = List()

.for (var i = 0; i < Level.Height; i++) {
	.eval underlayRowOffsets.add((underlayRowSprite << 6) + underlayRowSpriteOffset)
	.eval underlayFillTypes.add(max(floor(underlayRowSpriteOffset / 3) - 16, 0))
	.eval underlayRowSpriteOffset += 24
	.if (underlayRowSpriteOffset >= 63) {
		.eval underlayRowSpriteOffset -= 63
		.eval underlayRowSprite++
	}
}

UnderlayRowOffsetsLow:
	.for (var i = 0; i < Level.Height; i++) {
		.byte <underlayRowOffsets.get(i)
	}

UnderlayRowOffsetsHigh:
	.for (var i = 0; i < Level.Height; i++) {
		.byte >underlayRowOffsets.get(i)
	}

UnderlayFillTypes:
	.for (var i = 0; i < Level.Height; i++) {
		.byte underlayFillTypes.get(i)
	}

UnderlayFillAddressesLow:
	.byte <FillUnderlaySingle
	.byte <FillUnderlayRow17
	.byte <FillUnderlayRow18
	.byte <FillUnderlayRow19
	.byte <FillUnderlayRow20

UnderlayFillAddressesHigh:
	.byte >FillUnderlaySingle
	.byte >FillUnderlayRow17
	.byte >FillUnderlayRow18
	.byte >FillUnderlayRow19
	.byte >FillUnderlayRow20

DiamondFrames:
	.fill 6 << 3, charSet.get(i + $800)

PlayerColors:
	.byte GREEN, GREEN, CYAN, CYAN, CYAN, LIGHT_GREEN, LIGHT_GREEN, LIGHT_GREEN, WHITE

PlayerOverlayColors:
	.byte BLACK, DARK_GREY, DARK_GREY, GREY, GREY, LIGHT_GREY, LIGHT_GREY, WHITE, WHITE

MenuGradient:
	.byte WHITE, LIGHT_GREEN, LIGHT_GREY, GREEN, ORANGE, DARK_GREY, BROWN, BLACK

KyeGradient:
	.byte WHITE, WHITE, LIGHT_GREEN, LIGHT_GREEN, LIGHT_GREY, LIGHT_GREY, GREEN, GREEN

DiamondGgradient:
	.byte WHITE, WHITE, LIGHT_GREEN, LIGHT_GREEN, CYAN, CYAN, LIGHT_BLUE, LIGHT_BLUE

UnderlayGradient:
	.byte WHITE, WHITE, WHITE, WHITE, WHITE, WHITE, YELLOW, YELLOW

BlobGradient:
	.byte WHITE, YELLOW, YELLOW, LIGHT_GREY, LIGHT_GREY, LIGHT_RED, LIGHT_RED, PURPLE

* = * "Menu Data"

TitleBlocks:
	.import binary "graphics/kye-title - Chars.bin"

TitleMap:
	.import binary "graphics/kye-title - Map (16x5).bin"

TitleText1:
	MakeString("An original concept (c) 1992 by")

CountText:
	MakeString("999")

StatusBarText:
	MakeString("Diamonds:                Lives: 3")

VictoryText:
	MakeString("Well done!")

LostText:
	MakeString("Have another go!")

PauseMenuText:
	MakeString("Resume       Restart       Quit")

PauseMenuXs:
	.byte 83, 149, 218

ColinGarbuttText:
	MakeString("Colin Garbutt")

TitleText2:
	MakeString("Adapted to @64 by Patai Gergely in 2022")

InstructionsText1:
	MakeString("You are Kye, the green circle thing.")

InstructionsText2:
	MakeString("Collect all the diamonds!")

InstructionsText3:
	MakeString("Don't get stuck or eaten by monsters!")

StartText:
	MakeString("Press fire to start!")

LevelPacksText:
	MakeString("Level Packs")

LevelsText:
	MakeString("Levels")

ScrollArrowImage:
	.byte %00001000
	.byte %00011100
	.byte %00111110
	.byte %00111110
	.byte %01110111
	.byte %01100011

* = * "Level Data"

IncludeLevelPack("Default", "levels/default.kye")
IncludeLevelPack("Sampler", "levels/sampler.kye")
IncludeLevelPack("Plus 2", "levels/plus2.kye")
IncludeLevelPack("New Kye", "levels/newkye.kye")
IncludeLevelPack("Shapes & Monsters", "levels/shapes-monsters.kye")
IncludeLevelPack("Danish", "levels/danish.kye")

LevelPacks: IncludeLevelPackPointers()

* = Menu.Sprites "Instructions Sprites"

InstructionsSprites:
	.import binary "graphics/instructions - Sprites.bin" 
