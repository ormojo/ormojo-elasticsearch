{ Pagination } = require 'ormojo'

class ESPagination extends Pagination
	constructor: (@query) ->
		super()

	setFromOffset: (@offset, @limit, @total) ->
		@

module.exports = ESPagination
