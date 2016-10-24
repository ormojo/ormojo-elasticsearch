# Basic Elasticsearch crud operations.

makeESAPI = (es, log, Promise) ->
	{
		findById: (index, type, id, opts) ->
			rq = { id, index, type, ignore: [404] }
			if opts then Object.assign(rq, opts)
			log.trace "es.get >", rq
			Promise.resolve( es.get(rq) )
			.then (rst) ->
				log.trace "es.get <", rst
				rst

		findByIds: (index, type, ids, opts) ->
			rq = { index, type, body: { ids } }
			if opts then Object.assign(rq, opts)
			log.trace "es.mget >", rq
			Promise.resolve( es.mget(rq) )
			.then (rst) ->
				log.trace "es.mget <", rst
				rst

		findRaw: (index, type, opts) ->
			rq = { index, type, version: true }
			if not opts then throw new Error('findRaw: must provide `opts`')
			Object.assign(rq, opts)
			log.trace "es.search >", rq
			Promise.resolve( es.search(rq) )
			.then (rst) ->
				log.trace "es.search <", rst
				rst

		create: (index, type, data, opts) ->
			rq = { index, type, body: data }
			if opts then Object.assign(rq, opts)
			log.trace "es.create >", rq
			Promise.resolve( es.create(rq) )
			.then (rst) ->
				log.trace "es.create <", rst
				rst

		update: (index, type, id, delta, opts) ->
			rq = { index, type, id, body: { doc: delta } }
			if opts then Object.assign(rq, opts)
			log.trace "es.update >", rq
			Promise.resolve( es.update(rq) )
			.then (rst) ->
				log.trace "es.update <", rst
				rst

		delete: (index, type, id, opts) ->
			rq = { index, type, id }
			if opts then Object.assign(rq, opts)
			log.trace "es.delete >", rq
			Promise.resolve( es.delete(rq) )
			.then (rst) ->
				log.trace "es.delete <", rst
				if rst?.found then true else false
	}

module.exports = { makeESAPI }
