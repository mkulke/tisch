sortableMixin = 

  _addChild: (array, data) ->
    
    observables = @_createObservables data.new
    observables.writable.priority.subscribe partial(@_sortByPriority, array)
    array.push observables

  _sortByPriority: (array) ->

    array.sort (a, b) ->

      a.writable.priority() - b.writable.priority()

  # TODO: unit-test
  _calculatePriority: (objects, index) =>

    if index == 0 then prevPrio = 0
    else prevPrio = objects[index - 1].writable.priority()

    last = objects.length - 1
    if index == last 

      Math.ceil objects[index - 1].writable.priority() + 1
    else

      nextPrio = objects[index + 1].writable.priority()
      (nextPrio - prevPrio) / 2 + prevPrio

  _setupSortable: (children) ->

    # set global options for jquery ui sortable
    ko.bindingHandlers.sortable.options = 

      tolerance: 'pointer'
      delay: 150
      cursor: 'move'
      containment: 'ul#well'
      handle: '.header'

    ko.bindingHandlers.sortable.afterMove = (arg, event, ui) =>

      priority = @_calculatePriority children, arg.targetIndex
      arg.item.writable.priority priority