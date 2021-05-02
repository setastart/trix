Trix.config.textAttributes =
  bold:
    tagName: "strong"
    inheritable: true
    parser: (element) ->
      style = window.getComputedStyle(element)
      style["fontWeight"] is "bold" or style["fontWeight"] >= 600
  italic:
    tagName: "em"
    inheritable: true
    parser: (element) ->
      style = window.getComputedStyle(element)
      style["fontStyle"] is "italic"
  small:
    tagName: "small"
    inheritable: true
    parser: (element) ->
      style = window.getComputedStyle(element)
      style["fontSize"] is "smaller"
  href:
    groupTagName: "a"
    parser: (element) ->
      matchingSelector = "a"
      if link = Trix.findClosestElementFromNode(element, {matchingSelector})
        link.getAttribute("href")
  strike:
    tagName: "del"
    inheritable: true
  frozen:
    style: { "backgroundColor": "highlight" }
