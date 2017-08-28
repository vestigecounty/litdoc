Litdoc = require './litdoc'

{CompositeDisposable} = require 'atom'

module.exports =
  subscriptions: null
  editors: []
  litdocs: []
  #config:
  #  location:
  #    title: 'Location of litdoc block'
  #    type: 'string'
  #    default: 'end of file'
  #    enum: ['end of file']
  #  wrap:
  #    title: 'Soft-wrap'
  #    type: 'boolean'
  #    default: 'false'
  #    description: "Soft-wrap the litdoc block to preferred line length"

  activate: ->
    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.commands.add 'atom-workspace', 'litdoc:toggle':  => @toggle()
    @subscriptions.add atom.commands.add 'atom-workspace', 'litdoc:disable': => @disable()

    atom.workspace.observeTextEditors (editor) =>
      @register editor, false

  deactivate: ->
    @subscriptions.dispose()

  register: (editor, visible = true ) ->
    index = @editors.indexOf editor

    if index >= 0
      @litdocs[ index ].toggle()
    else
      @editors.push editor
      @litdocs.push new Litdoc( editor, visible )

  toggle: ->
    editor = atom.workspace.getActiveTextEditor()
    @register editor

  disable: ->
    # @deactivate()
    editor = atom.workspace.getActiveTextEditor()
    index = @editors.indexOf editor

    if index >= 0
      @litdocs[ index ].destroy()
      delete @litdocs[ index ]
      delete @editors[ index ]


# .litdoc
# Line 7: Maintain the list of editors for which litdoc gutters were created
# Line 26: Automatically register on activation
# Line 27: <i>todo</i>: this is expensive, search for litdoc tag first and only activate then
# Line 33: See if litdoc instance has been created for this editor already
# Line 41: Toggle litdoc in active editor
# Line 45: Find and destroy litdoc instance in active editor
