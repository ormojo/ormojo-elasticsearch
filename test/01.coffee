{ expect } = require 'chai'
es_backend = require '..'
es_client = require './es_client'
ormojo = require 'ormojo'

makeCorpus = ->
	c = new ormojo.Corpus({
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
			tags: { type: ormojo.ARRAY, default: -> [] }
		}
		backends: {
			main: {
				type: 'test'
			}
		}
	})

	{ Widget: c.getModel('widget') }

describe 'basic tests: ', ->
	it 'should create, save, find by id', ->
		{ Widget } = makeCorpus()
		awidget = Widget.create()
		awidget.name = 'whosit'

		testThing = null
		awidget.save().then (thing) ->
			console.log 'saved!', thing.get()
			thing
		.then (thing) ->
			testThing = thing
			Widget.findById(thing.id)
		.then (anotherThing) ->
			expect(anotherThing.get()).to.deep.equal(testThing.get())

	it 'shouldnt find documents that arent there', ->
		{ Widget } = makeCorpus()

		Widget.findById('nothere')
		.then (x) ->
			expect(x).to.equal(undefined)

	it 'should save, delete, not find', ->
		{ Widget } = makeCorpus()
		id = null
		Widget.create({name: 'whatsit', qty: 1000000})
		.then (widg) ->
			console.log widg.get()
			id = widg.id
			widg.destroy()
		.then ->
			Widget.findById(id)
		.then (x) ->
			expect(x).to.equal(undefined)

	it 'should find one by keyword', ->
		{ Widget } = makeCorpus()
		Widget.create({name: 'uniquely named thing', qty: 50})
		.then ->
			Widget.find({elasticsearch_query: {
				query: { match: { name: 'uniquely' } }
			}})
		.then (widg) ->
			expect(widg.qty).to.equal(50)
			widg.destroy()

	it 'should find nothing', ->
		{ Widget } = makeCorpus()
		Widget.find({elasticsearch_query: {
			query: { match: { name: 'frobozz' } }
		}})
		.then (nothing) ->
			expect(nothing).to.equal(undefined)
