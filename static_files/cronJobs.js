//Destination: server/core
var cronJob = require('cron').CronJob;
var customCron = require('../controller/cron/cron.js');
var jobs = {};

//Define cron jobs. May move this to another file at some point.
/*
jobs[''] = new cronJob(
 '0 5 0 * * *',
 customCron.unfinishedPortsImport,
 null,
 false,
 'America/New_York'
);
*/

module.exports = {
 jobs
}
