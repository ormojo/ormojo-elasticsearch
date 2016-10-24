ESBoundModel = require './ESBoundModel'
{ Instance } = require 'ormojo'

class ESChildModel extends ESBoundModel
	constructor: ->
		super
		@parentBoundModel = @spec.parentBoundModel
		if not (@parentBoundModel instanceof ESBoundModel)
			throw new Error("ESChildModel(`#{@name}`): parentBoundModel must be an ESBoundModel.")

	findById: (parent, id) ->
		if parent instanceof Instance
			parentId = parent.id
		else if (typeof(parent) is 'string' or typeof(parent) is 'number')
			parentId = parent.toString()
		else
			throw new Error("ESChildModel(`#{@name}`): must provide parent object or ID as first argument")

		if Array.isArray(id)
			throw new Error("ESChildModel(`#{@name}`): get by array not supported with child models")

		@backend.api.findInstanceById(@, @backend._deserialize, @backend, id, parentId)

	create: (parent, data) ->
		if parent instanceof Instance
			parentId = parent.id
		else if (typeof(parent) is 'string' or typeof(parent) is 'number')
			parentId = parent.toString()
		else
			throw new Error("ESChildModel(`#{@name}`): must provide parent object or ID as first argument")

		instance = @_createInstance()
		instance.isNewRecord = true
		instance.__applyDefaults()
		instance._parent = parentId
		if data isnt undefined
			instance.set(data)
			instance.save()
		else
			instance

	generateMapping: ->
		m = super
		m['_parent'] = { type: @parentBoundModel.getDefaultType() }
		m['_routing'] = { required: true }
		m

module.exports = ESChildModel
