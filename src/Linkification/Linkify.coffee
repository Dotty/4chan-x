Linkify =
  init: ->
    return if g.VIEW is 'catalog' or !Conf['Linkify']

    # gruber revised + magnet support
    # http://rodneyrehm.de/t/url-regex.html
    @catchAll = /\b([a-z][\w-]+:(\/{1,3}|[a-z0-9%]|\?(dn|x[lts]|as|kt|mt|tr)=)|www\d{0,3}\.|[a-z0-9.\-]+\.[a-z]{2,4}\/)([^\s()<>]+|\(([^\s()<>]+|(\([^\s()<>]+\)))*\))+(\(([^\s()<>]+|(\([^\s()<>]+\)))*\)|[^\s`!()\[\]{};:'".,<>?«»“”‘’])/g

    Post::callbacks.push
      name: 'Linkify'
      cb:   @node

  node: ->
    return if @isClone or !links = @info.comment.match Linkify.catchAll
    walker = d.createTreeWalker @nodes.comment, 4
    range  = d.createRange()
    for link in links
      boundaries = Linkify.find link, walker
      # break unless boundaries
      anchor = Linkify.createLink link
      if Linkify.surround anchor, range, boundaries
        if (parent = anchor.parentNode).href is anchor.href
          # Replace already-linkified links,
          # f.e.: https://boards.4chan.org/b/%
          $.replace parent, anchor
        Linkify.cleanLink anchor, link if Conf['Clean Links']
        walker.currentNode = anchor.lastChild
      else
        walker.currentNode = boundaries.endNode
    range.detach()

  find: (link, walker) ->
    # Walk through the nodes until we find the entire link.
    text = ''
    while node = walker.nextNode()
      text += node.data
      break if text.indexOf(link) > -1
    # return unless node
    startNode = endNode = node

    # Walk backwards to find the startNode.
    text = node.data
    until (index = text.indexOf link) > -1
      startNode = walker.previousNode()
      text = "#{startNode.data}#{text}"

    return {
      startNode, endNode
      startOffset: index
      endOffset: endNode.length - (text.length - index - link.length)
    }

  createLink: (link) ->
    unless /^[a-z][\w-]+:/.test link
      link = "http://#{link}"
    $.el 'a',
      href: link
      className: 'linkified'
      target: '_blank'

  surround: (anchor, range, boundaries) ->
    {startOffset, endOffset, startNode, endNode} = boundaries
    range.setStart startNode, startOffset
    range.setEnd endNode, endOffset
    try
      range.surroundContents anchor
      true
    catch
      <% if (type === 'crx') { %>
      # Chrome bug: crbug.com/275848
      return true if anchor.parentNode
      <% } %>
      # Attempt to handle cases such as:
      # [spoiler]www.[/spoiler]example.com #
      # www.example[spoiler].com[/spoiler] #
      return false if boundaries.areRelocated
      Linkify.relocate boundaries
      Linkify.surround anchor, range, boundaries

  relocate: (boundaries) ->
    # What do you mean, "silly"?
    boundaries.areRelocated = true

    if boundaries.startOffset is 0
      parentNode = boundaries.startNode
      until parentNode.previousSibling
        {parentNode} = parentNode
      parent = parentNode.parentNode
      boundaries.startNode   = parent
      boundaries.startOffset = [parent.childNodes...].indexOf parentNode

    if boundaries.endOffset is boundaries.endNode.length
      parentNode = boundaries.endNode
      until parentNode.nextSibling
        {parentNode} = parentNode
      parent = parentNode.parentNode
      boundaries.endNode   = parent
      boundaries.endOffset = [parent.childNodes...].indexOf(parentNode) + 1

  cleanLink: (anchor, link) ->
    {length} = link
    for node in $$ 's, .prettyprint', anchor
      $.replace node, [node.childNodes...] if length > node.textContent.length
    return