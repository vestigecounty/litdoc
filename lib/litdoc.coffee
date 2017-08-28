XRegExp = require 'xregexp'

class Litdoc
  gutter: null
  editor: null
  item: null
  subscription: null


  constructor: (editor, visible = true ) ->
    @editor = editor

    @gutter = @editor.addGutter( name: "litdoc", priority: 50, visible: visible )

    @deserializeFromText()

    atom.views.getView( @gutter ).onmousedown = (event) =>
      clickedBufferRow = @clickedBufferRow( event )
      @item = @createItemAtLine clickedBufferRow

    atom.views.getView( @gutter ).onmouseup = =>
      return if not @item?

      jumpToEndOfText = (contenteditable) ->
        range = document.createRange()
        range.selectNodeContents( contenteditable )
        range.collapse( false )
        selection = window.getSelection()
        selection.removeAllRanges()
        selection.addRange( range )

      @item.focus()
      jumpToEndOfText( @item )
      @item = null

    @subscription = @editor.getBuffer().onWillSave =>
      @serializeToText()

  createItemAtLine: ( lineNum, interactive = true ) ->
    item = null

    markers = @editor.findMarkers startBufferRow: lineNum, endBufferRow: lineNum, litdoc: true

    if markers.length > 0
      item = markers[0].item
    else
      range = [ [ lineNum, 0 ], [ lineNum, Infinity ] ]

      marker = @editor.markBufferRange( range, invalidate: 'surround', litdoc: true )

      item = document.createElement( "div" )
      item.className = 'native-key-bindings litdoc'
      item.setAttribute( "contentEditable", true )
      item.zIndex = -lineNum

      item.addEventListener 'mouseup', (event) ->
        event.stopPropagation()

      @gutter.decorateMarker( marker, { item } )
      marker.setProperties item: item

      item.onblur = =>
        atom.views.getView( @editor ).classList.add 'is-focused'
        if !item.innerHTML
          marker.destroy()

    if interactive
      atom.views.getView( @editor ).classList.remove 'is-focused'

    return item

  isVisible: ->
    @gutter.isVisible()
  show: ->
    @gutter.show()
  hide: ->
    @gutter.hide()
  toggle: ->
    if @isVisible() then @hide() else @show()




  clickedBufferRow: (event) ->
    textEditorElement = atom.views.getView( @editor ).component
    clickedScreenRow = textEditorElement.screenPositionForMouseEvent( event ).row
    clickedBufferRow = @editor.bufferRowForScreenRow( clickedScreenRow )
    clickedBufferRow

  getCommentLiteral: ->
    scope = @editor.getRootScopeDescriptor()
    atom.config.get( 'editor.commentStart', { scope } )

  getLitdocTag: ->
    "#{@getCommentLiteral()}.litdoc"

  getLitdocTagRegex: ->
    new XRegExp( "^ \\n?
                  ^ #{ XRegExp.escape( @getLitdocTag() ) } \s* $", 'xgm' )

  getLineRegex: ->
    new XRegExp( "^ #{ XRegExp.escape( @getCommentLiteral() ) }
                  Line\\ (?<lineNum> \\d+ ):\\ (?<content> .+$ )", 'xgm' )

  foldRange: (range) ->
    selectedRange = @editor.getSelectedBufferRange()
    @editor.setSelectedBufferRange range
    @editor.foldSelectedLines()
    @editor.setSelectedBufferRange selectedRange






  deserializeFromText: ->
    litdocTag = @getLitdocTag()
    textBuffer = @editor.getBuffer()

    textBuffer.backwardsScan @getLitdocTagRegex(), (match) =>
      range = match.range
      range.end = textBuffer.getEndPosition()

      @foldRange [ [ range.start.row + 1, litdocTag.length ], range.end ]

      litdocLines = textBuffer.getTextInRange range

      lineRegex = @getLineRegex()
      while ( matches = lineRegex.exec( litdocLines ) )
        lineNum = matches[1] - 1
        content = matches[2]
        if item = @createItemAtLine lineNum, false
          item.innerHTML = content

  serializeToText: ->
    textBuffer = @editor.getBuffer()

    markers = @editor.findMarkers litdoc: true

    return if markers.length == 0

    textBuffer.backwardsScan @getLitdocTagRegex(), (match) ->
      range = match.range
      range.end = textBuffer.getEndPosition()
      textBuffer.delete range

    textBuffer.append "\n" + @getLitdocTag()
    foldStart = textBuffer.getEndPosition()

    for marker in markers
      lineNum = marker.getBufferRange().start.row
      lineNumPlus1 = ( Number.parseInt( lineNum ) + 1 ).toString()

      textBuffer.append "\n" + @getCommentLiteral() +
                        "Line #{lineNumPlus1}: " + marker.getProperties().item.innerHTML,
                        undo: 'skip'

    @foldRange [ foldStart, textBuffer.getEndPosition() ]

  serialize: ->

  destroy: ->
    markers = @editor.findMarkers litdoc: true
    marker.destroy() for marker in markers
    @gutter.destroy()
    @subscription.dispose()


module.exports = Litdoc

# .litdoc
# Line 8: <span style="color: hsl(100,30%,50%)">Setup</span>
# Line 13: Create litdoc gutter
# Line 15: Load litdoc comments in currently edited file
# Line 17: On gutter click, create a new litdoc item on the clicked line
# Line 21: On mouse up, first check that the comment is not empty (if it is, discard the comment).<div>If the click was on the gutter and not on the text of the comment, make the comment focused and jump to the end of the text (which is logical, since the click is only possible to the right of the comment)</div>
# Line 36: Hook up to the buffer save and serialze and append our comments to the end of the file
# Line 39: Function to create an item in the litdoc gutter
# Line 49: Create marker. &nbsp;Invalidate marker whenever somebody deletes the line the marker is inside of
# Line 52: <i>native-key-bindings</i> allows keys like cmd-left etc. to work in the contenteditable
# Line 54: Manipulate z-index so that comment on N+1 line takes precedence over line N
# Line 56: If user clicks on text rather than on the unused gutter area, we want to stop our own mouseup handler from firing
# Line 67: Remove is-focused class to hide cursor in the active editor
# Line 72: Passthrough functions to gutter
# Line 82: <span style="color: hsl(100,30%,50%)">Helper functions</span>
# Line 84: Get buffer row of the line clicked in the gutter
# Line 90: Helper to get the comment token for the grammar of the edited file
# Line 94: Special comment tag used to signify litdoc block
# Line 97: Regex to scan edited file for litdoc tag block
# Line 98: <li> optional empty line before the tag</li>
# Line 99: <li> the tag itself followed by optional space</li>
# Line 101: Regex to scan for serialized comments inside a litdoc block
# Line 103: <li>comment token right at the start of the line</li>
# Line 104: <li>the word <i>Line </i>followed by a number</li>
# Line 105: <li>arbitrary content</li>
# Line 107: Fold the lines in the range. &nbsp;This allows folding arbitrary blocks, such as the whole litdoc block
# Line 114: <span style="color: hsl(100,30%,50%)">Loading and saving</span>
# Line 116: Load litdoc comments from the edited file
# Line 120: Find and read litdoc block at the end of the file
# Line 124: Fold litdoc block content except the first line
# Line 128: Deserialize comments for each line in the block
# Line 135: Save litdoc comments in the edited file
# Line 138: Find all litdoc markers
# Line 142: Find and remove old litdoc block
# Line 147: Insert litdoc tag
# Line 150: Serialize litdoc comments
# Line 152: Buffer line numbers are zero-based, add +1 for a human-readable number
# Line 154: Append the line in the format<div><i>Line xxx: comment</i>&nbsp; to the end of the file</div>
# Line 158: Fold inserted lines and restore selection
# Line 160: Unimplemented
# Line 163: Remove all markers
# Line 165: Remove gutter
# Line 166: Remove editor.onWillSave subscription
