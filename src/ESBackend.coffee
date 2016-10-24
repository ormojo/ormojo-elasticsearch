{ Backend, BoundModel, Util, createStandardInstanceClassForBoundModel } = require 'ormojo'
ESCursor = require './ESCursor'
ESBoundModel = require './ESBoundModel'
{ ESIndex, ESIndices } = require './ESIndex'
ESMigration = require './ESMigration'
ESResultSet = require './ESResultSet'

class ESBackend extends Backend
	constructor: (@es) ->
		@indices = new ESIndices(@)

	bindModel: (model, bindingOptions) ->
		# Basic checks
		bm = new ESBoundModel(model, @, bindingOptions)
		@indices.addBoundModel(bm)
		bm

	getMigration: ->
		new ESMigration(@corpus, @)

	################################ CREATION
	createRawInstance: (boundModel, dataValues) ->
		boundModel._createInstance(dataValues)

	_deserialize: (boundModel, esData, instance) ->
		if instance
			Object.assign(instance.dataValues, esData._source)
		else
			instance = boundModel._createInstance(esData._source)
		instance._id = esData._id
		instance._index = esData._index
		instance._version = esData._version
		instance._type = esData._type
		instance._score = esData._score
		instance

	################################ FINDING
	_findById: (boundModel, id) ->
		rq = { id, index: boundModel.getIndex(), type: boundModel.getDefaultType(), ignore: [404] }
		@corpus.log.trace "es.get >", rq
		@corpus.Promise.resolve( @es.get(rq) )
		.then (rst) =>
			@corpus.log.trace "es.get <", rst
			if not rst.found then undefined else @_deserialize(boundModel, rst)

	_findByIds: (boundModel, ids) ->
		rq = { index: boundModel.getIndex(), body: { ids } }
		@corpus.log.trace "es.mget >", rq
		@corpus.Promise.resolve( @es.mget(rq) )
		.then (rst) =>
			@corpus.log.trace "es.mget <", rst
			# Comprehense over returned entities.
			for entity in (rst?.docs or [])
				if not (entity?.found) then undefined else @_deserialize(boundModel, entity)

	findById: (boundModel, id) ->
		if Array.isArray(id) then @_findByIds(boundModel, id) else @_findById(boundModel, id)

	find: (boundModel, options) ->
		rq = {
			index: boundModel.getIndex()
			body: options.elasticsearch_query
			size: 1
			version: true
		}
		@corpus.log.trace "es.search >", rq
		@corpus.Promise.resolve( @es.search(rq) )
		.then (rst) =>
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
		searchParams.body = if options.elasticsearch_query then options.elasticsearch_query else options.cursor?.query
		# Determine search boundaries
		if options.cursor
			searchParams.from = options.cursor.offset
			searchParams.size = options.cursor.limit
		else
			if options.offset then searchParams.from = options.offset
			if options.limit then searchParams.size = options.limit

		@corpus.log.trace "es.search >", searchParams
		@corpus.Promise.resolve( @es.search(searchParams) )
		.then (rst) =>
			@corpus.log.trace "es.search <", rst
			if (not rst) or (not rst.hits)
				new ESResultSet([], 0, 0, null, 0)
			else
				data = (@_deserialize(boundModel, x) for x in rst.hits.hits)
				new ESResultSet(data, rst.hits.total, searchParams.from, searchParams.body, rst.hits.max_score)

	################################ SAVING
	_saveNewInstance: (instance, boundModel) ->
		rq = {
			index: instance._index or boundModel.getIndex()
			type: instance._type or boundModel.getDefaultType()
			body: instance.dataValues
		}
		if (parent = instance._parent) then rq.parent = parent
		# Allow creation with specified id.
		if (id = instance.id) then rq.id = id

		@corpus.log.trace "es.create >", rq
		@corpus.Promise.resolve( @es.create(rq) )
		.then (rst) =>
			@corpus.log.trace "es.create <", rst
			instance._id = rst._id
			@_deserialize(boundModel, rst, instance)
			delete instance.isNewRecord
			instance

	_saveOldInstance: (instance, boundModel) ->
		# Determine data changes to be saved - early out if no changes
		delta = Util.getDelta(instance)
		if not delta then return @corpus.Promise.resolve(instance)
		# Punt to ES
		rq = {
			index: instance._index or boundModel.getIndex()
			type: instance._type or boundModel.getDefaultType()
			id: instance.id
			body: { doc: delta }
		}
		if (parent = instance._parent) then rq.parent = parent
		@corpus.log.trace "es.update >", rq
		@corpus.Promise.resolve( @es.update(rq) )
		.then (rst) =>
			@corpus.log.trace "es.update <", rst
			@_deserialize(boundModel, rst, instance)
			instance

	save: (instance, boundModel) ->
		if instance.isNewRecord
			@_saveNewInstance(instance, boundModel)
		else
			@_saveOldInstance(instance, boundModel)

	destroy: (instance, boundModel) ->
		rq = {
			index: instance._index or boundModel.getIndex()
			type: instance._type or boundModel.getDefaultType()
			id: instance.id
		}
		if (parent = instance._parent) then rq.parent = parent
		@corpus.log.trace "es.delete >", rq
		@corpus.Promise.resolve( @es.delete(rq) )
		.then (rst) =>
			@corpus.log.trace "es.delete <", rst
			if rst?.found then true else false

module.exports = ESBackend
