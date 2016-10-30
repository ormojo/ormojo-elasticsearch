import { Backend, BoundModel, Util, createStandardInstanceClassForBoundModel } from 'ormojo'
import ESBoundModel from './ESBoundModel'
import ESChildModel from './ESChildModel'
import { ESIndex, ESIndices } from './ESIndex'
import ESMigration from './ESMigration'
import ESResultSet from './ESResultSet'
import { makeESAPI } from './ESAPI'

export default class ESBackend extends Backend
	constructor: (@es) ->
		@indices = new ESIndices(@)

	initialize: ->
		@api = makeESAPI(@es, @corpus.log, @corpus.Promise)

	_bindModel: (clazz, model, bindingOptions) ->
		bm = new clazz(model, @, bindingOptions)
		@indices.addBoundModel(bm)
		bm

	bindModel: (model, bindingOptions) ->
		@_bindModel(ESBoundModel, model, bindingOptions)

	bindChildModel: (childModel, bindingOptions) ->
		@_bindModel(ESChildModel, childModel, bindingOptions)

	getMigration: ->
		new ESMigration(@corpus, @)

	################################ CREATION
	_deserialize: (boundModel, esData, instance) ->
		if instance
			Object.assign(instance.dataValues, esData._source)
		else
			instance = boundModel._createInstance(esData._source)
		if esData._id then instance._id = esData._id
		if esData._index then instance._index = esData._index
		if esData._version then instance._version = esData._version
		if esData._type then instance._type = esData._type
		if esData._score then instance._score = esData._score
		if esData._routing then instance._routing = esData._routing
		if esData._parent then instance._parent = esData._parent
		instance._clearChanges()
		instance

	################################ FINDING

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
