{ Backend, BoundModel, Util, createStandardInstanceClassForBoundModel } = require 'ormojo'

class ElasticsearchBackend extends Backend
	constructor: (@es) ->

	bindModel: (model) ->
		bm = new BoundModel(model, @)
		bm.__esindex = bm.spec.backend.index
		bm.__estype = bm.spec.backend.type
		bm

	################################ CREATION
	createRawInstance: (boundModel, dataValues) ->
		if not boundModel.instanceClass
			boundModel.instanceClass = createStandardInstanceClassForBoundModel(boundModel)
		instance = new boundModel.instanceClass(boundModel, dataValues)
		instance

	createInstance: (boundModel, initialData) ->
		instance = @createRawInstance(boundModel)
		instance.isNewRecord = true
		instance.__applyDefaults()
		if initialData isnt undefined
			instance.set(initialData)
			@saveInstance(instance, boundModel)
		else
			instance

	################################ FINDING
	findInstanceById: (boundModel, id) ->
		@corpus.promiseResolve(
			@es.get({ id, index: boundModel.__esindex, type: (boundModel.__estype or '_all')})
		).then (rst) =>
			if not rst.found
				undefined
			else
				@createRawInstance(boundModel, Object.assign({ id: rst._id}, rst._source))

	################################ SAVING
	_saveNewInstance: (instance, boundModel) ->
		@corpus.promiseResolve(
			@es.create({
				index: boundModel.__esindex
				type: instance.__type or boundModel.__estype
				body: instance.dataValues
			})
		).then (rst) ->
			instance.id = rst._id
			instance._version = rst._version
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
		).then (rst) ->
			console.log "saveOldInstance result ", rst
			instance

	saveInstance: (instance, boundModel) ->
		if instance.isNewRecord
			@_saveNewInstance(instance, boundModel)
		else
			@_saveOldInstance(instance, boundModel)

	destroyInstance: (instance, boundModel) ->
		@corpus.promiseResolve(
			@es.delete({
				index: boundModel.__esindex
				type: instance.__type or boundModel.__estype
				id: instance.id
			})
		).then (rst) ->
			console.log "destroyInstance result ", rst
			undefined

module.exports = ElasticsearchBackend
