{ Migration, Util } = require 'ormojo'
lodash = require 'lodash'
deepDiff = require 'deep-diff'

_getMigrationCounter = (indexList) ->
	maxn = 0
	for index in indexList
		match = /ormojo(\d+)$/.exec(index)
		# Unmigrated indices in the alias = bailout.
		if not match then return null
		n = parseInt(match[1]); if n > maxn then maxn = n
	maxn

#
# Migration plan for a specific index. Determines if the index can
# be migrated and how.
#
class MigrationPlan
	constructor: (@backend, @index) ->
		@targetSettings = {
			mappings: @index.generateMappings()
			settings: {
				analysis: @index.generateAnalysis()
			}
		}

	getTargetSettings: -> @targetSettings

	prepare: ->
		@getIndex()
		.then =>
			@finalChecks()

	getIndex: ->
		@indexStatus = 'UNKNOWN'
		@backend.es.indices.get({
			index: @index.name
			ignore: [404]
		})
		.then (result) =>
			@backend.corpus.log.trace 'es.indices.get <', JSON.stringify(result, undefined, 2)
			# Check for missing index.
			if result.error
				if result.status is 404 then @indexStatus = 'DOESNT_EXIST'
				return
			# Check for unaliased index which can't be migrated
			if result[@index.name]
				@indexStatus = 'NOT_ALIASED'
				return
			# Check for highest-numbered automigrated index
			matchingIndices = (k for k,v of result)
			n = _getMigrationCounter(matchingIndices)
			if n is null
				@indexStatus = 'NOT_MIGRATED'
				return
			else
				@indexStatus = 'AUTOMIGRATED'
				@migrationCounter = n
				@mostRecentIndex = "#{@index.name}_ormojo#{n}"
			# Get details of most recent index
			details = result[@mostRecentIndex]
			@currentSettings = {
				mappings: details.mappings
				settings: {
					analysis: details.settings?.index?.analysis or {}
				}
			}

	finalChecks: ->
		@migrationDiff = deepDiff.diff(@currentSettings, @targetSettings)
		# Elasticsearch annoyingly stringifies numbers. We must do the same.
		for difference in @migrationDiff
			if difference.kind is 'E' and (JSON.stringify(difference.rhs) is difference.lhs)
				Util.set(@targetSettings, difference.path, difference.lhs)
		# If mappings are the same, migration is unnecessary.
		if lodash.isEqual(@currentSettings, @targetSettings)
			@migrationStrategy = 'NOT_NEEDED'
			return
		else
			@migrationDiff = deepDiff.diff(@currentSettings, @targetSettings)
			@backend.corpus.log.trace 'migration diff', @migrationDiff
		# Determine a migration strategy.
		@migrationStrategy = 'CANT_MIGRATE'
		if @indexStatus is 'UNKNOWN' or @indexStatus is 'NOT_ALIASED' or @indexStatus is 'NOT_MIGRATED'
			@reason = 'Index cannot be automigrated.'
		else if @indexStatus is 'DOESNT_EXIST'
			@migrationStrategy = 'CREATE'
		else if @indexStatus is 'AUTOMIGRATED'
			@migrationStrategy = 'REINDEX'

	executeCreateStrategy: ->
		if @migrationStrategy isnt 'CREATE' then throw new Error('executeCreateStrategy() called in invalid state')
		aliases = {}
		aliases[@index.name] = {}
		body = Object.assign({}, @targetSettings, { aliases })
		@backend.corpus.log.trace 'es.indices.create >', body
		@backend.corpus.Promise.resolve(
			@backend.es.indices.create({
				index: "#{@index.name}_ormojo1"
				body
			})
		)
		.then (result) =>
			@backend.corpus.log.trace 'es.indices.create <', result
			result

	executeReindexStrategy: ->
		if @migrationStrategy isnt 'REINDEX' then throw new Error('executeReindexStrategy() called in invalid state')
		prevIndex = "#{@index.name}_ormojo#{@migrationCounter}"
		nextIndex = "#{@index.name}_ormojo#{@migrationCounter + 1}"
		alias = "#{@index.name}"
		@backend.corpus.log.trace 'es.indices.create >', @targetSettings
		@backend.corpus.Promise.resolve(
			@backend.es.indices.create({
				index: nextIndex
				body: @targetSettings
			})
		)
		.then (result) =>
			@backend.corpus.log.trace 'es.indices.create <', result
			@backend.corpus.log.trace 'es.indices.flush >'
			@backend.es.indices.flush({ index: prevIndex })
		.then (result) =>
			@backend.corpus.log.trace 'es.indices.flush <', result
			@backend.corpus.log.trace 'es.reindex >'
			@backend.es.reindex({
				refresh: true
				waitForCompletion: true
				body: {
					source: { index: prevIndex }
					dest: { index: nextIndex }
				}
			})
		.then (result) =>
			@backend.corpus.log.trace 'es.reindex <', result
			@backend.corpus.log.trace 'es.updateAliases >'
			@backend.es.indices.updateAliases({
				body: {
					actions: [
						{ remove: { index: prevIndex, alias } }
						{ add: { index: nextIndex, alias} }
					]
				}
			})
		.then (result) =>
			@backend.corpus.log.trace 'es.updateAliases <', result

	execute: ->
		if @migrationStrategy is 'REINDEX'
			@executeReindexStrategy()
		else if @migrationStrategy is 'CREATE'
			@executeCreateStrategy()
		else if (not @migrationStrategy)
			@backend.corpus.Promise.reject(new Error('unprepared MigrationPlan'))
		else
			@backend.corpus.Promise.resolve()

class ESMigration extends Migration
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
				currentSettings: plan.currentSettings
				targetSettings: plan.targetSettings
			}
		plans

	execute: ->
		promises = (plan.execute() for name,plan of @plans)
		@corpus.Promise.all(promises)

module.exports = ESMigration
