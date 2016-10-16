{ expect } = require 'chai'
es_backend = require '..'
es_client = require './es_client'
ormojo = require 'ormojo'
Blackbird = require 'blackbird-promises'

makeCorpus = ->
	c = new ormojo.Corpus({
		Promise: {
			resolve: (x) -> Blackbird.resolve(x)
			reject: (x) -> Blackbird.reject(x)
			all: (x) -> Blackbird.all(x)
		}
		backends: {
			'main': new es_backend(es_client)
		}
		defaultBackend: 'main'
	})

	c.createModel({
		name: 'widget'
		fields: {
			id: { type: ormojo.STRING }
			name: { type: ormojo.STRING, default: 'nameless' }
			qty: { type: ormojo.INTEGER, default: -> 1 + 1 }
			tags: { type: ormojo.ARRAY(ormojo.STRING), default: -> [] }
		}
		backends: {
			main: {
				type: 'test'
			}
		}
	})

	{ corpus: c, Widget: c.getModel('widget') }


describe 'migration tests: ', ->
	it 'should have static migration plan', ->
		{ corpus } = makeCorpus()
		corpus.bindAllModels()
		mig = corpus.getBackend('main').getMigration()
		console.dir mig.plans['widget'].getTargetMappings(), { depth: 50 }

	it 'should offer migration', ->
		{ corpus } = makeCorpus()
		corpus.bindAllModels()
		mig = corpus.getBackend('main').getMigration()
		mig.prepare()
