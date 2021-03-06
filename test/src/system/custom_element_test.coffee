{after, assert, clickToolbarButton, defer, moveCursor, pasteContent, test, testIf, testGroup, triggerEvent, typeCharacters, typeInToolbarDialog} = Trix.TestHelpers

testGroup "Custom element API", template: "editor_empty", ->
  test "element triggers trix-initialize on first connect", (done) ->
    container = document.getElementById("trix-container")
    container.innerHTML = ""

    initializeEventCount = 0
    element = document.createElement("trix-editor")
    element.addEventListener "trix-initialize", -> initializeEventCount++

    container.appendChild(element)
    requestAnimationFrame ->
      container.removeChild(element)
      requestAnimationFrame ->
        container.appendChild(element)
        after 60, ->
          assert.equal initializeEventCount, 1
          done()

  test "element triggers trix-change events when the document changes", (done) ->
    element = getEditorElement()
    eventCount = 0
    element.addEventListener "trix-change", (event) -> eventCount++

    typeCharacters "a", ->
      assert.equal eventCount, 1
      moveCursor "left", ->
        assert.equal eventCount, 1
        typeCharacters "bcd", ->
          assert.equal eventCount, 4
          clickToolbarButton action: "undo", ->
            assert.equal eventCount, 5
            done()

  test "element triggers trix-change event after toggling attributes", (done) ->
    element = getEditorElement()
    editor = element.editor

    afterChangeEvent = (edit, callback) ->
      element.addEventListener "trix-change", handler = (event) ->
        element.removeEventListener("trix-change", handler)
        callback(event)
      edit()

    typeCharacters "hello", ->
      edit = -> editor.activateAttribute("quote")
      afterChangeEvent edit, ->
        assert.ok editor.attributeIsActive("quote")

        edit = -> editor.deactivateAttribute("quote")
        afterChangeEvent edit, ->
          assert.notOk editor.attributeIsActive("quote")

          editor.setSelectedRange([0, 5])
          edit = -> editor.activateAttribute("bold")
          afterChangeEvent edit, ->
            assert.ok editor.attributeIsActive("bold")

            edit = -> editor.deactivateAttribute("bold")
            afterChangeEvent edit, ->
              assert.notOk editor.attributeIsActive("bold")
              done()

  test "disabled attributes aren't considered active", (done) ->
    {editor} = getEditorElement()
    editor.activateAttribute("heading1")
    assert.notOk editor.attributeIsActive("code")
    assert.notOk editor.attributeIsActive("quote")
    done()

  test "element triggers trix-selection-change events when the location range changes", (done) ->
    element = getEditorElement()
    eventCount = 0
    element.addEventListener "trix-selection-change", (event) -> eventCount++

    typeCharacters "a", ->
      assert.equal eventCount, 1
      moveCursor "left", ->
        assert.equal eventCount, 2
        done()

  test "only triggers trix-selection-change events on the active element", (done) ->
    elementA = getEditorElement()
    elementB = document.createElement("trix-editor")
    elementA.parentNode.insertBefore(elementB, elementA.nextSibling)

    elementB.addEventListener "trix-initialize", ->
      elementA.editor.insertString("a")
      elementB.editor.insertString("b")
      rangy.getSelection().removeAllRanges()

      eventCountA = 0
      eventCountB = 0
      elementA.addEventListener "trix-selection-change", (event) -> eventCountA++
      elementB.addEventListener "trix-selection-change", (event) -> eventCountB++

      elementA.editor.setSelectedRange(0)
      assert.equal eventCountA, 1
      assert.equal eventCountB, 0

      elementB.editor.setSelectedRange(0)
      assert.equal eventCountA, 1
      assert.equal eventCountB, 1

      elementA.editor.setSelectedRange(1)
      assert.equal eventCountA, 2
      assert.equal eventCountB, 1
      done()

  test "element triggers toolbar dialog events", (done) ->
    element = getEditorElement()
    events = []

    element.addEventListener "trix-toolbar-dialog-show", (event) ->
      events.push(event.type)

    element.addEventListener "trix-toolbar-dialog-hide", (event) ->
      events.push(event.type)

    clickToolbarButton action: "link", ->
      typeInToolbarDialog "http://example.com", attribute: "href", ->
        defer ->
          assert.deepEqual events, ["trix-toolbar-dialog-show", "trix-toolbar-dialog-hide"]
          done()

  test "element triggers before-paste event with paste data", (expectDocument) ->
    element = getEditorElement()
    eventCount = 0
    paste = null

    element.addEventListener "trix-before-paste", (event) ->
      eventCount++
      {paste} = event

    typeCharacters "", ->
      pasteContent "text/html", "<strong>hello</strong>", ->
        assert.equal eventCount, 1
        assert.equal paste.type, "text/html"
        assert.equal paste.html, "<strong>hello</strong>"
        expectDocument("hello\n")

  test "element triggers before-paste event with mutable paste data", (expectDocument) ->
    element = getEditorElement()
    eventCount = 0
    paste = null

    element.addEventListener "trix-before-paste", (event) ->
      eventCount++
      {paste} = event
      paste.html = "<strong>greetings</strong>"

    typeCharacters "", ->
      pasteContent "text/html", "<strong>hello</strong>", ->
        assert.equal eventCount, 1
        assert.equal paste.type, "text/html"
        expectDocument("greetings\n")

  test "element triggers paste event with position range", (done) ->
    element = getEditorElement()
    eventCount = 0
    paste = null

    element.addEventListener "trix-paste", (event) ->
      eventCount++
      {paste} = event

    typeCharacters "", ->
      pasteContent "text/html", "<strong>hello</strong>", ->
        assert.equal eventCount, 1
        assert.equal paste.type, "text/html"
        assert.ok Trix.rangesAreEqual([0, 5], paste.range)
        done()

  test "element triggers attribute change events", (done) ->
    element = getEditorElement()
    eventCount = 0
    attributes = null

    element.addEventListener "trix-attributes-change", (event) ->
      eventCount++
      {attributes} = event

    typeCharacters "", ->
      assert.equal eventCount, 0
      clickToolbarButton attribute: "bold", ->
        assert.equal eventCount, 1
        assert.deepEqual { bold: true }, attributes
        done()

  test "element triggers action change events", (done) ->
    element = getEditorElement()
    eventCount = 0
    actions = null

    element.addEventListener "trix-actions-change", (event) ->
      eventCount++
      {actions} = event

    typeCharacters "", ->
      assert.equal eventCount, 0
      clickToolbarButton attribute: "bullet", ->
        assert.equal eventCount, 1
        assert.equal actions.decreaseNestingLevel, true
        assert.equal actions.increaseNestingLevel, false
        done()

  test "element triggers custom focus and blur events", (done) ->
    element = getEditorElement()

    focusEventCount = 0
    blurEventCount = 0
    element.addEventListener "trix-focus", -> focusEventCount++
    element.addEventListener "trix-blur", -> blurEventCount++

    triggerEvent(element, "blur")
    defer ->
      assert.equal blurEventCount, 1
      assert.equal focusEventCount, 0

      triggerEvent(element, "focus")
      defer ->
        assert.equal blurEventCount, 1
        assert.equal focusEventCount, 1
        done()

  # Selenium doesn't seem to focus windows properly in some browsers (FF 47 on OS X)
  # so skip this test when unfocused pending a better solution.
  testIf document.hasFocus(), "element triggers custom focus event when autofocusing", (done) ->
    element = document.createElement("trix-editor")
    element.setAttribute("autofocus", "")

    focusEventCount = 0
    element.addEventListener "trix-focus", -> focusEventCount++

    container = document.getElementById("trix-container")
    container.innerHTML = ""
    container.appendChild(element)

    element.addEventListener "trix-initialize", ->
      assert.equal focusEventCount, 1
      done()

  test "element serializes HTML after attribute changes", (done) ->
    element = getEditorElement()
    serializedHTML = element.value

    typeCharacters "a", ->
      assert.notEqual serializedHTML, element.value
      serializedHTML = element.value

      clickToolbarButton attribute: "quote", ->
        assert.notEqual serializedHTML, element.value
        serializedHTML = element.value

        clickToolbarButton attribute: "quote", ->
          assert.notEqual serializedHTML, element.value
          done()

  test "editor resets to its original value on form reset", (expectDocument) ->
    element = getEditorElement()
    form = element.inputElement.form

    typeCharacters "hello", ->
      form.reset()
      expectDocument("\n")

  test "editor resets to last-set value on form reset", (expectDocument) ->
    element = getEditorElement()
    form = element.inputElement.form

    element.value = "hi"
    typeCharacters "hello", ->
      form.reset()
      expectDocument("hi\n")

  test "editor respects preventDefault on form reset", (expectDocument) ->
    element = getEditorElement()
    form = element.inputElement.form
    preventDefault = (event) -> event.preventDefault()

    typeCharacters "hello", ->
      form.addEventListener("reset", preventDefault, false)
      form.reset()
      form.removeEventListener("reset", preventDefault, false)
      expectDocument("hello\n")

