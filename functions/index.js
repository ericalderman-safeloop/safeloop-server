const functions = require("firebase-functions");
const authListener = require('./lib/authListener.js');
const { wearer_function } = require('./lib/wearer_function.js');

module.exports = {
    onUserCreated: functions.auth.user().onCreate(authListener),
    wearer_function: functions.https.onRequest(wearer_function)
}
