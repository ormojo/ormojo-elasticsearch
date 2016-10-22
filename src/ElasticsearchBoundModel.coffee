{ BoundModel, createStandardInstanceClassForBoundModel } = require 'ormojo'
esTypeMap = require './esTypeMap'

_idGetter = -> @_id
_idSetter = (k,v) ->
	if @_id? then throw new Error('ElasticsearchInstance: cannot reassign `id` - create a new Instance instead')
	@_id = v


class ElasticsearchBoundModel extends BoundModel
	constructor: (model, backend) ->
		super(model, backend)
		if typeof(@name) isnt 'string' then throw new Error('ElasticsearchBoundModel: Cannot bind unnamed model.')
		if typeof(@spec.backend.type) isnt 'string' then throw new Error('ElasticsearchBoundModel: must specify an elasticsearch type')
		@esIndex = (@spec.backend.index or @name).toLowerCase()
		@esType = (@spec.backend.type).toLowerCase()
		@instanceClass = createStandardInstanceClassForBoundModel(@)

		# Custom getter and setter for id.
		@getters['id'] = _idGetter
		@setters['id'] = _idSetter

	createInstance: (dataValues) ->
		new @instanceClass(@, dataValues)

	getIndex: -> @esIndex
	getDefaultType: -> @esType

	# Generate Elasticsearch mapping properties
	generateMappingProps: ->
		props = {}
		for k, field of @getFields() when k isnt 'id'
			mapping = field.spec.elasticsearch?.mapping or {}
			# Merge missing keys from typemap defaults
			for mk,mv of esTypeMap(field.spec.type)
				if not (mk of mapping) then mapping[mk] = mv

			props[field.getBackendFieldName()] = mapping
		props

	# Generate Elasticsearch analysis properties
	generateAnalysisProps: ->
		props = {}
		if @spec.backend.analyzer then props.analyzer = @spec.backend.analyzer
		if @spec.backend.filter then props.filter = @spec.backend.filter
		props



module.exports = ElasticsearchBoundModel
