

# Represents an index in Elasticsearch.
class ElasticsearchIndex
	constructor: (@backend, @name) ->
		@boundModels = []
		@types = {}

	addBoundModel: (bm) ->
		@types[bm.getDefaultType()] = bm
		@boundModels.push(bm)

	_deleteIndex: ->
		@backend.es.indices.delete({index: @name})

	################################# MAPPING
	generateMappings: ->
		mappings = {}
		for type, boundModel of @types
			mappings[type] = {
				properties: boundModel.generateMappingProps()
			}
		mappings

# Represents the collection of indices associated with a backend.
class ElasticsearchIndices
	constructor: (@backend) ->
		@indices = {}

	addBoundModel: (bm) ->
		indexName = bm.getIndex()
		if not @indices[indexName]
			@indices[indexName] = new ElasticsearchIndex(@backend, indexName)
		@indices[indexName].addBoundModel(bm)

	getIndices: ->
		@indices



module.exports = { ElasticsearchIndex, ElasticsearchIndices }
