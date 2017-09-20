Litdoc = require './litdoc'

{CompositeDisposable} = require 'atom'

module.exports =
  subscriptions: null
  editors: []
  litdocs: []
  popup: 'always'
  config:
    popup:
      title: 'Automatically open litdoc'
      description: 'You can choose to open litdoc only when previous comments detected, ' +
                   'to keep it always open, or to open manually in each tab'
      type: 'string'
      enum: [ 'always', 'when litdoc detected', 'manually' ]
      default: 'when litdoc detected'
  #config:
  #  location:
  #    title: 'Location of litdoc block'
  #    type: 'string'
  #    default: 'end of file'
  #    enum: ['end of file']
  #  wrap:
  #    title: 'Wrap litdoc block at preferred line length'
  #    type: 'boolean'
  #    default: 'false'
  #    description: 'If false, litdoc inserts one line per comment.  ' +
  #                 'Note that this doesn't affect appearance.'

  activate: ->
    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.commands.add 'atom-workspace', 'litdoc:toggle':  => @toggle()
    @subscriptions.add atom.commands.add 'atom-workspace', 'litdoc:disable': => @disable()

    @subscriptions.add atom.config.observe 'litdoc.popup', (popup) =>
      @popup = popup

    atom.workspace.observeTextEditors (editor) =>
      switch @popup
        when 'always'    then @register editor, true
        when 'manually'  then @register editor, false
        when 'when litdoc detected' then Litdoc.detect editor, =>
          @register editor, true

  deactivate: ->
    @litdocs = @editors = []
    @subscriptions.dispose()

  register: (editor, visible ) ->
    index = @editors.indexOf editor

    if index >= 0
      @litdocs[ index ].toggle()
    else
      @editors.push editor
      @litdocs.push new Litdoc( editor, visible )

  toggle: ->
    editor = atom.workspace.getActiveTextEditor()
    @register editor, true

  disable: ->
    editor = atom.workspace.getActiveTextEditor()
    index = @editors.indexOf editor

    if index >= 0
      @litdocs[ index ].destroy()
      delete @litdocs[ index ]
      delete @editors[ index ]

# .litdoc
# Line 7: Maintain the list of editors for which litdoc gutters were created
# Line 46: Deactivate the package, destroying all existing instances&nbsp;
# Line 50: Create litdoc instance in the editor, or toggle the visibility of the existing instance
# Line 59: Toggle litdoc in active editor
# Line 64: Find and destroy litdoc in active editor
