{ Backend, BoundModel, Util, createStandardInstanceClassForBoundModel } = require 'ormojo'
ESCursor = require './ESCursor'
ESBoundModel = require './ESBoundModel'
{ ESIndex, ESIndices } = require './ESIndex'
ESMigration = require './ESMigration'
ESResultSet = require './ESResultSet'
{ makeESAPI } = require './ESAPI'

class ESBackend extends Backend
	constructor: (@es) ->
		@indices = new ESIndices(@)

	initialize: ->
		@api = makeESAPI(@es, @corpus.log, @corpus.Promise)

	bindModel: (model, bindingOptions) ->
		# Basic checks
		bm = new ESBoundModel(model, @, bindingOptions)
		@indices.addBoundModel(bm)
		bm

	getMigration: ->
		new ESMigration(@corpus, @)

	################################ CREATION
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
		@api.findById(boundModel.getIndex(), boundModel.getDefaultType(), id)
		.then (rst) =>
			if not rst.found then undefined else @_deserialize(boundModel, rst)

	_findByIds: (boundModel, ids) ->
		@api.findByIds(boundModel.getIndex(), boundModel.getDefaultType(), ids)
		.then (rst) =>
			# Comprehense over returned entities.
			for entity in (rst?.docs or [])
				if not (entity?.found) then undefined else @_deserialize(boundModel, entity)

	findById: (boundModel, id) ->
		if Array.isArray(id) then @_findByIds(boundModel, id) else @_findById(boundModel, id)

	find: (boundModel, options) ->
		@api.findRaw(boundModel.getIndex(), boundModel.getDefaultType(), { size: 1, body: options.elasticsearch_query })
		.then (rst) =>
			if (not rst) or (not rst.hits) or (rst.hits.total is 0)
				undefined
			else
				@_deserialize(boundModel, rst.hits.hits[0])

	findAll: (boundModel, options) ->
		searchParams = { }
		# Determine query
		searchParams.body = if options.elasticsearch_query then options.elasticsearch_query else options.cursor?.query
		# Determine search boundaries
		if options.cursor
			searchParams.from = options.cursor.offset
			searchParams.size = options.cursor.limit
		else
			if options.offset then searchParams.from = options.offset
			if options.limit then searchParams.size = options.limit

		@api.findRaw(boundModel.getIndex(), boundModel.getDefaultType(), searchParams)
		.then (rst) =>
			if (not rst) or (not rst.hits)
				new ESResultSet([], 0, 0, null, 0)
			else
				data = (@_deserialize(boundModel, x) for x in rst.hits.hits)
				new ESResultSet(data, rst.hits.total, searchParams.from, searchParams.body, rst.hits.max_score)

	################################ SAVING
	_saveNewInstance: (instance, boundModel) ->
		opts = { }
		if (parent = instance._parent) then opts.parent = parent
		# Allow creation with specified id.
		if (id = instance.id) then opts.id = id

		@api.create(instance._index or boundModel.getIndex(), instance._type or boundModel.getDefaultType(), instance.dataValues, opts)
		.then (rst) =>
			instance._id = rst._id
			@_deserialize(boundModel, rst, instance)
			delete instance.isNewRecord
			instance

	_saveOldInstance: (instance, boundModel) ->
		# Determine data changes to be saved - early out if no changes
		delta = Util.getDelta(instance)
		if not delta then return @corpus.Promise.resolve(instance)
		# Punt to ES
		opts = { }
		if (parent = instance._parent) then opts.parent = parent
		@api.update(instance._index or boundModel.getIndex(), instance._type or boundModel.getDefaultType(), instance.id, delta, opts)
		.then (rst) =>
			@_deserialize(boundModel, rst, instance)
			instance

	save: (instance, boundModel) ->
		if instance.isNewRecord
			@_saveNewInstance(instance, boundModel)
		else
			@_saveOldInstance(instance, boundModel)

	destroy: (instance, boundModel) ->
		opts = { }
		if (parent = instance._parent) then opts.parent = parent
		@api.delete(instance._index or boundModel.getIndex(), instance._type or boundModel.getDefaultType(), instance.id, opts)

module.exports = ESBackend
