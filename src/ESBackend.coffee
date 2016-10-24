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
		instance._clearChanges()
		instance

	################################ FINDING
	_findById: (boundModel, id) ->
		@api.findInstanceById(boundModel, @_deserialize, @, id)

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
		@api.createFromInstance(instance, @_deserialize, @)

	_saveOldInstance: (instance, boundModel) ->
		@api.updateInstance(instance, @_deserialize, @)

	save: (instance, boundModel) ->
		if instance.isNewRecord
			@_saveNewInstance(instance, boundModel)
		else
			@_saveOldInstance(instance, boundModel)

	destroy: (instance, boundModel) ->
		@api.destroyInstance(instance)

module.exports = ESBackend
