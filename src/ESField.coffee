{ Field } = ormojo = require 'ormojo'

_idGetter = -> @_id
_idSetter = (k,v) ->
	if @_id? then throw new Error('ESInstance: cannot reassign `id` - create a new Instance instead')
	@_id = v

class ESField extends Field
	fromSpec: (name, spec) ->
		super
		# Special handling for es id fields
		if name is 'id'
			if spec.get or spec.set
				throw new Error('ESField: `id` field may not have custom getter or setter.')
			if (spec.type isnt ormojo.STRING) and (spec.type isnt ormojo.INTEGER)
				throw new Error('ESField: `id` field must be `ormojo.STRING` or `ormojo.INTEGER`')
			@get = _idGetter; @set = _idSetter
		@

module.exports = ESField
