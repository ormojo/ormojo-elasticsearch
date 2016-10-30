// Generated by CoffeeScript 1.11.1
var ESCursor,
    extend = function (child, parent) {
  for (var key in parent) {
    if (hasProp.call(parent, key)) child[key] = parent[key];
  }function ctor() {
    this.constructor = child;
  }ctor.prototype = parent.prototype;child.prototype = new ctor();child.__super__ = parent.prototype;return child;
},
    hasProp = {}.hasOwnProperty;

import { Cursor } from 'ormojo';

export default ESCursor = function (superClass) {
  extend(ESCursor, superClass);

  function ESCursor(query) {
    this.query = query;
    ESCursor.__super__.constructor.call(this);
  }

  ESCursor.prototype.setFromOffset = function (offset, limit, total) {
    this.offset = offset;
    this.limit = limit;
    this.total = total;
    return this;
  };

  return ESCursor;
}(Cursor);