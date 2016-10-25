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
			value: { type: ormojo.STRING }
		}
	})

	Kidget = corpus.createModel({
		name: 'Kidget'
		fields: {
			id: { type: ormojo.STRING }
			value: { type: ormojo.STRING }
		}
	})

	BWidget = Widget.forBackend('main', {
		index: 'widget',
		type: 'widget'
	})

	BKidget = BWidget.bindChildModel(Kidget, {
		type: 'kidget',
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
		parent = null
		Widget.create({ value: 'mom'})
		.then (widg) ->
			parent = widg
			Kidget.create(widg, { value: 'kid'})
		.then (kidg) ->
			expect(kidg.value).to.equal('kid')
			Kidget.findById(parent, kidg.id)
		.then (kidg) ->
			expect(kidg._parent).to.equal(parent.id)
			expect(kidg.value).to.equal('kid')

	it 'should do CRUD on kidget', ->
		{ corpus, Widget, Kidget } = makeCorpus()
		parent = null
		Widget.create({ value: 'mom'})
		.then (widg) ->
			parent = widg
			Kidget.create(widg, { value: 'kid'})
		.then (kidg) ->
			kidg.value = 'child'
			kidg.save()
		.then (kidg) ->
			expect(kidg.value).to.equal('child')
			kidg.destroy()

	it 'should do CRUD ops by string id instead of object', ->
		{ corpus, Widget, Kidget } = makeCorpus()
		parent = null
		Widget.create({ value: 'mom'})
		.then (widg) ->
			parent = widg
			Kidget.create(widg.id, { value: 'kid'})
		.then (kidg) ->
			expect(kidg.value).to.equal('kid')
			Kidget.findById(parent.id, kidg.id)
		.then (kidg) ->
			expect(kidg._parent).to.equal(parent.id)
			expect(kidg.value).to.equal('kid')
			Kidget.destroyById(parent.id, kidg.id)
		.then (rst) ->
			expect(rst).to.equal(true)
