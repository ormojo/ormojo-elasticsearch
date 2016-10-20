{ Migration } = require 'ormojo'
lodash = require 'lodash'

_flattenAliasResult = (result, soughtAlias) ->
	if result?[soughtAlias]
		{ status: 'INDEX_EXISTS' }
	else
		indicesWithSoughtAlias = []
		for actualIndex, aliasData of (result or {})
			if aliasData?.aliases?[soughtAlias]
				indicesWithSoughtAlias.push(actualIndex)
		if indicesWithSoughtAlias.length > 0
			{ status: 'ALIAS_EXISTS', indices: indicesWithSoughtAlias }
		else
			{ status: 'DOESNT_EXIST' }

_getMigrationCounter = (indexList) ->
	maxn = 0
	for index in indexList
		match = /ormojo(\d+)$/.exec(index)
		# Unmigrated indices in the alias = bailout.
		if not match then return null
		n = parseInt(match[1]); if n > maxn then maxn = n
	maxn

_extractFirst = (object) -> return v for k,v of object


#
# Migration plan for a specific index. Determines if the index can
# be migrated and how.
#
class MigrationPlan
	constructor: (@backend, @index) ->
		@targetMappings = @index.generateMappings()

	getTargetMappings: -> @targetMappings

	prepare: ->
		@backend.corpus.Promise.all([@getMappings(), @getAliases()])
		.then =>
			@finalChecks()

	getMappings: ->
		@backend.es.indices.getMapping({
			index: @index.name
			ignore: [404]
		})
		.then (result) =>
			@backend.corpus.log.trace 'indices.getMapping', result
			rst = _extractFirst(result)?.mappings
			@currentMappings = rst or {}

	getAliases: ->
		@backend.es.indices.getAliases({
			index: @index.name
			name: '*'
		})
		.then (result) =>
			flat = _flattenAliasResult(result, @index.name)
			if flat.status is 'DOESNT_EXIST'
				@migrationStrategy = 'CREATE'
				@migrationCounter = 1
			else if flat.status is 'ALIAS_EXISTS'
				n = _getMigrationCounter(flat.indices)
				if n is null
					@migrationStrategy = 'CANT_MIGRATE'
					@reason = 'Alias points to unmigrated index'
				else
					@migrationStrategy = 'REINDEX'
					@migrationCounter = n
			else
				@migrationStrategy = 'CANT_MIGRATE'
				@reason = 'Index is not aliased.'

	finalChecks: ->
		# If mappings are the same, migration is unnecessary.
		if lodash.isEqual(@currentMappings, @targetMappings)
			@migrationStrategy = 'NOT_NEEDED'
			return

	executeCreateStrategy: ->
		if @migrationStrategy isnt 'CREATE' then throw new Error('executeCreateStrategy() called in invalid state')
		aliases = {}
		aliases[@index.name] = {}
		@backend.corpus.Promise.resolve(
			@backend.es.indices.create({
				index: "#{@index.name}_ormojo#{@migrationCounter}"
				body: {
					mappings: @targetMappings
					aliases
				}
			})
		)

	executeReindexStrategy: ->
		if @migrationStrategy isnt 'REINDEX' then throw new Error('executeReindexStrategy() called in invalid state')
		prevIndex = "#{@index.name}_ormojo#{@migrationCounter}"
		nextIndex = "#{@index.name}_ormojo#{@migrationCounter + 1}"
		alias = "#{@index.name}"
		@backend.corpus.Promise.resolve(
			@backend.es.indices.create({
				index: nextIndex
				body: {	mappings: @targetMappings }
			})
		)
		.then (result) =>
			console.log "indices.create", result
			@backend.es.indices.flush({ index: prevIndex })
		.then (result) =>
			console.log "indices.flush", result
			@backend.es.reindex({
				refresh: true
				waitForCompletion: true
				body: {
					source: { index: prevIndex }
					dest: { index: nextIndex }
				}
			})
		.then (result) =>
			console.log "reindex", result
			@backend.es.indices.updateAliases({
				body: {
					actions: [
						{ remove: { index: prevIndex, alias } }
						{ add: { index: nextIndex, alias} }
					]
				}
			})
		.then (result) ->
			console.log "indices.updateAliases", result

	execute: ->
		if @migrationStrategy is 'REINDEX'
			@executeReindexStrategy()
		else if @migrationStrategy is 'CREATE'
			@executeCreateStrategy()
		else if (not @migrationStrategy)
			@backend.corpus.Promise.reject(new Error('unprepared MigrationPlan'))
		else
			@backend.corpus.Promise.resolve()

class ElasticsearchMigration extends Migration
	constructor: (corpus, backend) ->
		super(corpus, backend)
		@plans = {}
		for name, index of @backend.indices.getIndices()
			@plans[name] = new MigrationPlan(backend, index)

	prepare: ->
		# Develop a migration plan for each index.
		promises = (plan.prepare() for name, plan of @plans)
		@corpus.Promise.all(promises)

	getMigrationPlan: ->
		plans = for name,plan of @plans
			{
				strategy: plan.migrationStrategy
				index: plan.index.name
				currentMappings: plan.currentMappings
				targetMappings: plan.targetMappings
			}
		plans

	execute: ->
		promises = (plan.execute() for name,plan of @plans)
		@corpus.Promise.all(promises)

module.exports = ElasticsearchMigration
