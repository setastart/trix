#= require trix/views/text_view

{makeElement, getBlockConfig} = Trix
{css} = Trix.config

class Trix.BlockView extends Trix.ObjectView
  constructor: ->
    super
    @block = @object
    @attributes = @block.getAttributes()

  createNodes: ->
    comment = document.createComment("block")
    nodes = [comment]
    if @block.isEmpty()
      nodes.push(makeElement("br"))
    else
      textConfig = getBlockConfig(@block.getLastAttribute())?.text
      textView = @findOrCreateCachedChildView(Trix.TextView, @block.text, {textConfig})
      nodes.push(textView.getNodes()...)
      nodes.push(makeElement("br")) if @shouldAddExtraNewlineElement()

    if @attributes.length
      nodes
    else
      {tagName} = Trix.config.blockAttributes.default
      attributes = dir: "rtl" if @block.isRTL()

      element = makeElement({tagName, attributes})
      element.appendChild(node) for node in nodes
      [element]

  createContainerElement: (depth) ->
    attributeName = @attributes[depth]

    {tagName} = getBlockConfig(attributeName)
    attributes = dir: "rtl" if depth is 0 and @block.isRTL()

    makeElement({tagName, "", attributes})

  # A single <br> at the end of a block element has no visual representation
  # so add an extra one.
  shouldAddExtraNewlineElement:->
    /\n\n$/.test(@block.toString())
