{ expect } = require 'chai'
es_backend = require '..'
es_client = require './es_client'
ormojo = require 'ormojo'
Blackbird = require 'blackbird-promises'

makeCorpus = ->
	logger = if true then console.log.bind(console) else ->
	corpus = new ormojo.Corpus({
		Promise: {
			resolve: (x) -> Blackbird.resolve(x)
			reject: (x) -> Blackbird.reject(x)
			all: (x) -> Blackbird.all(x)
		}
		log: {
			trace: logger
		}
		backends: {
			'main': new es_backend(es_client)
		}
	})

	Widget = corpus.createModel({
		name: 'Widget'
		fields: {
			id: { type: ormojo.STRING }
		}
	})

	Kidget = corpus.createModel({
		name: 'Kidget'
		fields: {
			id: { type: ormojo.STRING }
		}
	})

	BWidget = Widget.forBackend('main', {
		index: 'widget',
		type: 'widget'
	})

	BKidget = Kidget.forBackend('main', {
		index: 'widget',
		type: 'kidget',
		parentBoundModel: BWidget
	})

	{ Widget: BWidget, Kidget: BKidget, corpus }

describe 'migration tests: ', ->
	it 'should delete all indices from prior tests', ->
		es_client.indices.delete({
			index: 'widget_ormojo*'
			ignore: [404]
		})

	it 'should create mapping', ->
		{ corpus } = makeCorpus()
		mig = corpus.getBackend('main').getMigration()
		mig.prepare().then ->
			mig.execute()

	it 'should make a widget and a kidget', ->
		{ corpus, Widget, Kidget } = makeCorpus()
		Widget.create({})
		.then (widg) ->
			Kidget.createChild(widg, {})
		.then (kidg) ->
			Kidget.findById(kidg.id)
