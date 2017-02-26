import { ResultSet } from 'ormojo'
import Cursor from './ESCursor'

export default class ESResultSet extends ResultSet
	constructor: (data, total, offset, originalQuery, @maxScore = 0) ->
		super()
		@results = data or []
		@total = total or @results.length
		nextOffset = (offset or 0) + @results.length
		if nextOffset < @total
			@cursor = new Cursor(originalQuery).setFromOffset(nextOffset, @results.length, @total)

	getTotalResultCount: -> @total

	getCursor: -> @cursor

	getMaxScore: -> @maxScore
