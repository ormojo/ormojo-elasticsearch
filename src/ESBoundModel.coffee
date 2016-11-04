import { BoundModel, createStandardInstanceClassForBoundModel } from 'ormojo'
import ESField from './ESField'
import esTypeMap from './esTypeMap'
import ESResultSet from './ESResultSet'

export default class ESBoundModel extends BoundModel
	constructor: (model, backend, bindingOptions) ->
		super
		if typeof(@name) isnt 'string' then throw new Error('ESBoundModel: Cannot bind unnamed model.')
		if typeof(@spec.type) isnt 'string' then throw new Error("ESBoundModel: bound model derived from Model named #{model.name} must specify an elasticsearch type")
		@esIndex = (@spec.index or @name).toLowerCase()
		@esType = (@spec.type).toLowerCase()
		@instanceClass = createStandardInstanceClassForBoundModel(@)
		@api = backend.api

	_deriveFields: ->
		@fields = {}
		for k,fieldSpec of @spec.fields
			f = new ESField().fromSpec(k, fieldSpec)
			@fields[k] = f
		if not @fields['id']
			throw new Error("ESBoundModel: bound model derived from Model named `#{@model.name}` must have an id field.")
		undefined

	getIndex: -> @esIndex
	getDefaultType: -> @esType

	bindChildModel: (model, bindingOptions) ->
		bindingOptions = bindingOptions or {}
		# Child index must be the same as this index.
		bindingOptions.index = @getIndex()
		bindingOptions.parentBoundModel = @
		@backend.bindChildModel(model, bindingOptions)

	_deserialize: (esData, instance, overrideDVs) ->
		dvs = overrideDVs or esData._source
		if instance
			instance._setDataValues(dvs)
		else
			instance = @createInstance(dvs)
		if esData._id then instance._id = esData._id
		if esData._index then instance._index = esData._index
		if esData._version then instance._version = esData._version
		if esData._type then instance._type = esData._type
		if esData._score then instance._score = esData._score
		if esData._routing then instance._routing = esData._routing
		if esData._parent then instance._parent = esData._parent
		instance._clearChanges()
		instance

	_findById: (id) ->
		@backend.api.findInstanceById(@getIndex(), @getDefaultType(), @_deserialize, @, id)

	_findByIds: (ids) ->
		@backend.api.findByIds(@getIndex(), @getDefaultType(), ids)
		.then (rst) =>
			# Comprehense over returned entities.
			for entity in (rst?.docs or [])
				if not (entity?.found) then undefined else @_deserialize(entity)

	findById: (id) ->
		if Array.isArray(id) then @_findByIds(id) else @_findById(id)

	find: (options) ->
		@api.findRaw(@getIndex(), @getDefaultType(), { size: 1, body: options.elasticsearch_query })
		.then (rst) =>
			if (not rst) or (not rst.hits) or (rst.hits.total is 0)
				undefined
			else
				@_deserialize(rst.hits.hits[0])

	findAll: (options) ->
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

		@api.findRaw(@getIndex(), @getDefaultType(), searchParams)
		.then (rst) =>
			if (not rst) or (not rst.hits)
				new ESResultSet([], 0, 0, null, 0)
			else
				data = (@_deserialize(x) for x in rst.hits.hits)
				new ESResultSet(data, rst.hits.total, searchParams.from, searchParams.body, rst.hits.max_score)

	_saveNewInstance: (instance) ->
		@api.createFromInstance(instance, @_deserialize, @)

	_saveOldInstance: (instance) ->
		@api.updateInstance(instance, @_deserialize, @)

	save: (instance) ->
		if instance.isNewRecord
			@_saveNewInstance(instance)
		else
			@_saveOldInstance(instance)

	destroyById: (id) ->
		@api.destroy(@getIndex(), @getDefaultType(), id)

	destroy: (instance) ->
		@api.destroyInstance(instance)

	# Generate Elasticsearch mapping properties
	generateMapping: ->
		m = {}
		m.properties = props = {}

		for k, field of @getFields() when k isnt 'id'
			mapping = field.spec.elasticsearch?.mapping or {}
			# Merge missing keys from typemap defaults
			for mk,mv of esTypeMap(field.spec.type)
				if not (mk of mapping) then mapping[mk] = mv

			props[field.getBackendFieldName()] = mapping

		m

	# Generate Elasticsearch analysis properties
	generateAnalysisProps: ->
		props = {}
		if @spec.analyzer then props.analyzer = @spec.analyzer
		if @spec.filter then props.filter = @spec.filter
		props
