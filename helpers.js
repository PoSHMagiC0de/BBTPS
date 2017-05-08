// Helper Modules
var jfs = require('fs');

function jobsParser(jobsObj, jbFldr){
    var runType = ['thread','process'];
    if(jobsObj instanceof Array){
        for(i=0;i<jobsObj.length;i++){
            if(jfs.existsSync(jbFldr + jobsObj[i].scriptName) && runType.indexOf(jobsObj[i].runType.toLowerCase()) > -1){
                jobsObj[i].scriptName = jbFldr + jobsObj[i].scriptName;
            }else{
                jobsObj.splice(i, 1);
                console.log("removing job, script file invalid");
            }
        }
    }else{
        if(jfs.existsSync(jbFldr + jobsObj.scriptName) && runType.indexOf(jobsObj.runType) > -1){
            jobsObj.scriptName = jbFldr + jobsObj.scriptName;
        }else{
            jobsObj = null;
            console.log('removing job, script file invalid');
        }
    }
    console.log(jobsObj);
    return jobsObj;
}

exports.jobParser = jobsParser;