# Represents an index in Elasticsearch.
export class ESIndex
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
			mappings[type] = boundModel.generateMapping()
		mappings

	generateAnalysis: ->
		analysis = { }
		for type, boundModel of @types
			props = boundModel.generateAnalysisProps()
			if props.analyzer then analysis.analyzer = Object.assign(analysis.analyzer or {}, props.analyzer)
			if props.filter then analysis.filter = Object.assign(analysis.filter or {}, props.filter)
		analysis

# Represents the collection of indices associated with a backend.
export class ESIndices
	constructor: (@backend) ->
		@indices = {}

	addBoundModel: (bm) ->
		indexName = bm.getIndex()
		if not @indices[indexName]
			@indices[indexName] = new ESIndex(@backend, indexName)
		@indices[indexName].addBoundModel(bm)

	getIndices: ->
		@indices
