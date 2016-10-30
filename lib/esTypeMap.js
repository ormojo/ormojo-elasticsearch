'use strict';

exports.__esModule = true;

var _ormojo = require('ormojo');

var ormojo = _interopRequireWildcard(_ormojo);

function _interopRequireWildcard(obj) { if (obj && obj.__esModule) { return obj; } else { var newObj = {}; if (obj != null) { for (var key in obj) { if (Object.prototype.hasOwnProperty.call(obj, key)) newObj[key] = obj[key]; } } newObj.default = obj; return newObj; } }

// Generated by CoffeeScript 1.11.1
var esTypeMap;

exports.default = esTypeMap = function (orType) {
  var match;
  if (orType === ormojo.STRING) {
    return {
      type: 'string'
    };
  } else if (orType === ormojo.TEXT) {
    return {
      type: 'string'
    };
  } else if (orType === ormojo.INTEGER) {
    return {
      type: 'long'
    };
  } else if (orType === ormojo.BOOLEAN) {
    return {
      type: 'boolean'
    };
  } else if (orType === ormojo.FLOAT) {
    return {
      type: 'double'
    };
  } else if (orType === ormojo.OBJECT) {
    return {
      type: 'object'
    };
  } else if (orType === ormojo.DATE) {
    return {
      type: 'date',
      format: 'strict_date_optional_time||epoch_millis'
    };
  } else if (match = /^ARRAY\((.*)\)$/.exec(orType)) {
    return esTypeMap(match[1]);
  } else {
    return void 0;
  }
};