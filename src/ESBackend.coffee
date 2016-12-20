import { Backend } from 'ormojo'
import ESBoundModel from './ESBoundModel'
import ESChildModel from './ESChildModel'
import { ESIndex, ESIndices } from './ESIndex'
import ESMigration from './ESMigration'
import { makeESAPI } from './ESAPI'

export default class ESBackend extends Backend
	constructor: (@es) ->
		@indices = new ESIndices(@)

	initialize: ->
		@api = makeESAPI(@es, @corpus.log, @corpus.Promise)

	_bindModel: (clazz, model, bindingOptions) ->
		bm = new clazz(model, @, bindingOptions)
		@indices.addBoundModel(bm)
		bm

	bindModel: (model, bindingOptions) ->
		@_bindModel(ESBoundModel, model, bindingOptions)

	bindChildModel: (childModel, bindingOptions) ->
		@_bindModel(ESChildModel, childModel, bindingOptions)

	getMigration: ->
		new ESMigration(@corpus, @)
