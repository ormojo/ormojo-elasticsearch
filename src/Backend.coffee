{ Backend, BoundModel } = require 'ormojo'

class ElasticsearchBackend extends Backend
	constructor: (@es) ->

	createBoundModel: (model) ->
		new BoundModel(model, @)
