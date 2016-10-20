{ expect } = require 'chai'
es_backend = require '..'
es_client = require './es_client'
ormojo = require 'ormojo'
Blackbird = require 'blackbird-promises'

makeCorpus = ->
	new ormojo.Corpus({
		Promise: {
			resolve: (x) -> Blackbird.resolve(x)
			reject: (x) -> Blackbird.reject(x)
			all: (x) -> Blackbird.all(x)
		}
		log: {
			trace: console.log.bind(console)
		}
		backends: {
			'main': new es_backend(es_client)
		}
		defaultBackend: 'main'
	})

makeModel = (corpus, modified) ->
	fields = {
		id: { type: ormojo.STRING }
		name: { type: ormojo.STRING, default: 'nameless' }
		url: {
			type: ormojo.STRING
			elasticsearch: {
				mapping: { index: 'not_analyzed' }
			}
		}
		qty: { type: ormojo.INTEGER, default: -> 1 + 1 }
		tags: {
			type: ormojo.ARRAY(ormojo.STRING)
			default: -> []
			elasticsearch: {
				mapping: {
					fields: {
						raw: {
							type: 'string'
							index: 'not_analyzed'
						}
					}
				}
			}
		}
	}
	if modified then fields['extra'] = { type: ormojo.STRING, default: 'extraData' }

	corpus.createModel({
		name: 'widget'
		fields
		backends: {
			main: {
				type: 'test'
			}
		}
	})


describe 'migration tests: ', ->
	it 'should delete all indices from prior tests', ->
		es_client.indices.delete({
			index: 'widget_ormojo*'
			ignore: [404]
		})

	it 'should have static migration plan', ->
		corpus = makeCorpus()
		Widget = makeModel(corpus)
		corpus.bindAllModels()
		mig = corpus.getBackend('main').getMigration()
		mig.prepare()
		.then ->
			plan = mig.getMigrationPlan()
			console.dir plan[0].targetSettings, { depth: 50 }

	it 'should do a create migration', ->
		corpus = makeCorpus()
		Widget = makeModel(corpus)
		corpus.bindAllModels()
		mig = corpus.getBackend('main').getMigration()
		mig.prepare()
		.then ->
			console.log mig.getMigrationPlan()
			mig.execute()
		.then ->
			Widget.create({ name: 'wodget', qty: 50, tags: ['cool']})

	it 'should do a reindex migration', ->
		corpus = makeCorpus()
		Widget = makeModel(corpus, true)
		corpus.bindAllModels()
		mig = corpus.getBackend('main').getMigration()
		mig.prepare()
		.then ->
			console.log mig.getMigrationPlan()
			mig.execute()
		.then ->
			Widget.create({ name: 'whatsit', qty: 50000, tags:['unCool'], extra: '150'})
