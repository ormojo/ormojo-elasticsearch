import { Cursor } from 'ormojo'

export default class ESCursor extends Cursor
	constructor: (@query) ->
		super()

	setFromOffset: (@offset, @limit, @total) ->
		@
