ormojo = require 'ormojo'

esTypeMap = (orType) ->
	if orType is ormojo.STRING
		'string'
	else if orType is ormojo.INTEGER
		'long'
	else if orType is ormojo.BOOLEAN
		'boolean'
	else if orType is ormojo.FLOAT
		'double'
	else if orType is ormojo.OBJECT
		'object'
	else if (match = /^ARRAY\((.*)\)$/.exec(orType))
		esTypeMap(match[1])
	else
		undefined

module.exports = esTypeMap
