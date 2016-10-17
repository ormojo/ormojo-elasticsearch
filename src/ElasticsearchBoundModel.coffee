{ BoundModel, createStandardInstanceClassForBoundModel } = require 'ormojo'
esTypeMap = require './esTypeMap'

class ElasticsearchBoundModel extends BoundModel
	constructor: (model, backend) ->
		super(model, backend)
		if typeof(@name) isnt 'string' then throw new Error('ElasticsearchBoundModel: Cannot bind unnamed model.')
		if typeof(@spec.backend.type) isnt 'string' then throw new Error('ElasticsearchBoundModel: must specify an elasticsearch type')
		@esIndex = @spec.backend.index or @name
		@esType = @spec.backend.type
		@instanceClass = createStandardInstanceClassForBoundModel(@)

	createInstance: (dataValues) ->
		new @instanceClass(@, dataValues)

	getIndex: -> @esIndex
	getDefaultType: -> @esType

	# Generate Elasticsearch mapping properties
	generateMappingProps: ->
		props = {}
		for k, field of @getFields() when k isnt 'id'
			mapping = field.spec.elasticsearch?.mapping or {}
			mapping.type = esTypeMap(field.spec.type)
			props[field.getBackendFieldName()] = mapping
		props



module.exports = ElasticsearchBoundModel
