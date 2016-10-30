import ESBoundModel from './ESBoundModel'
import { Instance } from 'ormojo'

export default class ESChildModel extends ESBoundModel
	constructor: ->
		super
		@parentBoundModel = @spec.parentBoundModel
		if not (@parentBoundModel instanceof ESBoundModel)
			throw new Error("ESChildModel(`#{@name}`): parentBoundModel must be an ESBoundModel.")

	_checkParent: (parent) ->
		if parent instanceof Instance
			return parent.id
		else if (typeof(parent) is 'string' or typeof(parent) is 'number')
			return parent.toString()
		else
			throw new Error("ESChildModel(`#{@name}`): must provide parent object or ID as first argument")

	findById: (parent, id) ->
		parentId = @_checkParent(parent)

		if Array.isArray(id)
			throw new Error("ESChildModel(`#{@name}`): get by array not supported with child models")

		@backend.api.findInstanceById(@, @backend._deserialize, @backend, id, parentId)

	destroyById: (parent, id) ->
		parentId = @_checkParent(parent)
		@backend.api.destroy(@getIndex(), @getDefaultType(), id, parentId)

	create: (parent, data) ->
		parentId = @_checkParent(parent)

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
