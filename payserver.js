//Initializes main server modules
var prc = require('child_process');
prc.exec('LED SPECIAL1').unref();
var fs = require('fs');
var zlib = require('zlib');
var express = require('express');
var bodyParser = require('body-parser');
var app = express();
var port = 1337;
var lootdir = process.env['LOOTDIR'] || __dirname + '/tmploot';
var jobsfolder = __dirname + '/jobs/';
var agentfile = __dirname + '/agent/bbAgent.ps1';

app.use(bodyParser.json());
app.use(bodyParser.urlencoded({extended:false}));

var FirstRun = false;
var AgentRequested = false;

//process jobslist
var joblist = require(__dirname + '/joblist.json');
var helper = require(__dirname + '/helpers.js');

joblist = helper.jobParser(joblist, jobsfolder);
console.log(joblist);

app.get('/getAgent', function(req, res){
    console.log('Agent Requested...');
    if(AgentRequested == false){
        prc.exec('LED STAGE2').unref();
        console.log('Agent download led indicator lit..');
        AgentRequested = true;
    }
    fs.readFile(agentfile, 'utf8', function(err, data){
        if(err){
            console.log('Error reading Agent.');
            exit(1);
        }else{
            console.log('Sending Agent...');
            res.send(data);
        }
    });
});

app.get('/getJob1', function(req, res){
    console.log('A job was requested');
    if(FirstRun == false){
        prc.exec('LED STAGE3').unref();
        console.log('LED lights for first job sent..');
        FirstRun = true;
    }
    sendjob = joblist.pop();
    if(sendjob){
        var payload = {};
        payload.jobName = sendjob.jobName;
        payload.command = sendjob.command;
        payload.runType = sendjob.runType.toLowerCase();
        fs.readFile(sendjob.scriptName, 'utf8', function(err, data){
            if(err){
                console.log("error reading payload");
            }else{
                zlib.deflateRaw(new Buffer(data), function(err, buffer){
                    payload.payload = buffer.toString('base64');
                    //console.log(payload);
                    res.json(payload);
                })                
            }
        });
    }else{
        var payload = {};
        payload.jobName = "none";
        payload.payload = "none";
        res.json(payload);
    }
});

app.post('/addJob', function(req, res){
    console.log(req.body);
    var addJobObj = req.body;
    addJobObj = helper.jobParser(addJobObj, jobsfolder);
    if(addJobObj){        
        joblist.push(addJobObj);
        res.send('done');
    }else{
        res.send('error');
    }
});

app.post('/pushData', function(req, res){
    console.log(req.body);
    var logData = req.body;
    if(logData.jobName){
        var logtmp = lootdir + '/' + logData.jobName + '.log';
        fs.writeFile(logtmp, logData.data, function(err){
            if(err){
                res.send('error');
            }else{
                res.send('success');
            }
        });
    }else{
        res.send('error');
    }
});

app.get('/quit', function(req, res){
    prc.exec('LED FINISH').unref();
    res.send('bye');
    process.exit(0);
});

app.listen(port, function(){
    console.log('Starting Server');
});