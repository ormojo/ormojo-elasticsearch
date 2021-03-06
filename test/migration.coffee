{ expect } = require 'chai'
{ ESBackend: es_backend } = require '..'
es_client = require './es_client'
ormojo = require 'ormojo'
Blackbird = require 'blackbird-promises'

makeCorpus = ->
	logger = if '--ormojo-trace' in process.argv then console.log.bind(console) else ->
	new ormojo.Corpus({
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

makeModel = (corpus, modified) ->
	fields = {
		id: { type: ormojo.STRING }
		name: { type: ormojo.STRING, defaultValue: 'nameless' }
		timestamp: { type: ormojo.DATE, defaultValue: -> new Date }
		url: {
			type: ormojo.STRING
			elasticsearch: {
				mapping: { index: 'not_analyzed' }
			}
		}
		qty: { type: ormojo.INTEGER, defaultValue: -> 1 + 1 }
		tags: {
			type: ormojo.ARRAY(ormojo.STRING)
			defaultValue: -> []
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
	if modified then fields['extra'] = { type: ormojo.STRING, defaultValue: 'extraData' }

	Widget = corpus.createModel({
		name: 'widget'
		fields
	})

	Widget.forBackend('main', {
		index: 'widget'
		type: 'test'
		filter: {
			autocomplete_filter: {
				type: 'edge_ngram',
				min_gram: 1,
				max_gram: 10
			}
		}
		analyzer: {
			autocomplete: {
				type: 'custom',
				tokenizer: 'standard',
				filter: [ 'lowercase', 'autocomplete_filter' ]
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
		mig = corpus.getBackend('main').getMigration()
		mig.prepare()
		.then ->
			plan = mig.getMigrationPlan()
			console.dir plan[0].targetSettings, { depth: 50 }

	it 'should do a create migration', ->
		corpus = makeCorpus()
		Widget = makeModel(corpus)
		mig = corpus.getBackend('main').getMigration()
		mig.prepare()
		.then ->
			plan = mig.getMigrationPlan()
			expect(plan[0].strategy).to.equal('CREATE')
			mig.execute()

	it 'should report repeated migration as unneded', ->
		corpus = makeCorpus()
		Widget = makeModel(corpus)
		mig = corpus.getBackend('main').getMigration()
		mig.prepare()
		.then ->
			plan = mig.getMigrationPlan()
			expect(plan[0].strategy).to.equal('NOT_NEEDED')
		.then ->
			Widget.create({ name: 'wodget', qty: 50, tags: ['cool']})

	it 'should do a reindex migration', ->
		corpus = makeCorpus()
		Widget = makeModel(corpus, true)
		mig = corpus.getBackend('main').getMigration()
		mig.prepare()
		.then ->
			plan = mig.getMigrationPlan()
			expect(plan[0].strategy).to.equal('REINDEX')
			mig.execute()
		.then ->
			Widget.create({ name: 'whatsit', qty: 50000, tags:['unCool'], extra: '150'})
