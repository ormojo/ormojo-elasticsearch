{ ResultSet } = require 'ormojo'
Cursor = require './ESCursor'

class ESResultSet extends ResultSet
	constructor: (data, @total, offset, searchBody, @maxScore = 0) ->
		super()
		@results = data or []
		nextOffset = (offset or 0) + @results.length
		if nextOffset < @total
			@cursor = new Cursor(searchBody).setFromOffset(nextOffset, @results.length, @total)

	getTotalResultCount: -> @total

	getCursor: -> @cursor

	getMaxScore: -> @maxScore

module.exports = ESResultSet
