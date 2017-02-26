import { BoundModel, createStandardInstanceClassForBoundModel } from 'ormojo'
import ESField from './ESField'
import esTypeMap from './esTypeMap'
import ESResultSet from './ESResultSet'
import ESStore from './store/Store'
import ESHydrator from './store/Hydrator'

export default class ESBoundModel extends BoundModel
	constructor: (model, backend, bindingOptions) ->
		super
		if typeof(@name) isnt 'string' then throw new Error('ESBoundModel: Cannot bind unnamed model.')
		if typeof(@spec.type) isnt 'string' then throw new Error("ESBoundModel: bound model derived from Model named #{model.name} must specify an elasticsearch type")
		@esIndex = (@spec.index or @name).toLowerCase()
		# Apply index auto-prefixing.
		if backend.indexPrefix and (not (bindingOptions?.indexIsRaw))
			@esIndex = backend.indexPrefix + @esIndex
		@esType = (@spec.type).toLowerCase()
		@instanceClass = createStandardInstanceClassForBoundModel(@)
		@store = new ESStore({@corpus, backend, defaultIndex: @esIndex, defaultType: @esType})
		@hydrator = new ESHydrator({boundModel: @})

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
		bindingOptions.indexIsRaw = true # Parent index is raw and already prefixed
		bindingOptions.parentBoundModel = @
		@backend.bindChildModel(model, bindingOptions)

	# Create a query addressing this boundModel.
	createQuery: ->
		q = @backend.createQuery()
		q.index = @getIndex()
		q.type = @getDefaultType()
		q

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
