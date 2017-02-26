import { Store as OrmojoStore } from 'ormojo'
import ESResultSet from '../ESResultSet'

export default class Store extends OrmojoStore
	constructor: ({@defaultIndex, @defaultType}) ->
		super
		@api = @backend.api

	createOne: (data) ->
		# Store dataValues that we used to create the instance.
		createdValues = data.data
		@api.create(data.index, data.type, data.data, data.id, data.parent)
		.then (res) ->
			# Elasticsearch does not return the new values; pull them from the original doc.
			res._source = createdValues
			res

	updateOne: (data) ->
		if not data
			@corpus.Promise.resolve(null)
		else
			updateData = data.data
			@api.update(data.index, data.type, data.id, updateData, data.parent)
			.then (res) ->
				# Return the delta-values we updated with...
				res._source = updateData
				res

	crupsert: (data, isCreate) ->
		# XXX: use Bulk API here.
		promises = for datum in data
			if (not datum?) then throw new Error("invalid create format")
			if isCreate then @createOne(datum) else @updateOne(datum)
		@corpus.Promise.all(promises)

	read: (query) ->
		if (ids = query?.ids)
			if ids.length is 0
				@corpus.Promise.resolve([])
			else if ids.length is 1
				# Elasticsearch GET
				@api.findById(query.index, query.type, ids[0], query.parent)
				.then (rst) ->
					if not rst.found then new ESResultSet([]) else new ESResultSet([ rst ])
			else
				# Elasticsearch MGET
				opts = if query.parent then { routing: query.parent }
				@api.findByIds(query.index, query.type, ids, opts)
				.then (rst) ->
					entities = for entity in (rst?.docs or [])
						if not (entity?.found) then undefined else entity
					new ESResultSet(entities)
		else if (body = query?.getQueryDsl())
			# Elaticsearch SEARCH
			searchParams = { body }
			if query.offset then searchParams.from = query.offset
			if query.limit then searchParams.size = query.limit
			@api.findRaw(query.index, query.type, searchParams)
			.then (rst) ->
				if (not rst) or (not rst.hits)
					new ESResultSet([], 0, 0, query, 0)
				else
					new ESResultSet(rst.hits.hits, rst.hits.total, searchParams.from, query, rst.hits.max_score)
		else
			throw new Error("invalid query format")

	create: (data) ->
		@crupsert(data, true)

	update: (data) ->
		promises = for datum in data
			@updateOne(datum)
		@corpus.Promise.all(promises)

	upsert: (data) ->
		@crupsert(data, false)

	delete: (data) ->
		promises = for datum in data
			if datum?.id
				# Destroy given full object spec.
				@api.destroy(datum.index, datum.type, datum.id, datum.parent)
			else
				# Destroy given only ID.
				@api.destroy(@defaultIndex, @defaultType, datum)
		@corpus.Promise.all(promises)
