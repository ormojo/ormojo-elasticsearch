ormojo = require 'ormojo'

esTypeMap = (orType) ->
	if orType is ormojo.STRING
		{ type: 'string' }
	else if orType is ormojo.TEXT
		{ type: 'string' }
	else if orType is ormojo.INTEGER
		{ type: 'long' }
	else if orType is ormojo.BOOLEAN
		{ type: 'boolean' }
	else if orType is ormojo.FLOAT
		{ type: 'double' }
	else if orType is ormojo.OBJECT
		{ type: 'object' }
	else if orType is ormojo.DATE
		{ type: 'date', format: 'strict_date_optional_time||epoch_millis' }
	else if (match = /^ARRAY\((.*)\)$/.exec(orType))
		esTypeMap(match[1])
	else
		undefined

module.exports = esTypeMap
