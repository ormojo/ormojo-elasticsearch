// Generated by CoffeeScript 1.11.1
var ESField,
    _idGetter,
    _idSetter,
    extend = function (child, parent) {
  for (var key in parent) {
    if (hasProp.call(parent, key)) child[key] = parent[key];
  }function ctor() {
    this.constructor = child;
  }ctor.prototype = parent.prototype;child.prototype = new ctor();child.__super__ = parent.prototype;return child;
},
    hasProp = {}.hasOwnProperty;

import { Field, STRING, INTEGER } from 'ormojo';

_idGetter = function () {
  return this._id;
};

_idSetter = function (k, v) {
  if (this._id != null) {
    throw new Error('ESInstance: cannot reassign `id` - create a new Instance instead');
  }
  return this._id = v;
};

export default ESField = function (superClass) {
  extend(ESField, superClass);

  function ESField() {
    return ESField.__super__.constructor.apply(this, arguments);
  }

  ESField.prototype.fromSpec = function (name, spec) {
    ESField.__super__.fromSpec.apply(this, arguments);
    if (name === 'id') {
      if (spec.get || spec.set) {
        throw new Error('ESField: `id` field may not have custom getter or setter.');
      }
      if (spec.type !== STRING && spec.type !== INTEGER) {
        throw new Error('ESField: `id` field must be `ormojo.STRING` or `ormojo.INTEGER`');
      }
      this.get = _idGetter;
      this.set = _idSetter;
    }
    return this;
  };

  return ESField;
}(Field);