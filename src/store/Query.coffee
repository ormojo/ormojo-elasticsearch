import { Query } from 'ormojo'

export default class ESQuery extends Query
	constructor: ->
		super

	setQueryDsl: (@body) -> @

	setLimit: (@limit) -> @

	setCursor: (cursor) ->
		@body = cursor.query?.getQueryDsl()
		@offset = cursor.offset
		@limit = cursor.limit
		@

	# Get Elasticsearch Query DSL JSON for this query.
	getQueryDsl: ->
		@body
