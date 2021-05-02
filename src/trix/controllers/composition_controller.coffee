#= require trix/views/document_view

{handleEvent, innerElementIsActive, defer}  = Trix


class Trix.CompositionController extends Trix.BasicObject
  constructor: (@element, @composition) ->
    @documentView = new Trix.DocumentView @composition.document, {@element}

    handleEvent "focus", onElement: @element, withCallback: @didFocus
    handleEvent "blur", onElement: @element, withCallback: @didBlur
    handleEvent "click", onElement: @element, matchingSelector: "a[contenteditable=false]", preventDefault: true

  didFocus: (event) =>
    perform = =>
      unless @focused
        @focused = true
        @delegate?.compositionControllerDidFocus?()

    @blurPromise?.then(perform) ? perform()

  didBlur: (event) =>
    @blurPromise = new Promise (resolve) =>
      defer =>
        unless innerElementIsActive(@element)
          @focused = null
          @delegate?.compositionControllerDidBlur?()
        @blurPromise = null
        resolve()

  getSerializableElement: ->
    @element

  render: ->
    unless @revision is @composition.revision
      @documentView.setDocument(@composition.document)
      @documentView.render()
      @revision = @composition.revision

    if not @documentView.isSynced()
      @delegate?.compositionControllerWillSyncDocumentView?()
      @documentView.sync()
      @delegate?.compositionControllerDidSyncDocumentView?()

    @delegate?.compositionControllerDidRender?()

  rerenderViewForObject: (object) ->
    @invalidateViewForObject(object)
    @render()

  invalidateViewForObject: (object) ->
    @documentView.invalidateViewForObject(object)

  isViewCachingEnabled: ->
    @documentView.isViewCachingEnabled()

  enableViewCaching: ->
    @documentView.enableViewCaching()

  disableViewCaching: ->
    @documentView.disableViewCaching()

  refreshViewCache: ->
    @documentView.garbageCollectCachedViews()
