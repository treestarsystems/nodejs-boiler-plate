//Destination: server/app.js
const core = require('./core/core.js');

function appCode () {
 console.log(`${core.coreVars.projectName}|${process.env.pm_id}: Running App Specific Code...`)
}

module.exports = {
 appCode
}
