parentMixin =

  _removeChild: (children, id) ->

    children.remove (item) ->

      item.id == id

  _createAddWire: (parentId, children) ->

    parent_id: parentId
    method: 'PUT'
    handler: _.compose(partial(@_addChild, children), curry2(_.result)('new'))

  _createRemoveWire: (id, children) ->

    method: 'DELETE'
    id: id
    handler: partial @_removeChild, children, id

  _createAssignmentWire: (parentId, children, property, getFn) ->

    parent_id: parentId
    properties: [property]
    method: 'POST'
    handler: _.compose(curry2(getFn)(partial(@_addChild, children)), curry2(_.result)('id'))

  _subscribeToAssignmentChanges: (children, property) ->

    removeChild = partial @_removeChild, children

    _.each children(), (observables) ->

      observables.readonly[property].subscribe partial(removeChild, observables.id)
    subscribeToNewChild = (changes) => 

      _.each changes, (change) =>

        if change.status == 'added'

          observables = children()[change.index]
          observables.readonly[property].subscribe partial(removeChild, observables.id)
    children.subscribe subscribeToNewChild, null, 'arrayChange'

  _createChildWires: (children, observables) ->

    [@_createUpdateWire(observables.js, _.extend({}, observables.writable, observables.readonly)), 
    @_createRemoveWire(observables.id, children)]

  _adjustChildWires: (socket, children, wires, changes) ->

    _.each changes, (change) =>

      if change.status == 'added'

        observables = children()[change.index]
        newWires = @_createChildWires children, observables
        socket.registerWires newWires
        wires = wires.concat newWires
      else if change.status == 'deleted'

        socket.unregisterWires _.where(wires, {id: change.value.id})