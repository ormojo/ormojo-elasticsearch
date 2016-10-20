{ Cursor } = require 'ormojo'

class ElasticsearchCursor extends Cursor
	constructor: (@query) ->
		super()

	setFromOffset: (@offset, @limit, @total) ->
		@

module.exports = ElasticsearchCursor
