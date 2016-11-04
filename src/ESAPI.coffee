# Basic Elasticsearch crud operations.
import { Util } from 'ormojo'

export makeESAPI = (es, log, Promise) ->
	findById = (index, type, id, parent) ->
		rq = { id, index, type, ignore: [404] }
		if parent then rq.parent = parent
		log.trace "es.get >", rq
		Promise.resolve( es.get(rq) )
		.then (rst) ->
			log.trace "es.get <", rst
			rst

	findByIds = (index, type, ids, opts) ->
		rq = { index, type, body: { ids } }
		if opts then Object.assign(rq, opts)
		log.trace "es.mget >", rq
		Promise.resolve( es.mget(rq) )
		.then (rst) ->
			log.trace "es.mget <", rst
			rst

	findRaw = (index, type, opts) ->
		rq = { index, type, version: true }
		if not opts then throw new Error('findRaw: must provide `opts`')
		Object.assign(rq, opts)
		log.trace "es.search >", rq
		Promise.resolve( es.search(rq) )
		.then (rst) ->
			log.trace "es.search <", rst
			rst

	create = (index, type, data, id, parent) ->
		rq = { index, type, body: data }
		if id then rq.id = id
		if parent then rq.parent = parent
		log.trace "es.create >", rq
		Promise.resolve( es.create(rq) )
		.then (rst) ->
			log.trace "es.create <", rst
			rst

	update = (index, type, id, delta, parent) ->
		rq = { index, type, id, body: { doc: delta } }
		if parent then rq.parent = parent
		log.trace "es.update >", rq
		Promise.resolve( es.update(rq) )
		.then (rst) ->
			log.trace "es.update <", rst
			rst

	destroy = (index, type, id, parent) ->
		rq = { index, type, id, ignore: [404] }
		if parent then rq.parent = parent
		log.trace "es.delete >", rq
		Promise.resolve( es.delete(rq) )
		.then (rst) ->
			log.trace "es.delete <", rst
			if rst?.found then true else false

	findInstanceById = (index, type, rehydrate, rehydrateContext, id, parent) ->
		findById(index, type, id, parent)
		.then (rst) ->
			if not rst.found then undefined else rehydrate.call(rehydrateContext, rst)

	createFromInstance = (instance, rehydrate, rehydrateContext) ->
		# We need to pass in the correct data values to the deserializer here.
		# (Consequence of switching the sense of the BoundInstance delta storage.)
		dvs = instance._getDataValues()
		create(instance._index or instance.boundModel.getIndex(), instance._type or instance.boundModel.getDefaultType(), dvs, instance.id, instance._parent)
		.then (rst) ->
			instance._id = rst._id
			# Pass along DVs that we stored before...
			rehydrate.call(rehydrateContext, rst, instance, dvs)
			instance

	updateInstance = (instance, rehydrate, rehydrateContext) ->
		# Send only the delta to elasticsearch.
		# Don't persist unchanged instances
		delta = Util.getDelta(instance)
		if not delta then return Promise.resolve(instance)
		update(instance._index or instance.boundModel.getIndex(), instance._type or instance.boundModel.getDefaultType(), instance.id, delta, instance._parent)
		.then (rst) ->
			# Do the data-value merging, since the persistence was successful.
			# XXX: private API...
			instance._mergeDataValues(instance._nextDataValues)
			rehydrate.call(rehydrateContext, rst, instance, instance.dataValues)
			instance

	destroyInstance = (instance) ->
		destroy(instance._index or instance.boundModel.getIndex(), instance._type or instance.boundModel.getDefaultType(), instance.id, instance._parent)

	{
		findById, findByIds, findRaw, create, update, destroy
		findInstanceById, createFromInstance, updateInstance, destroyInstance
	}
