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

    atom.views.getView( @gutter ).onkeydown = (event) =>
      event.stopPropagation()
      if event.metaKey
        defaultHandling = no
        switch event.key
          when 'x' then document.execCommand 'cut'
          when 'c' then document.execCommand 'copy'
          when 'v' then document.execCommand 'paste'
          when 'z' then document.execCommand 'undo'
          else defaultHandling = yes
        event.preventDefault() if not defaultHandling

    @subscription = @editor.getBuffer().onWillSave =>
      @serializeToText()

  createItemAtLine: (lineNum) ->
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
      item.onfocus = =>
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

  @getCommentLiteral: (editor) ->
    scope = editor.getRootScopeDescriptor()
    atom.config.get( 'editor.commentStart', { scope } )

  @getLitdocTag: (editor) ->
    "#{@getCommentLiteral( editor )}.litdoc"

  @getLitdocTagRegex: (editor) ->
    new XRegExp( "^ \\n?
                  ^ #{ XRegExp.escape( @getLitdocTag( editor ) ) } \s* $", 'xgm' )

  getLineRegex: ->
    new XRegExp( "^ #{ XRegExp.escape( Litdoc.getCommentLiteral( @editor ) ) }
                  Line\\ (?<lineNum> \\d+ ):\\ (?<content> .+$ )", 'xgm' )

  foldRange: (range) ->
    selectedRange = @editor.getSelectedBufferRange()
    @editor.setSelectedBufferRange range
    @editor.foldSelectedLines()
    @editor.setSelectedBufferRange selectedRange

  @detect: (editor, callback) ->
    editor.getBuffer().backwardsScan @getLitdocTagRegex( editor ), =>
      callback()




  deserializeFromText: ->
    litdocTag = Litdoc.getLitdocTag( @editor )
    textBuffer = @editor.getBuffer()

    textBuffer.backwardsScan Litdoc.getLitdocTagRegex( @editor ), (match) =>
      range = match.range
      range.end = textBuffer.getEndPosition()

      @foldRange [ [ range.start.row + 1, litdocTag.length ], range.end ]

      litdocLines = textBuffer.getTextInRange range

      lineRegex = @getLineRegex()
      while ( matches = lineRegex.exec( litdocLines ) )
        lineNum = matches[1] - 1
        content = matches[2]
        if item = @createItemAtLine lineNum
          item.innerHTML = content

  serializeToText: ->
    textBuffer = @editor.getBuffer()

    markers = @editor.findMarkers litdoc: true

    return if markers.length == 0

    textBuffer.backwardsScan Litdoc.getLitdocTagRegex( @editor ), (match) ->
      range = match.range
      range.end = textBuffer.getEndPosition()
      textBuffer.setTextInRange range, '', undo: 'skip'

    textBuffer.append "\n" + Litdoc.getLitdocTag( @editor ), undo: 'skip'
    foldStart = textBuffer.getEndPosition()

    for marker in markers
      lineNum = marker.getBufferRange().start.row
      lineNumPlus1 = ( Number.parseInt( lineNum ) + 1 ).toString()

      textBuffer.append "\n" + Litdoc.getCommentLiteral( @editor ) +
                        "Line #{lineNumPlus1}: " + marker.getProperties().item.innerHTML,
                        undo: 'skip'

    textBuffer.append "\n", undo: 'skip'

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
# Line 36: Prevent key events originating in litdoc gutter from reaching editor (otherwise it receives its copy of keystrokes)
# Line 40: Default native key bindings cause cut, copy, paste and undo events to arrive in the active editor. &nbsp;Prevent default and provide our own handling of such events (that will only make it into the gutter)
# Line 48: Hook up to the buffer save and serialze and append our comments to the end of the file
# Line 51: Function to create an item in the litdoc gutter
# Line 61: Create marker. &nbsp;Invalidate marker whenever somebody deletes the line the marker is inside of
# Line 64: <i>native-key-bindings</i> allows keys like cmd-left etc. to work in the contenteditable
# Line 66: Manipulate z-index so that comment on N+1 line takes precedence over line N
# Line 70: If user clicks on text rather than on the unused gutter area, we want to stop our own mouseup handler from firing
# Line 74: Remove is-focused class to hide cursor in the active editor
# Line 76: Destroy marker if it has no content
# Line 83: Passthrough functions to gutter
# Line 94: <span style="color: hsl(100,30%,50%)">Helper functions</span>
# Line 96: Get buffer row of the line clicked in the gutter
# Line 102: Helper to get the comment token for the grammar of the edited file
# Line 106: Special comment tag used to signify litdoc block
# Line 109: Regex to scan edited file for litdoc tag block
# Line 110: <li> optional empty line before the tag</li>
# Line 111: <li> the tag itself followed by optional space</li>
# Line 113: Regex to scan for serialized comments inside a litdoc block
# Line 115: <li>comment token right at the start of the line</li>
# Line 116: <li>the word <i>Line </i>followed by a number</li>
# Line 117: <li>arbitrary content</li>
# Line 119: Fold the lines in the range. &nbsp;This allows folding arbitrary blocks, such as the whole litdoc block
# Line 123: Detect litdoc tag in the editor, and call the callback function in that case
# Line 128: <span style="color: hsl(100,30%,50%)">Loading and saving</span>
# Line 130: Load litdoc comments from the edited file
# Line 134: Find and read litdoc block at the end of the file
# Line 138: Fold litdoc block content except the first line
# Line 142: Deserialize comments for each line in the block
# Line 149: Save litdoc comments in the edited file
# Line 152: Find all litdoc markers
# Line 156: Find and remove old litdoc block
# Line 159: Use setTextInRange rathen than delete, since delete doesn't allow to skip undo
# Line 161: Insert litdoc tag
# Line 164: Serialize litdoc comments
# Line 166: Buffer line numbers are zero-based, add +1 for a human-readable number
# Line 168: Append the line in the format<div><i>Line xxx: comment</i>&nbsp; to the end of the file</div>
# Line 172: Insert newline at the end of file (or atom will insert it itself, with undo)
# Line 174: Fold inserted lines and restore selection
# Line 176: Unimplemented
# Line 178: Deallocate litdoc in current editor
# Line 180: Remove all markers
# Line 181: Remove gutter
# Line 182: Remove editor.onWillSave subscription
