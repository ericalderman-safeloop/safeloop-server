'use strict';
const admin = require("firebase-admin");
const config = require('./config')

var serviceAccount_URL = config.default.serviceAccount_URL;
var serviceAccount = require(serviceAccount_URL);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: config.default.database_URL
});

const db = admin.firestore();
const auth = admin.auth();

module.exports = {
    db,
    auth,
    admin
}