testGroup "<label> support", template: "editor_with_labels", ->
  test "associates all label elements", (done) ->
    labels = [document.getElementById("label-1"), document.getElementById("label-3")]
    assert.deepEqual getEditorElement().labels, labels
    done()

  test "focuses when <label> clicked", (done) ->
    document.getElementById("label-1").click()
    assert.equal getEditorElement(), document.activeElement
    done()

  test "focuses when <label> descendant clicked", (done) ->
    document.getElementById("label-1").querySelector("span").click()
    assert.equal getEditorElement(), document.activeElement
    done()

  test "does not focus when <label> controls another element", (done) ->
    label = document.getElementById("label-2")
    assert.notEqual getEditorElement(), label.control
    label.click()
    assert.notEqual getEditorElement(), document.activeElement
    done()

testGroup "form property references its <form>", template: "editors_with_forms", container: "div", ->
  test "accesses its ancestor form", (done) ->
    form = document.getElementById("ancestor-form")
    editor = document.getElementById("editor-with-ancestor-form")
    assert.equal editor.form, form
    done()

  test "transitively accesses its related <input> element's <form>", (done) ->
    form = document.getElementById("input-form")
    editor = document.getElementById("editor-with-input-form")
    assert.equal editor.form, form
    done()

  test "returns null when there is no associated <form>", (done) ->
    editor = document.getElementById("editor-with-no-form")
    assert.equal editor.form, null
    done()
