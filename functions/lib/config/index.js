"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const fs = require('fs');
const functions = require("firebase-functions");
let environment = functions.config().app.environment;
exports.default = JSON.parse(fs.readFileSync(require('path').resolve(__dirname, `./${environment}.json`)));
