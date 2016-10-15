{ expect } = require 'chai'
es_backend = require '..'
es_client = require './es_client'
ormojo = require 'ormojo'
Blackbird = require 'blackbird-promises'

makeCorpus = ->
	c = new ormojo.Corpus({
		promiseResolve: (x) -> Blackbird.resolve(x)
		promiseReject: (x) -> Blackbird.reject(x)
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

	{ corpus: c, Widget: c.getModel('widget') }

describe 'basic tests: ', ->
	it 'should delete index', ->
		es_client.indices.delete({index: 'widget'})

	it 'should create, save, find by id', ->
		{ Widget } = makeCorpus()
		awidget = Widget.create()
		awidget.name = 'whosit'

		testThing = null
		awidget.save()
		.then (thing) ->
			testThing = thing
			Widget.findById(thing.id)
		.then (anotherThing) ->
			expect(anotherThing.get()).to.deep.equal(testThing.get())
			anotherThing.destroy()

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
			id = widg.id
			widg.destroy()
		.then ->
			Widget.findById(id)
		.then (x) ->
			expect(x).to.equal(undefined)

	it 'should find one by keyword', ->
		{ Widget } = makeCorpus()
		Widget.create({name: 'uniquely named thing', qty: 50})
		.delay(1000) # wait for es indexing
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

	it 'should find many', ->
		{ Widget } = makeCorpus()
		promises = (Widget.create({name: "findAll #{i}", tags: ['findAll'], qty: i}) for i in [0...10])
		Blackbird.all(promises)
		.delay(1000) # wait for es indexing
		.then (results) ->
			Widget.findAll({elasticsearch_query: {
				query: { match: { tags: 'findAll' } }
			}})
		.then (results) ->
			expect(results.data.length).to.equal(10)

	it 'should paginate', ->
		{ Widget } = makeCorpus()
		Widget.findAll({
			limit: 3
			elasticsearch_query: {
				query: { match: { tags: 'findAll' } }
				sort: { qty: 'asc' }
			}
		})
		.then (results) ->
			expect(results.data[0].qty).to.equal(0)
			Widget.findAll({
				pagination: results.pagination
			})
		.then (results) ->
			expect(results.data[0].qty).to.equal(3)
