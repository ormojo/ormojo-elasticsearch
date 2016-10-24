{ BoundModel, createStandardInstanceClassForBoundModel } = require 'ormojo'
ESField = require './ESField'
esTypeMap = require './esTypeMap'

class ESBoundModel extends BoundModel
	constructor: (model, backend, bindingOptions) ->
		super
		if typeof(@name) isnt 'string' then throw new Error('ESBoundModel: Cannot bind unnamed model.')
		if typeof(@spec.type) isnt 'string' then throw new Error("ESBoundModel: bound model derived from Model named #{model.name} must specify an elasticsearch type")
		@esIndex = (@spec.index or @name).toLowerCase()
		@esType = (@spec.type).toLowerCase()
		@instanceClass = createStandardInstanceClassForBoundModel(@)

	_deriveFields: ->
		@fields = {}
		for k,fieldSpec of @spec.fields
			f = new ESField().fromSpec(k, fieldSpec)
			@fields[k] = f
		if not @fields['id']
			throw new Error("ESBoundModel: bound model derived from Model named `#{@model.name}` must have an id field.")
		undefined

	getIndex: -> @esIndex
	getDefaultType: -> @esType

	bindChildModel: (model, bindingOptions) ->
		bindingOptions = bindingOptions or {}
		# Child index must be the same as this index.
		bindingOptions.index = @getIndex()
		bindingOptions.parentBoundModel = @
		@backend.bindChildModel(model, bindingOptions)

	_findById: (id) ->
		@backend.api.findInstanceById(@, @backend._deserialize, @backend, id)

	_findByIds: (ids) ->
		@backend.api.findByIds(@getIndex(), @getDefaultType(), ids)
		.then (rst) =>
			# Comprehense over returned entities.
			for entity in (rst?.docs or [])
				if not (entity?.found) then undefined else @backend._deserialize(@, entity)

	findById: (id) ->
		if Array.isArray(id) then @_findByIds(id) else @_findById(id)

	# Generate Elasticsearch mapping properties
	generateMapping: ->
		m = {}
		m.properties = props = {}

		for k, field of @getFields() when k isnt 'id'
			mapping = field.spec.elasticsearch?.mapping or {}
			# Merge missing keys from typemap defaults
			for mk,mv of esTypeMap(field.spec.type)
				if not (mk of mapping) then mapping[mk] = mv

			props[field.getBackendFieldName()] = mapping

		m

	# Generate Elasticsearch analysis properties
	generateAnalysisProps: ->
		props = {}
		if @spec.analyzer then props.analyzer = @spec.analyzer
		if @spec.filter then props.filter = @spec.filter
		props

module.exports = ESBoundModel
