{ Migration } = require 'ormojo'

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
		@getMappings()
		.then =>
			@getAliases()

	getMappings: ->
		@backend.es.indices.getMapping({
			index: @index.name
		})
		.then (result) =>
			rst = _extractFirst(result)?.mappings
			console.log rst
			@currentMappings = rst

	getAliases: ->
		@backend.es.indices.getAliases({
			index: @index.name
			name: '*'
		})
		.then (result) =>
			console.log result
			flat = _flattenAliasResult(result, @index.name)
			if flat.status is 'DOESNT_EXIST'
				@migrationStrategy = 'CREATE'
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
		.then (results) =>
			(console.log(plan) for name,plan of @plans)

module.exports = ElasticsearchMigration
