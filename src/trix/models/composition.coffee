#= require trix/models/document
#= require trix/models/line_break_insertion

{normalizeRange, rangeIsCollapsed, objectsAreEqual, arrayStartsWith, getAllAttributeNames, getBlockConfig, getTextConfig, extend} = Trix

class Trix.Composition extends Trix.BasicObject
  constructor: ->
    @document = new Trix.Document
    @currentAttributes = {}
    @revision = 0

  setDocument: (document) ->
    unless document.isEqualTo(@document)
      @document = document
      @revision++
      @delegate?.compositionDidChangeDocument?(document)

  # Snapshots

  getSnapshot: ->
    document: @document
    selectedRange: @getSelectedRange()

  loadSnapshot: ({document, selectedRange}) ->
    @delegate?.compositionWillLoadSnapshot?()
    @setDocument(document ? new Trix.Document)
    @setSelection(selectedRange ? [0, 0])
    @delegate?.compositionDidLoadSnapshot?()

  # Responder protocol

  insertText: (text, {updatePosition} = updatePosition: true) ->
    selectedRange = @getSelectedRange()
    @setDocument(@document.insertTextAtRange(text, selectedRange))

    startPosition = selectedRange[0]
    endPosition = startPosition + text.getLength()

    @setSelection(endPosition) if updatePosition
    @notifyDelegateOfInsertionAtRange([startPosition, endPosition])

  insertBlock: (block = new Trix.Block) ->
    document = new Trix.Document [block]
    @insertDocument(document)

  insertDocument: (document = new Trix.Document) ->
    selectedRange = @getSelectedRange()
    @setDocument(@document.insertDocumentAtRange(document, selectedRange))

    startPosition = selectedRange[0]
    endPosition = startPosition + document.getLength()

    @setSelection(endPosition)
    @notifyDelegateOfInsertionAtRange([startPosition, endPosition])

  insertString: (string, options) ->
    attributes = @getCurrentTextAttributes()
    text = Trix.Text.textForStringWithAttributes(string, attributes)
    @insertText(text, options)

  insertBlockBreak: ->
    selectedRange = @getSelectedRange()
    @setDocument(@document.insertBlockBreakAtRange(selectedRange))

    startPosition = selectedRange[0]
    endPosition = startPosition + 1

    @setSelection(endPosition)
    @notifyDelegateOfInsertionAtRange([startPosition, endPosition])

  insertLineBreak: ->
    insertion = new Trix.LineBreakInsertion this

    if insertion.shouldDecreaseListLevel()
      @decreaseListLevel()
      @setSelection(insertion.startPosition)
    else if insertion.shouldPrependListItem()
      document = new Trix.Document [insertion.block.copyWithoutText()]
      @insertDocument(document)
    else if insertion.shouldInsertBlockBreak()
      @insertBlockBreak()
    else if insertion.shouldRemoveLastBlockAttribute()
      @removeLastBlockAttribute()
    else if insertion.shouldBreakFormattedBlock()
      @breakFormattedBlock(insertion)
    else
      @insertString("\n")

  insertHTML: (html) ->
    document = Trix.Document.fromHTML(html)
    selectedRange = @getSelectedRange()

    @setDocument(@document.mergeDocumentAtRange(document, selectedRange))

    startPosition = selectedRange[0]
    endPosition = startPosition + document.getLength() - 1

    @setSelection(endPosition)
    @notifyDelegateOfInsertionAtRange([startPosition, endPosition])

  replaceHTML: (html) ->
    document = Trix.Document.fromHTML(html).copyUsingObjectsFromDocument(@document)
    locationRange = @getLocationRange(strict: false)
    selectedRange = @document.rangeFromLocationRange(locationRange)
    @setDocument(document)
    @setSelection(selectedRange)

  shouldManageDeletingInDirection: (direction) ->
    locationRange = @getLocationRange()
    if rangeIsCollapsed(locationRange)
      return true if direction is "backward" and locationRange[0].offset is 0
      return true if @shouldManageMovingCursorInDirection(direction)
    else
      return true if locationRange[0].index isnt locationRange[1].index
    false

  deleteInDirection: (direction, {length} = {}) ->
    locationRange = @getLocationRange()
    range = @getSelectedRange()
    selectionIsCollapsed = rangeIsCollapsed(range)

    if selectionIsCollapsed
      deletingIntoPreviousBlock = direction is "backward" and locationRange[0].offset is 0
    else
      selectionSpansBlocks = locationRange[0].index isnt locationRange[1].index

    if deletingIntoPreviousBlock
      if @canDecreaseBlockAttributeLevel()
        block = @getBlock()

        if block.isListItem()
          @decreaseListLevel()
        else
          @decreaseBlockAttributeLevel()

        @setSelection(range[0])
        return false if block.isEmpty()

    if selectionIsCollapsed
      range = @getExpandedRangeInDirection(direction, {length})

    @setDocument(@document.removeTextAtRange(range))
    @setSelection(range[0])
    false if deletingIntoPreviousBlock or selectionSpansBlocks

  moveTextFromRange: (range) ->
    [position] = @getSelectedRange()
    @setDocument(@document.moveTextFromRangeToPosition(range, position))
    @setSelection(position)

  removeLastBlockAttribute: ->
    [startPosition, endPosition] = @getSelectedRange()
    block = @document.getBlockAtPosition(endPosition)
    @removeCurrentAttribute(block.getLastAttribute())
    @setSelection(startPosition)

  placeholder = " "

  insertPlaceholder: ->
    @placeholderPosition = @getPosition()
    @insertString(placeholder)

  selectPlaceholder: ->
    if @placeholderPosition?
      @setSelectedRange([@placeholderPosition, @placeholderPosition + placeholder.length])
      @getSelectedRange()

  forgetPlaceholder: ->
    @placeholderPosition = null

  # Current attributes

  hasCurrentAttribute: (attributeName) ->
    value = @currentAttributes[attributeName]
    value? and value isnt false

  toggleCurrentAttribute: (attributeName) ->
    if value = not @currentAttributes[attributeName]
      @setCurrentAttribute(attributeName, value)
    else
      @removeCurrentAttribute(attributeName)

  canSetCurrentAttribute: (attributeName) ->
    if getBlockConfig(attributeName)
      @canSetCurrentBlockAttribute(attributeName)
    else
      @canSetCurrentTextAttribute(attributeName)

  canSetCurrentTextAttribute: (attributeName) ->
    return unless document = @getSelectedDocument()
    true

  canSetCurrentBlockAttribute: (attributeName) ->
    return unless block = @getBlock()
    not block.isTerminalBlock()

  setCurrentAttribute: (attributeName, value) ->
    if getBlockConfig(attributeName)
      @setBlockAttribute(attributeName, value)
    else
      @setTextAttribute(attributeName, value)
      @currentAttributes[attributeName] = value
      @notifyDelegateOfCurrentAttributesChange()

  setTextAttribute: (attributeName, value) ->
    return unless selectedRange = @getSelectedRange()
    [startPosition, endPosition] = selectedRange
    if startPosition is endPosition
      if attributeName is "href"
        text = Trix.Text.textForStringWithAttributes(value, href: value)
        @insertText(text)
    else
      @setDocument(@document.addAttributeAtRange(attributeName, value, selectedRange))

  setBlockAttribute: (attributeName, value) ->
    return unless selectedRange = @getSelectedRange()
    if @canSetCurrentAttribute(attributeName)
      block = @getBlock()
      @setDocument(@document.applyBlockAttributeAtRange(attributeName, value, selectedRange))
      @setSelection(selectedRange)

  removeCurrentAttribute: (attributeName) ->
    if getBlockConfig(attributeName)
      @removeBlockAttribute(attributeName)
      @updateCurrentAttributes()
    else
      @removeTextAttribute(attributeName)
      delete @currentAttributes[attributeName]
      @notifyDelegateOfCurrentAttributesChange()

  removeTextAttribute: (attributeName) ->
    return unless selectedRange = @getSelectedRange()
    @setDocument(@document.removeAttributeAtRange(attributeName, selectedRange))

  removeBlockAttribute: (attributeName) ->
    return unless selectedRange = @getSelectedRange()
    @setDocument(@document.removeAttributeAtRange(attributeName, selectedRange))

  canDecreaseNestingLevel: ->
    @getBlock()?.getNestingLevel() > 0

  canIncreaseNestingLevel: ->
    return unless block = @getBlock()
    if getBlockConfig(block.getLastNestableAttribute())?.listAttribute
      if previousBlock = @getPreviousBlock()
        arrayStartsWith(previousBlock.getListItemAttributes(), block.getListItemAttributes())
    else
      block.getNestingLevel() > 0

  decreaseNestingLevel: ->
    return unless block = @getBlock()
    @setDocument(@document.replaceBlock(block, block.decreaseNestingLevel()))

  increaseNestingLevel: ->
    return unless block = @getBlock()
    @setDocument(@document.replaceBlock(block, block.increaseNestingLevel()))

  canDecreaseBlockAttributeLevel: ->
    @getBlock()?.getAttributeLevel() > 0

  decreaseBlockAttributeLevel: ->
    if attribute = @getBlock()?.getLastAttribute()
      @removeCurrentAttribute(attribute)

  decreaseListLevel: ->
    [startPosition] = @getSelectedRange()
    {index} = @document.locationFromPosition(startPosition)
    endIndex = index
    attributeLevel = @getBlock().getAttributeLevel()

    while block = @document.getBlockAtIndex(endIndex + 1)
      break unless block.isListItem() and block.getAttributeLevel() > attributeLevel
      endIndex++

    startPosition = @document.positionFromLocation(index: index, offset: 0)
    endPosition = @document.positionFromLocation(index: endIndex, offset: 0)
    @setDocument(@document.removeLastListAttributeAtRange([startPosition, endPosition]))

  updateCurrentAttributes: ->
    if selectedRange = @getSelectedRange(ignoreLock: true)
      currentAttributes = @document.getCommonAttributesAtRange(selectedRange)

      for attributeName in getAllAttributeNames()
        unless currentAttributes[attributeName]
          unless @canSetCurrentAttribute(attributeName)
            currentAttributes[attributeName] = false

      unless objectsAreEqual(currentAttributes, @currentAttributes)
        @currentAttributes = currentAttributes
        @notifyDelegateOfCurrentAttributesChange()

  getCurrentAttributes: ->
    extend.call({}, @currentAttributes)

  getCurrentTextAttributes: ->
    attributes = {}
    for key, value of @currentAttributes when value isnt false
      attributes[key] = value if getTextConfig(key)
    attributes

  # Selection freezing

  freezeSelection: ->
    @setCurrentAttribute("frozen", true)

  thawSelection: ->
    @removeCurrentAttribute("frozen")

  hasFrozenSelection: ->
    @hasCurrentAttribute("frozen")

  # Selection

  @proxyMethod "getSelectionManager().getPointRange"
  @proxyMethod "getSelectionManager().setLocationRangeFromPointRange"
  @proxyMethod "getSelectionManager().createLocationRangeFromDOMRange"
  @proxyMethod "getSelectionManager().locationIsCursorTarget"
  @proxyMethod "getSelectionManager().selectionIsExpanded"
  @proxyMethod "delegate?.getSelectionManager"

  setSelection: (selectedRange) ->
    locationRange = @document.locationRangeFromRange(selectedRange)
    @delegate?.compositionDidRequestChangingSelectionToLocationRange(locationRange)

  getSelectedRange: ->
    if locationRange = @getLocationRange()
      @document.rangeFromLocationRange(locationRange)

  setSelectedRange: (selectedRange) ->
    locationRange = @document.locationRangeFromRange(selectedRange)
    @getSelectionManager().setLocationRange(locationRange)

  getPosition: ->
    if locationRange = @getLocationRange()
      @document.positionFromLocation(locationRange[0])

  getLocationRange: (options) ->
    @targetLocationRange ?
      @getSelectionManager().getLocationRange(options) ?
      normalizeRange(index: 0, offset: 0)

  withTargetLocationRange: (locationRange, fn) ->
    @targetLocationRange = locationRange
    try
      result = fn()
    finally
      @targetLocationRange = null
    result

  withTargetRange: (range, fn) ->
    locationRange = @document.locationRangeFromRange(range)
    @withTargetLocationRange(locationRange, fn)

  withTargetDOMRange: (domRange, fn) ->
    locationRange = @createLocationRangeFromDOMRange(domRange, strict: false)
    @withTargetLocationRange(locationRange, fn)

  getExpandedRangeInDirection: (direction, {length} = {}) ->
    [startPosition, endPosition] = @getSelectedRange()
    if direction is "backward"
      if length
        startPosition -= length
      else
        startPosition = @translateUTF16PositionFromOffset(startPosition, -1)
    else
      if length
        endPosition += length
      else
        endPosition = @translateUTF16PositionFromOffset(endPosition, 1)
    normalizeRange([startPosition, endPosition])

  shouldManageMovingCursorInDirection: (direction) ->
    range = @getExpandedRangeInDirection(direction)

  moveCursorInDirection: (direction) ->
    selectedRange = @getSelectedRange()
    range = @getExpandedRangeInDirection(direction)

    if direction is "backward"
      @setSelectedRange(range[0])
    else
      @setSelectedRange(range[1])

  expandSelectionInDirection: (direction, {length} = {}) ->
    range = @getExpandedRangeInDirection(direction, {length})
    @setSelectedRange(range)

  expandSelectionForEditing: ->
    if @hasCurrentAttribute("href")
      @expandSelectionAroundCommonAttribute("href")

  expandSelectionAroundCommonAttribute: (attributeName) ->
    position = @getPosition()
    range = @document.getRangeOfCommonAttributeAtPosition(attributeName, position)
    @setSelectedRange(range)

  selectionIsInCursorTarget: ->
    @positionIsCursorTarget(@getPosition())

  positionIsCursorTarget: (position) ->
    if location = @document.locationFromPosition(position)
      @locationIsCursorTarget(location)

  positionIsBlockBreak: (position) ->
    @document.getPieceAtPosition(position)?.isBlockBreak()

  getSelectedDocument: ->
    if selectedRange = @getSelectedRange()
      @document.getDocumentAtRange(selectedRange)

  # Private

  breakFormattedBlock: (insertion) ->
    {document, block} = insertion
    position = insertion.startPosition
    range = [position - 1, position]

    if block.getBlockBreakPosition() is insertion.startLocation.offset
      if block.breaksOnReturn() and insertion.nextCharacter is "\n"
        position += 1
      else
        document = document.removeTextAtRange(range)
      range = [position, position]
    else if insertion.nextCharacter is "\n"
      if insertion.previousCharacter is "\n"
        range = [position - 1, position + 1]
      else
        range = [position, position + 1]
        position += 1
    else if insertion.startLocation.offset - 1 isnt 0
      position += 1

    newDocument = new Trix.Document [block.removeLastAttribute().copyWithoutText()]
    @setDocument(document.insertDocumentAtRange(newDocument, range))
    @setSelection(position)

  getPreviousBlock: ->
    if locationRange = @getLocationRange()
      {index} = locationRange[0]
      @document.getBlockAtIndex(index - 1) if index > 0

  getBlock: ->
    if locationRange = @getLocationRange()
      @document.getBlockAtIndex(locationRange[0].index)

  notifyDelegateOfCurrentAttributesChange: ->
    @delegate?.compositionDidChangeCurrentAttributes?(@currentAttributes)

  notifyDelegateOfInsertionAtRange: (range) ->
    @delegate?.compositionDidPerformInsertionAtRange?(range)

  translateUTF16PositionFromOffset: (position, offset) ->
    utf16string = @document.toUTF16String()
    utf16position = utf16string.offsetFromUCS2Offset(position)
    utf16string.offsetToUCS2Offset(utf16position + offset)
