var exp;

try {
	exp = require("./src/index");
} catch(e) {
	exp = require("./js/index");
}

module.exports = exp;
