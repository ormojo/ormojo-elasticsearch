{ Pagination } = require 'ormojo'

class ElasticsearchPagination extends Pagination
	constructor: (@query) ->
		super()

	setFromOffset: (@offset, @limit, @total) ->
		@

module.exports = ElasticsearchPagination
