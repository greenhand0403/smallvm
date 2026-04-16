// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

// Copyright 2019 John Maloney, Bernat Romagosa, and Jens Mönig

defineClass Display8x8Slot morph display paintMode inset stride ledWidth ledHeight

to newDisplay8x8Slot aString {
	return (initialize (new 'Display8x8Slot') aString)
}

method initialize Display8x8Slot aString {
	morph = (newMorph this)
	setHandler morph this
	setGrabRule morph 'defer'
	setTransparentTouch morph true
	display = (newArray 64 false)
	inset = 0
	stride = 15
	ledWidth = 9
	ledHeight = 12
	if (notNil aString) { setContents this aString }
	redraw this
	return this
}

method contents Display8x8Slot {
    s = ''
    for i 64 {
        if (at display i) {
            s = (join s '1')
        } else {
            s = (join s '0')
        }
    }
    return s
}

method setContents Display8x8Slot aString {
    if (isNil aString) { return }

    if (not (isClass aString 'String')) {
        aString = (toString aString)
    }

    if ((byteCount aString) != 64) { return }

    for i 64 {
        ch = (at aString i)
        atPut display i ('1' == ch)
    }
    redraw this
}

method redraw Display8x8Slot {
	scale = (blockScale)
	bgColor = (transparent)
	offColor = (colorHSV 235 0.62 0.40)
	onColor = (colorHSV 0 1.0 0.9)

	xStride = stride
	yStride = (stride - 1)

	bmWidth = (ledWidth + ((8 - 1) * xStride))
	bmHeight = (ledHeight + ((8 - 1) * yStride))

	bm = (costumeData morph)
	if (isNil bm) {
		bm = (newBitmap (bmWidth * scale) (bmHeight * scale) bgColor)
	}

	for y 8 {
		for x 8 {
			index = ((8 * (y - 1)) + x)
			c = offColor
			if (at display index) { c = onColor }
			left = ((x - 1) * xStride)
			top = ((y - 1) * yStride)
			fillRect bm c (left * scale) (top * scale) (ledWidth * scale) (ledHeight * scale)
		}
	}
	setCostume morph bm
}

// events

method handEnter Display8x8Slot aHand { setCursor 'crosshair' }
method handLeave Display8x8Slot aHand { setCursor 'default' }

method handDownOn Display8x8Slot aHand {
	// Start drawing on the LED display.

	setCursor 'crosshair'
	focusOn aHand this
	paintMode = true
	index = (ledIndex this aHand)
	if (notNil index) {
		paintMode = (not (at display index))
	}
	handMoveFocus this aHand
	return true
}

method handMoveFocus Display8x8Slot aHand {
	// Draw on the LED display as the mouse moves.

	index = (ledIndex this aHand)
	if (notNil index) {
		atPut display index paintMode
		redraw this
		raise morph 'inputChanged' this
		// xxx update underlying block
	}
	return true
}

method ledIndex Display8x8Slot aHand {
	// Return the 1-based LED index under the hand, or nil.

	scale = (blockScale)
	xStride = stride
	yStride = (stride - 1)

	normalizedX = (((x aHand) - (left morph)) / scale)
	normalizedY = (((y aHand) - (top morph)) / scale)

	if (or (normalizedX < 0) (normalizedY < 0)) { return nil }
	if ((normalizedX % xStride) >= ledWidth) { return nil }
	if ((normalizedY % yStride) >= ledHeight) { return nil }

	col = (truncate (normalizedX / xStride))
	row = (truncate (normalizedY / yStride))

	if (or (col > 7) (row > 7)) { return nil }

	return (((row * 8) + col) + 1)
}
