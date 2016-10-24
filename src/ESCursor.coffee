{ Cursor } = require 'ormojo'

class ESCursor extends Cursor
	constructor: (@query) ->
		super()

	setFromOffset: (@offset, @limit, @total) ->
		@

module.exports = ESCursor
