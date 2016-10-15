# Make the ES client for testing.
# Do not expose credentials for a live server to git!
elasticsearch = require 'elasticsearch'

module.exports = new elasticsearch.Client({
	host: 'slave1.internal.oigroup.net:9200'
})
