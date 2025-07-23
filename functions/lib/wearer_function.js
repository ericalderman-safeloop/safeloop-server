const cors = require('cors')({ origin: true });
const functions = require('firebase-functions');
const { db } = require('./admin.js')


const wearer_function = async (req, res) => {
    cors(req, res, async () => {
        const data = req.body;

        console.log('>>>>>>>>>>>>> Wearer Functions: ' + data.type + ' <<<<<<<<<<<<<<<<<<<<');

        switch (data.type) {
            case "validate_watch":
                var account_snapshot = await db.collection('accounts')
                    .where("wearer_id", "==", data.wearer_id).get();
                if (account_snapshot.empty) {
                    console.log('No account found for wearer_id: ' + data.wearer_id);
                    return res.status(200).send({ success: false, message: 'No account found for the provided wearer_id' });
                } else {
                    var account = account_snapshot.docs[0].data();
                    console.log('Account found: ', account);
                    return res.status(200).send({ success: true, message: 'Account found', account: account });
                }
            break;

            case "help_request":
                const helpRequest = {
                    wearer_id: data.wearer_id,
                    event: data.event,
                    resolution: data.resolution,
                    location: data.location,
                    createdAt: new Date().toISOString()
                };

                try {
                    await db.collection('help_requests').add(helpRequest);
                    console.log('Help request saved successfully');

                    
                    return res.status(200).send({ success: true, message: 'Help request saved successfully' });
                } catch (error) {
                    console.error('Error saving help request:', error);
                    return res.status(500).send({ success: false, message: 'Error saving help request' });
                }
        } 
    });
}

module.exports = {
    wearer_function
};
