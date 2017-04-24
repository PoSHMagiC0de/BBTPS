# BashBunny Total P0wn System

Author: PoSHMag1C0de

## Introduction
The BashBunny Total P0wn System is more like a tool than a payload for the BashBunny.  It is used to launch multiple payloads through an agent to the victims machine.

Right now I am only working on a Powershell agent.  Maybe there will be others who would like to create agents for other OSes.  More info on that as I update the documentation.  The server is just a Nodejs server that serves scripts as jobs to the agent running on the victims machine.  The agent is launched by the first stage the BashBunny payload runs in HID mode to create a download cradle to receive the BunnyAgent.

## Directions

## Installation
This tool/payload uses express so you will need to clone the repository to your computer and run ```npm install``` while in the repository's folder to install express.  You will need npm and node installed to do this.  After that, just put the BashBunny in arming mode and copy the contents of the repo to one of the switch folders.  Configure and go P0wn something.

### Script formats
Your Powershell scripts should be formatted as functions like in the Powersploit guide.  This makes your scripts modular so they can be loaded and then ran with parameters.  BBTPS handles scripts formatted like this.

Your scripts can be formatted in regular text, base64 encoded in ASCII or compressed.  A utilities folder contains a Powershell script originally Out-CompressedScript I modified to output just the base64 compressed script, minus the command to decompress it.  That part is in the BunnyAgent.  All Powershell scripts are stored in the jobs folder.  I included a few test scripts that does get directory listings to see an example.

If your scripts are going to return data that needs to be returned to the BashBunny, the output of the data should be as a string.  Consider piping your output to "out-string".

If you have any jobs that are supposed to keep running even after the BashBunny is done, please encapsulate them in a here-string to be kicked off in a separate process with start-process.  The system is setup so when jobs are done, the BashBunny will indicate it but if you have a job that will never end then the BunnyAgent task for that job will never end thus you never get a signal on the BashBunny that it is done.

Example

```gci c:\ | out-string```

### Setting Up Jobs
In the root of the BBTPS folder are 2 files.

- joblist.json
- joblist_template.json

The joblist.json file is where all the scripts you want to be delivered to the BunnyAgent are input.  The template file is a template describing the schema of the joblist.json file and the jobs are listed as a json array.  This file is sucked in by the server on initialization and each job processed as the BunnyAgent requests them.  The required fields that need to be filled in are described below.

**jobName**

Name of the script job.  Must be unique to avoid conflicts.  This is also the name of the text file that will be saved in the loot folder that will contain the data for that job.  The value is a string and should contain no special characters.

**encoding**

The format the script is in.  The correct values are text, base64 and compressed.  This info is sent to the BunnyAgent so it knows what format to convert the script from to properly run it.  This value is a string.

**command**

The function that calls your script and any parameters goes here.  This is appended to the decoded script on the BunnyAgent side before ran.  This value is a string.

**scriptName**

The name of the script file in the jobs folder.  You only put the name of the script here.  The server already looks for it in the jobs folder.  Right now only scripts in the jobs folder is supported.

### BBTPS LEDs
Below are the indicator lights and their normal working order for the BBTPS

| Color | Description |
|-------|-------------|
| Solid Magenta	| Attackmode initialization for both HID and Ethernet |
| Yellow Single Blink | Start HID Quack Attack |
| Cyan Inverted Blink | Node Server Initializing |
| Yellow 2x Blink | Agent being delivered |
| Yellow 3x Blink | First Job Being Delivered to Agent |
| Green | Agent Finished Successfully |
| Red | Server Errored Out |
The order of normal operation is:

1. Solid Magenta
2. Yellow Single Blink
3. Solid Magenta
4. Cyan Inverted Blink
5. Yellow 2x Blink
6. Yellow 3x Blink


### Extras
The BBTPS can not only send out jobs but receive data from your scripts in the BunnyAgent to tell the server to queue up other jobs.  You just have to make sure you have the script for that job in the jobs folder.  Your script simple has to make a POST back to the BashBunny to url "/addJob", IP and port "default port is 1337" with a single json object in the same format as what is in the joblist.json.  If the script exists, it will queue it up to be pulled when the BunnyAgent checks for jobs.  This can come in handy if you only want to send a script if you conditions are met or if you can make conditions for it.  Since I am trying to get this out, I will include more about this feature as I update the documentation.

To help with debugging your scripts in the agent, in the payload.txt you can enable debugging.  This runs a download cradle not hidden and the agent verbose so you can see what is taking place.

~~Right now the agent only works with Powershell 3.0 and higher.  I am working out the kinks to make it fully 2.0 compliant.~~

**4/24/2017 Updated the BunnyAgent so it now works in Powershell 2.0.**

This documentation is a work in progress as well as this project.  expect bugs.