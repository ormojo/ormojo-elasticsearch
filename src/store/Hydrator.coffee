import { Hydrator, Util } from 'ormojo'

# Move between Elasticsearch Json API and ormojo instances.
export default class ESHydrator extends Hydrator
	constructor: ->
		super

	# Get ES API data for an instance.
	getDataForInstance: (instance, dvs) ->
		rst = {
			index: instance._index or @boundModel.getIndex()
			type: instance._type or @boundModel.getDefaultType()
			data: dvs or instance._getDataValues()
		}
		if instance._parent then rst.parent = instance._parent
		if instance.id then rst.id = instance.id
		rst

	# Update an instance from an ES API return value.
	updateInstanceWithData: (instance, esData) ->
		instance._setDataValues(esData._source)
		if esData._id then instance._id = esData._id
		if esData._index then instance._index = esData._index
		if esData._version then instance._version = esData._version
		if esData._type then instance._type = esData._type
		if esData._score then instance._score = esData._score
		if esData._routing then instance._routing = esData._routing
		if esData._parent then instance._parent = esData._parent
		instance._clearChanges()
		instance

	didRead: (instance, data) ->
		if data is undefined then return undefined
		if instance
			@updateInstanceWithData(instance, data)
		else
			instance = @boundModel.createInstance()
			@updateInstanceWithData(instance, data)

	willCreate: (instance) ->
		@getDataForInstance(instance)

	didCreate: (instance, data) ->
		@updateInstanceWithData(instance, data)

	willUpdate: (instance) ->
		delta = Util.getDelta(instance)
		if not delta then return undefined
		@getDataForInstance(instance, delta)

	didUpdate: (instance, deltaData) ->
		# The underlying Store returns the delta sent to Elasticsearch as the _source field.
		instance._mergeDataValues(deltaData._source)
		# Re-apply the post-merge data values
		deltaData._source = instance.dataValues
		@updateInstanceWithData(instance, deltaData)

	willDelete: (instance) ->
		@getDataForInstance(instance)
