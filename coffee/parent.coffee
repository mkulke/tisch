parentMixin =

  _createAddWire: (parentId, children) ->

    parent_id: parentId
    method: 'PUT'
    handler: partial @_addChild, children    
  _createRemoveWire: (id, children) ->

    method: 'DELETE'
    id: id
    handler: =>

      children.remove (item) ->

        item.id == id 
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