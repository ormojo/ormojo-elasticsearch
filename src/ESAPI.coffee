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
		create(instance._index or instance.boundModel.getIndex(), instance._type or instance.boundModel.getDefaultType(), instance._getDataValues(), instance.id, instance._parent)
		.then (rst) ->
			instance._id = rst._id
			rehydrate.call(rehydrateContext, rst, instance)
			instance

	updateInstance = (instance, rehydrate, rehydrateContext) ->
		# Don't persist unchanged instances
		delta = Util.getDelta(instance)
		if not delta then return Promise.resolve(instance)
		update(instance._index or instance.boundModel.getIndex(), instance._type or instance.boundModel.getDefaultType(), instance.id, delta, instance._parent)
		.then (rst) ->
			rehydrate.call(rehydrateContext, rst, instance)
			instance

	destroyInstance = (instance) ->
		destroy(instance._index or instance.boundModel.getIndex(), instance._type or instance.boundModel.getDefaultType(), instance.id, instance._parent)

	{
		findById, findByIds, findRaw, create, update, destroy
		findInstanceById, createFromInstance, updateInstance, destroyInstance
	}
