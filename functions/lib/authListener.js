const { admin } = require('./admin.js');

const db = admin.firestore();

async function onCreate(user) {
    const wearerData = {
        uid: user.uid,
        email: user.email || null,
        displayName: user.displayName || null,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
    };

    await db.collection('wearers').doc(user.uid).set(wearerData);
}

module.exports = { onCreate };