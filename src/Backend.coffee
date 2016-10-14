{ Backend, BoundModel, Util, createStandardInstanceClassForBoundModel } = require 'ormojo'

class ElasticsearchBackend extends Backend
	constructor: (@es) ->

	bindModel: (model) ->
		bm = new BoundModel(model, @)
		bm.__esindex = bm.spec.backend.index or model.name
		bm.__estype = bm.spec.backend.type
		bm

	################################ CREATION
	createRawInstance: (boundModel, dataValues) ->
		if not boundModel.instanceClass
			boundModel.instanceClass = createStandardInstanceClassForBoundModel(boundModel)
		instance = new boundModel.instanceClass(boundModel, dataValues)
		instance

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
	findById: (boundModel, id) ->
		@corpus.promiseResolve(
			@es.get({
				id, index: boundModel.__esindex, type: '_all'
				ignore: [404]
			})
		).then (rst) =>
			console.log "es.get: ", rst
			if not rst.found
				undefined
			else
				@_deserialize(boundModel, rst)

	find: (boundModel, options) ->
		@corpus.promiseResolve(
			@es.search({
				index: boundModel.__esindex
				body: options.elasticsearch_query
				size: 1
				version: true
			})
		).then (rst) =>
			console.log "es.search: ", rst
			if (not rst) or (not rst.hits) or (rst.hits.total is 0)
				undefined
			else
				@_deserialize(boundModel, rst.hits.hits[0])

	################################ SAVING
	_saveNewInstance: (instance, boundModel) ->
		@corpus.promiseResolve(
			@es.create({
				index: boundModel.__esindex
				type: instance.__type or boundModel.__estype
				body: instance.dataValues
			})
		).then (rst) =>
			console.log "es.create: ", rst
			instance.id = rst._id
			@_deserialize(boundModel, rst, instance)
			delete instance.isNewRecord
			instance

	_saveOldInstance: (instance, boundModel) ->
		# Determine data changes to be saved - early out if no changes
		delta = Util.getDelta(instance)
		if not delta then return @corpus.promiseResolve(instance)
		# Punt to ES
		@corpus.promiseResolve(
			@es.update({
				index: boundModel.__esindex
				type: instance.__type or boundModel.__estype
				body: { doc: delta }
			})
		).then (rst) =>
			console.log "es.update: ", rst
			@_deserialize(boundModel, rst, instance)
			instance

	save: (instance, boundModel) ->
		if instance.isNewRecord
			@_saveNewInstance(instance, boundModel)
		else
			@_saveOldInstance(instance, boundModel)

	destroy: (instance, boundModel) ->
		@corpus.promiseResolve(
			@es.delete({
				index: boundModel.__esindex
				type: instance.__type or boundModel.__estype
				id: instance.id
			})
		).then (rst) ->
			console.log "es.delete: ", rst
			undefined

module.exports = ElasticsearchBackend
