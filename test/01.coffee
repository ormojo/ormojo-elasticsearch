{ expect } = require 'chai'
es_backend = require '..'
es_client = require './es_client'
ormojo = require 'ormojo'

makeCorpus = ->
	c = new ormojo.Corpus({
		backends: {
			'main': new es_backend(es_client)
		}
	})

	c.createModel({
		name: 'widget'
		fields: {
			id: { type: ormojo.STRING }
			name: { type: ormojo.STRING, default: 'nameless' }
			qty: { type: ormojo.INTEGER, default: -> 1 + 1 }
		}
		backends: {
			main: {
				index: 'test'
				type: 'test'
			}
		}
	})

	c


describe 'basic tests: ', ->
	it 'should create, save, find by id', ->
		c = makeCorpus()
		widget = c.getModel('widget')
		widgetm = widget.forBackend('main')
		awidget = widgetm.create()
		awidget.name = 'whosit'

		testThing = null
		awidget.save().then (thing) ->
			console.log 'saved!', thing.get()
			thing
		.then (thing) ->
			testThing = thing
			widgetm.findById(thing.id)
		.then (anotherThing) ->
			expect(anotherThing.get()).to.deep.equal(testThing.get())
