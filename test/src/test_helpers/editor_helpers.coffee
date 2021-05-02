helpers = Trix.TestHelpers

helpers.extend
  insertString: (string) ->
    getComposition().insertString(string)
    render()

  insertText: (text) ->
    getComposition().insertText(text)
    render()

  insertDocument: (document) ->
    getComposition().insertDocument(document)
    render()

  replaceDocument: (document) ->
    getComposition().setDocument(document)
    render()

render = ->
  getEditorController().render()
