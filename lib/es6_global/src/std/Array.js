// Generated by ReScript, PLEASE EDIT WITH CARE

import * as Curry from "../../../../node_modules/rescript/lib/es6/curry.js";
import * as Belt_Array from "../../../../node_modules/rescript/lib/es6/belt_Array.js";

function concat(prim0, prim1) {
  return prim0.concat(prim1);
}

function length(prim) {
  return prim.length;
}

function empty(a) {
  return a.length === 0;
}

function filter(prim0, prim1) {
  return prim0.filter(Curry.__1(prim1));
}

function flatMap(a, fn) {
  return Belt_Array.concatMany(a.map(Curry.__1(fn)));
}

function flatMapWithIndex(a, fn) {
  return Belt_Array.concatMany(Belt_Array.mapWithIndex(a, fn));
}

function from(prim) {
  return Array.from(prim);
}

function includes(prim0, prim1) {
  return prim0.includes(prim1);
}

function join(prim0, prim1) {
  return prim0.join(prim1);
}

function map(prim0, prim1) {
  return prim0.map(Curry.__1(prim1));
}

function reduce(prim0, prim1, prim2) {
  return prim0.reduce(Curry.__2(prim1), prim2);
}

function some(prim0, prim1) {
  return prim0.some(Curry.__1(prim1));
}

var flatten = Belt_Array.concatMany;

var mapWithIndex = Belt_Array.mapWithIndex;

var slice = Belt_Array.slice;

export {
  concat ,
  length ,
  empty ,
  filter ,
  flatten ,
  flatMap ,
  mapWithIndex ,
  flatMapWithIndex ,
  from ,
  includes ,
  join ,
  map ,
  reduce ,
  slice ,
  some ,
  
}
/* No side effect */