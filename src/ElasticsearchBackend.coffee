{ Backend, BoundModel, Util, createStandardInstanceClassForBoundModel } = require 'ormojo'
ElasticsearchPagination = require './ElasticsearchPagination'
ElasticsearchBoundModel = require './ElasticsearchBoundModel'
{ ElasticsearchIndex, ElasticsearchIndices } = require './ElasticsearchIndex'
ElasticsearchMigration = require './ElasticsearchMigration'

class ElasticsearchBackend extends Backend
	constructor: (@es) ->
		@boundModels = {}
		@indices = new ElasticsearchIndices(@)

	bindModel: (model) ->
		# Basic checks
		bm = new ElasticsearchBoundModel(model, @)
		if @boundModels[bm.name] then throw new Error("ElasticsearchBackend: Cannot bind two models with the same name (`#{bm.name}`)")
		@boundModels[bm.name] = bm
		@indices.addBoundModel(bm)
		bm

	getMigration: ->
		new ElasticsearchMigration(@corpus, @)

	################################ CREATION
	createRawInstance: (boundModel, dataValues) ->
		boundModel.createInstance(dataValues)

	create: (boundModel, initialData) ->
		instance = @createRawInstance(boundModel)
		instance.isNewRecord = true
		instance.__applyDefaults()
		if initialData isnt undefined
			instance.set(initialData)
			@save(instance, boundModel)
		else
			instance

	_deserialize: (boundModel, esData, instance) ->
		if instance
			Object.assign(instance.dataValues, esData._source)
		else
			instance = @createRawInstance(boundModel, Object.assign({ id: esData._id}, esData._source))
		instance._version = esData._version
		instance._type = esData._type
		instance._score = esData._score
		instance

	################################ FINDING
	_findById: (boundModel, id) ->
		@corpus.Promise.resolve(
			@es.get { id, index: boundModel.getIndex(), type: '_all', ignore: [404] }
		).then (rst) =>
			@corpus.log.trace "es.get <", rst
			if not rst.found then undefined else @_deserialize(boundModel, rst)

	_findByIds: (boundModel, ids) ->
		@corpus.Promise.resolve(
			@es.mget { index: boundModel.getIndex(), body: { ids } }
		).then (rst) =>
			@corpus.log.trace "es.mget <", rst
			# Comprehense over returned entities.
			for entity in (rst?.docs or [])
				if not (entity?.found) then undefined else @_deserialize(boundModel, entity)

	findById: (boundModel, id) ->
		if Array.isArray(id) then @_findByIds(boundModel, id) else @_findById(boundModel, id)

	find: (boundModel, options) ->
		@corpus.Promise.resolve(
			@es.search({
				index: boundModel.getIndex()
				body: options.elasticsearch_query
				size: 1
				version: true
			})
		).then (rst) =>
			@corpus.log.trace "es.search <", rst
			if (not rst) or (not rst.hits) or (rst.hits.total is 0)
				undefined
			else
				@_deserialize(boundModel, rst.hits.hits[0])

	findAll: (boundModel, options) ->
		searchParams = {
			index: boundModel.getIndex()
			version: true
		}
		# Determine query
		searchParams.body = if options.elasticsearch_query then options.elasticsearch_query else options.pagination?.query
		# Determine search boundaries
		if options.pagination
			searchParams.from = options.pagination.offset
			searchParams.size = options.pagination.limit
		else
			if options.offset then searchParams.from = options.offset
			if options.limit then searchParams.size = options.limit

		@corpus.log.trace "es.search >", searchParams
		@corpus.Promise.resolve(@es.search(searchParams))
		.then (rst) =>
			@corpus.log.trace "es.search <", rst
			if (not rst) or (not rst.hits)
				{ data: [] }
			else
				data = (@_deserialize(boundModel, x) for x in rst.hits.hits)
				pagination = if (searchParams.from or 0) + data.length < rst.hits.total
					(new ElasticsearchPagination(searchParams.body)).setFromOffset((searchParams.from or 0) + data.length, (searchParams.size or data.length), rst.hits.total)

				{
					data
					metadata: {
						total: rst.hits.total
						max_score: rst.hits.max_score
					}
					pagination
				}

	################################ SAVING
	_saveNewInstance: (instance, boundModel) ->
		@corpus.Promise.resolve(
			@es.create({
				index: boundModel.getIndex()
				type: instance._type or boundModel.getDefaultType()
				body: instance.dataValues
			})
		).then (rst) =>
			@corpus.log.trace "es.create <", rst
			instance.id = rst._id
			@_deserialize(boundModel, rst, instance)
			delete instance.isNewRecord
			instance

	_saveOldInstance: (instance, boundModel) ->
		# Determine data changes to be saved - early out if no changes
		delta = Util.getDelta(instance)
		if not delta then return @corpus.Promise.resolve(instance)
		# Punt to ES
		@corpus.Promise.resolve(
			@es.update({
				index: boundModel.getIndex()
				type: instance._type or boundModel.getDefaultType()
				id: instance.id
				body: { doc: delta }
			})
		).then (rst) =>
			@corpus.log.trace "es.update <", rst
			@_deserialize(boundModel, rst, instance)
			instance

	save: (instance, boundModel) ->
		if instance.isNewRecord
			@_saveNewInstance(instance, boundModel)
		else
			@_saveOldInstance(instance, boundModel)

	destroy: (instance, boundModel) ->
		@corpus.Promise.resolve(
			@es.delete({
				index: boundModel.getIndex()
				type: instance._type or boundModel.getDefaultType()
				id: instance.id
			})
		).then (rst) =>
			@corpus.log.trace "es.delete <", rst
			undefined

module.exports = ElasticsearchBackend
