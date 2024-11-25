___INFO___

{
  "type": "CLIENT",
  "id": "cvt_temp_public_id",
  "version": 1,
  "securityGroups": [],
  "displayName": "CTRL Your documentation - HTML",
  "brand": {
    "id": "brand_dummy",
    "displayName": ""
  },
  "description": "",
  "containerContexts": [
    "SERVER"
  ]
}


___TEMPLATE_PARAMETERS___

[
  {
    "type": "TEXT",
    "name": "projectId",
    "displayName": "GCP Project",
    "simpleValueType": true
  },
  {
    "type": "TEXT",
    "name": "firestoreCollection",
    "displayName": "Firestore Collection",
    "simpleValueType": true
  },
  {
    "type": "TEXT",
    "name": "endpoint",
    "displayName": "Endpoint",
    "simpleValueType": true
  },
  {
    "type": "CHECKBOX",
    "name": "automaticDocumentation",
    "checkboxText": "Auto document GA4 events",
    "simpleValueType": true,
    "defaultValue": true,
    "subParams": [
      {
        "type": "CHECKBOX",
        "name": "checkForNewParameters",
        "checkboxText": "Check for new parameters to already documented events",
        "simpleValueType": true,
        "defaultValue": true,
        "enablingConditions": [
          {
            "paramName": "automaticDocumentation",
            "paramValue": true,
            "type": "EQUALS"
          }
        ]
      },
      {
        "type": "TEXT",
        "name": "ignoreParameters",
        "displayName": "Ignore these parameters (applicable across all fields)",
        "simpleValueType": true,
        "enablingConditions": [
          {
            "paramName": "checkForNewParameters",
            "paramValue": true,
            "type": "EQUALS"
          }
        ]
      }
    ]
  }
]


___SANDBOXED_JS_FOR_SERVER___

/*
 *  Copyright 2024 CTRL Digital AB
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 */

const Firestore = require('Firestore');
const setResponseBody = require('setResponseBody');
const setResponseStatus = require('setResponseStatus');
const setResponseHeader = require('setResponseHeader');
const returnResponse = require('returnResponse');
const getRequestPath = require('getRequestPath');
const getRequestBody = require('getRequestBody');
const log = require('logToConsole');
const claimRequest = require('claimRequest');
const JSON = require('JSON');
const Object = require('Object');
const templateDataStorage = require('templateDataStorage');
const getTimestampMillis = require('getTimestampMillis');
const Promise = require('Promise');
const getAllEventData = require('getAllEventData');
const isRequestMpv2 = require('isRequestMpv2');
const extractEventsFromMpv2 = require('extractEventsFromMpv2');
const getType = require('getType');

const projectId = data.projectId;
const collection = data.firestoreCollection;

// Get last documentation update and set as template storage.
lastDocumentationUpdate();
// Check if data is available in template storage
const cachedContent = cachedDataExists();

if (getRequestPath() === data.endpoint) {
  claimRequest();
  
  // If the no data is available, fetch new data
  if (!cachedContent) {
    Firestore.query(collection, [], { projectId: projectId, limit: 10000 })
      .then(firestoreData => {
        if (firestoreData) {
          setTemplateStorages(firestoreData); 
          
          let htmlPage = generateHtmlPage(firestoreData);
          
          setResponseBody(htmlPage);
          setResponseStatus(200);
          returnResponse();
        } else {
          log('No data returned from Firestore');
          setResponseStatus(500);
          returnResponse();
        }});
  } else {
    log('Documentation: Read data from cache.');
    
    let htmlPage = generateHtmlPage(cachedContent);
    
    setResponseBody(htmlPage);
    setResponseStatus(200);
    returnResponse();
  }

} else if (getRequestPath() === data.endpoint + '_update') {
  claimRequest();
  const body      = JSON.parse(getRequestBody()),
        eventName = body.event_name,
        newParams = body.new_parameters || {},
        newEvent  = {'SAFE_GUARD':'DO NOT REMOVE'};
  
  Object.delete(body, 'event_name');
  Object.delete(body, 'new_parameters');
  
  newEvent[eventName] = body;

  if (data.ignoreParameters) {
    data.ignoreParameters.split(',').forEach(parameter => removeKeyFromObject(body, parameter.trim()));
  }
  
  Firestore.write(collection + '/events', newEvent, { projectId: projectId, merge: true })
          .then(() => {
    Firestore.query(collection, [], { projectId: projectId, limit: 10000 })
        .then(firestoreData => {
      
      let updatedUndocumentedData;
      firestoreData.forEach(document => document.id.indexOf('undocumented') > -1 ? updatedUndocumentedData = document.data : {});
      
      if(updatedUndocumentedData) {
        Object.delete(updatedUndocumentedData, eventName);
        
        Firestore.write(collection + '/undocumented', updatedUndocumentedData, { projectId: projectId })
          .then();
      }
      
      if(newParams && Object.keys(newParams).length > 0) {
        const currentParams = {
          'event_parameters':{'SAFE_GUARD':'DO NOT REMOVE'},
          'user_properties':{'SAFE_GUARD':'DO NOT REMOVE'},
          'item_parameters':{'SAFE_GUARD':'DO NOT REMOVE'}
        };
        firestoreData.forEach(document => {
          const scope = document.id.replace(collection + '/','');
          
          if (currentParams[scope]) {
            currentParams[scope] = document.data;
          }
        });
        const updatedParams = combineNewParams(currentParams, newParams);
        
        Firestore.write(collection + '/event_parameters', updatedParams.event_parameters,{ projectId: projectId})
            .then();
        Firestore.write(collection + '/user_properties', updatedParams.user_properties,{ projectId: projectId})
            .then();
        Firestore.write(collection + '/item_parameters', updatedParams.item_parameters,{ projectId: projectId})
            .then();
      }
  
      setUpdatedTimestamp();
      returnResponse();
        
    });
  });
    
} else if (data.automaticDocumentation && isRequestMpv2()) {
  if (!cachedContent) {
    Firestore.query(collection, [], { projectId: projectId, limit: 10000 })
      .then(firestoreData => {
      
        if (!firestoreData) {
          log('No data returned from Firestore');
          setResponseStatus(500);
          returnResponse();
        } else {
          setTemplateStorages(firestoreData); 
          processAutoDocumentationRequest(firestoreData);        
        }
      });
  } else {
    processAutoDocumentationRequest(cachedContent);
  }
}

function processAutoDocumentationRequest(firestoreData) {
    const request = extractEventsFromMpv2();
    
    request.forEach(event => {
      
      let newEventName           = event.event_name,
          newEvent               = cleanCustomKeys(event),
          checkForNewParameters  = data.checkForNewParameters,
          newEventKeys           = getNestedKeys(newEvent),
          documentedEvent        = findDocumentedEvent(firestoreData, newEventName) || [],
          undocumentedEvent      = findUndocumentedEvent(firestoreData, newEventName) || [];
      
      if ((documentedEvent.length === 0 && undocumentedEvent.length === 0) || 
          (undocumentedEvent.length > 0 && hasNewKey(newEventKeys, undocumentedEvent)) ||
           (checkForNewParameters && undocumentedEvent.length === 0 && hasNewKey(newEventKeys, documentedEvent))) {
        
        let oldData = getUndocumentedEventObject(firestoreData, newEventName) || {};
        
        writeUndocumentedData(newEventName,newEvent,oldData);
      }
    });
    
    return;
  }

function findDocumentedEvent(firestoreData, event) {
  let eventsData;
  let eventData;
  
  firestoreData.forEach(document => document.id.indexOf('events') > -1 ? eventsData = document.data : undefined);
  
  if (!eventsData || Object.keys(eventsData).length === 0) return;
  
  Object.entries(eventsData).forEach(element => element[0] === event ? eventData = element[1] : undefined);
  
  if (!eventData || Object.keys(eventData).length === 0) return [];// Return an empty array if the event is not found

  // Get required and optional parameters, defaulting to an empty array if not present
  const requiredParameters = eventData.required_parameters || [];
  const optionalParameters = eventData.optional_parameters || [];
  
  // Combine the required and optional parameters into one list
  const combinedParameters = requiredParameters.concat(optionalParameters);
  
  return combinedParameters;
}

function findUndocumentedEvent(firestoreData, event) {
  let undocumentedData = getUndocumentedEventObject(firestoreData, event);
  let returnData = getNestedKeys(undocumentedData);
  
  return returnData;
}

function getUndocumentedEventObject(firestore, event) {
  let undocumentedData;
  let returnData = {};
  firestore.forEach(document => document.id.indexOf('undocumented') > -1 ? undocumentedData = document.data : undefined);
  
  if (!undocumentedData || Object.keys(undocumentedData).indexOf(event) === -1) return returnData;
  
  Object.entries(undocumentedData).forEach(data => {
    const key = data[0];
    const value = data[1];
    if (key === event) {
      returnData = value;
    }
  });
  return returnData;
}

function getNestedKeys (data) {
  const scopes = ['event_parameters', 'user_properties', 'item_parameters'];
  const returnArray = [];
  scopes.forEach(scope => {
    if (!data[scope]) return;
    Object.keys(data[scope]).forEach(param => returnArray.push(param));
  });
  return returnArray;
}

function hasNewKey(newEventKeys, oldEventKeys) {
  if (!newEventKeys || newEventKeys.length === 0) return false;
  if (!oldEventKeys || oldEventKeys.length === 0) return true;
  
  const hasAdditionalKeys = newEventKeys.some(param => oldEventKeys.indexOf(param) === -1);
  
  return hasAdditionalKeys;
}

function writeUndocumentedData(eventName, eventData, oldData) {
  const newData = mergeObjects(eventData, oldData);
  
  const dataToWrite = createUndocumentedObject(newData, eventName);
        
  if (data.ignoreParameters && data.ignoreParameters.length > 0) {
    data.ignoreParameters.split(',').forEach(parameter => removeKeyFromObject(dataToWrite, parameter.trim()));
  }
  
  Firestore.write(collection + '/undocumented', dataToWrite, { projectId: projectId, merge: true })
    .then(() => {
      log('Documentation: event added to undocumented list:', eventName);
      setUpdatedTimestamp();
    });
}

function mergeObjects(newData, oldData) {
  // Loop through each key of the first-level scopes
  for (let key of Object.keys(oldData)) {
    if (newData.hasOwnProperty(key)) {
      // Merge only new keys in second-level
      for (let subKey of Object.keys(oldData[key])) {
        if (!newData[key].hasOwnProperty(subKey)) {
          newData[key][subKey] = oldData[key][subKey];
        }
      }
    } else {
      // If the first-level property doesn't exist, copy it
      newData[key] = oldData[key];
    }
  }
  return newData;
}

function createUndocumentedObject(data, eventName) {
  let dataToWrite = {};
  
  dataToWrite.SAFE_GUARD = 'DO NOT REMOVE';
  dataToWrite[eventName] = data;
  
  return dataToWrite;
}

function cleanCustomKeys(object) {
  Object.entries(object).forEach(array => {
    let key = array[0],
        value = array[1];
    const keyContains = (substring) => key.indexOf(substring) > -1;

    if ((keyContains('x-ga') && !keyContains('user_properties')) || keyContains('x-sst') || key === 'event_name') {
      Object.delete(object, key);
    } else if (keyContains('user_properties')) {
      Object.delete(object, key);
      object.user_properties = value;
    } else if (key === 'items') {
      Object.delete(object, key);
      const uniqueGroups = value.reduce((acc, currentObject) => {
        for (var key in currentObject) {
          if (currentObject.hasOwnProperty(key)) {
            acc[key] = currentObject[key];
          }
        }
        return acc;
      }, {});
      object.item_parameters = uniqueGroups;
    } else if (key !== 'event_parameters') {
      object.event_parameters = object.event_parameters || {};
      if (key === 'user_id') {
        object.user_properties = object.user_properties || {};
        object.user_properties[key] = value;
      } else {
        object.event_parameters[key] = value;
      }
      Object.delete(object, key);
    }
  });
  
  return object;
}

function combineNewParams(currentParams, newParams) {
  let updatedParams = currentParams || {};

  // Iterate over newParams object
  Object.entries(newParams).forEach(data => {
    const scope = data[0];
    const params = data[1];
    
    if (updatedParams[scope]) {
      // If the scope already exists, update the params
      params.forEach(param => {
        const paramName = param.name;
        Object.delete(param, 'name');  // Manually delete 'name' field
        updatedParams[scope][paramName] = param;  // Assign the rest of the object
      });
    } else {
      updatedParams[scope] = {};
      
      params.forEach(param => {
        const paramName = param.name;
        Object.delete(param, 'name');  // Manually delete 'name' field
        updatedParams[scope][paramName] = param;
      });
    }
  });

  return updatedParams;  // Return the updatedParams object
}

function removeKeyFromObject(obj, keyToRemove) {
    // Check if the object is an array
    if (getType(obj) === 'array') {
        for (let i = obj.length - 1; i >= 0; i--) {
            if (typeof obj[i] === 'object' && obj[i] !== null) {
                removeKeyFromObject(obj[i], keyToRemove);
            } else if (obj[i].key === keyToRemove) {
                obj.splice(i, 1);
            }
        }
    } else if (getType(obj) === 'object' && obj !== null) {
        for (const key in obj) {
            if (key === keyToRemove) {
                Object.delete(obj, key);
            } else if (typeof obj[key] === 'object') {
                removeKeyFromObject(obj[key], keyToRemove);
            }
        }
    }
}

function setUpdatedTimestamp(timestamp) {
  timestamp = timestamp ? timestamp : getTimestampMillis();
  
  Firestore.write(collection + '/last_modified', {'SAFE_GUARD':'DO NOT REMOVE', 'updated_at': timestamp },{ projectId: projectId })
    .then(() => {
      templateDataStorage.setItemCopy('lastUpdate', timestamp);
      log('Documentation: Set updated timestamp');
    });
  
  return;
}

function cachedDataExists() {
  let cachedContent  = templateDataStorage.getItemCopy('firestoreData') || {},
      lastFetch      = templateDataStorage.getItemCopy('lastFetched') || 0,
      lastUpdate     = templateDataStorage.getItemCopy('lastUpdate') || 0,
      maxDayOldData  = getTimestampMillis() - (24 * 60 * 60 * 1000);
  
  // Returns false if:
  // - Previous data doesn't exists,
  // - The Firestore data has been updated more recently than last fetch,
  // - More than one day has passed since last fetch (fail safe, if manual update of Firestore Data).
  if (!cachedContent || lastUpdate > lastFetch || maxDayOldData > lastFetch) {
    return false;
  }
  
  return cachedContent;
}

function lastDocumentationUpdate() {
  let poll             = templateDataStorage.getItemCopy('15minPoll') || 0,
      max15MinOldCheck = getTimestampMillis() - 15 * 60 * 1000;
  
  if (max15MinOldCheck > poll) {
    Firestore.read(collection + '/last_modified', { projectId: projectId })
      .then((result) => {
        templateDataStorage.setItemCopy('lastUpdate', result.data.updated_at);
        templateDataStorage.setItemCopy('15minPoll', getTimestampMillis());
    })
    .catch((error) => {
      if (error.reason === 'not_found') {
        setUpdatedTimestamp();
        return;
      }
      log('Error: ', error);
    });
  }
}

function setTemplateStorages(firestoreData) {
  let modifiedData;
  firestoreData.forEach(document => document.id.indexOf('last_modified') > -1 ? modifiedData = document.data : { data: { updated_at: 0 } });

  templateDataStorage.setItemCopy('firestoreData', firestoreData);
  templateDataStorage.setItemCopy('lastFetched', getTimestampMillis());
  templateDataStorage.setItemCopy('lastUpdate', modifiedData.updated_at);

  log('Documentation: Firestore data saved to cache.');

  return;
}

function generateHtmlPage(firestoreData) {
  let htmlContent = '<!DOCTYPE html> <html lang="en"> <head> <meta charset="UTF-8"> <meta name="viewport" content="width=device-width, initial-scale=1.0">   <link rel="stylesheet" href="https://early.webawesome.com/webawesome@3.0.0-alpha.4/dist/themes/default.css" /><script type="module" src="https://early.webawesome.com/webawesome@3.0.0-alpha.4/dist/webawesome.loader.js"></script><script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.6/dist/chart.umd.min.js"></script> <title>Tracking documentation</title> <style> body { display: grid; grid-template-areas: "header header" "nav main" "footer footer"; grid-template-columns: 400px 1fr; grid-template-rows: 100px 1fr 50px; height: 100vh; margin: 0; font-family: Arial, Helvetica, sans-serif; } header { grid-area: header; padding: 10px; color: #495057; display: flex; justify-content: space-between; align-items: center; box-shadow: 0 2px 4px rgba(0,0,0,0.1); } nav { grid-area: nav; flex: 1; display: flex; flex-flow: column; overflow-y: auto; padding: 5px; margin: 10px; } #events, #events-responsive div { display: flex; flex-flow: column; padding: 0; gap: 5px; overflow-y: auto; } nav wa-button, #events wa-button, #events-responsive wa-button { width: 100%; } #events wa-button, #events-responsive wa-button { --border-color-hover: #e4e5e9; --background-color-hover: #fff; } #events ~ wa-divider { margin-top: auto; } #events-responsive wa-button { gap: 5px; } .wa-block-spacing-l > * + * { margin-block-start: var(--wa-space-l); } wa-radio, wa-checkbox, wa-switch { width: fit-content; } nav:last-child { margin-top: auto; } main { grid-area: main; flex: 1; overflow-y: auto; padding: 20px; margin: 10px; } footer { grid-area: footer; background-color: #333; color: #fff; justify-content: center; display: flex; } .border { border: 1px solid #dee2e6; border-radius: 10px; } .upper-section h2 { font-size: 1.5rem; } .lower-section :is(h1,h2,h3,h4,h5,h6) { color: #007bff; font-size: 1.5rem; border-bottom: 2px solid #dee2e6; } wa-drawer + wa-button { visibility: hidden; } wa-dialog { --width: 60%; } #new-params { display: none; } #required-fields { --indent-guide-width: 1px; } table { width: 100%; } th { text-align: left; font-weight: bold; } main table { border-collapse: separate; border-spacing: 0; border-radius: 15px; overflow: hidden; box-shadow: 0 4px 8px rgba(0, 0, 0, 0.1); } main th { background-color: #f3f4f6; color: #333; padding: 12px 15px; border-bottom: 2px solid #ddd; } main th:not(:first-child) { cursor: pointer; } main td { background-color: #ffffff; padding: 12px 15px; color: #555; border-bottom: 1px solid #eee; } main tr:nth-child(odd) td { background-color: #f9fafb; } main table tr:first-child th:first-child { border-top-left-radius: 15px; } main table tr:first-child th:last-child { border-top-right-radius: 15px; } main table tr:last-child td:first-child { border-bottom-left-radius: 15px; } main table tr:last-child td:last-child { border-bottom-right-radius: 15px; } wa-callout { display: none; } #clear-form { float: right; } @media only screen and (max-width: 1000px) { wa-drawer + wa-button { visibility: visible; } h1 { visibility: hidden; } nav { display: none; } main { grid-column-start: nav; grid-column-end: main; } table thead { display: none; } table *:not(thead) { display: block; width: 100%; } table td::before { content: attr(data-label); position: relative; left: 10px; font-weight: bold; } } </style> </head> <body> <header> <div> <wa-drawer id="events-responsive" label="Events" light-dismiss with-header with-footer class="drawer-scrolling"> <div> </div> <wa-button slot="footer" variant="brand" data-drawer="close">Close</wa-button> </wa-drawer> <wa-button>Events</wa-button> <script> const drawer = document.querySelector(".drawer-scrolling"); const openButton = drawer.nextElementSibling; openButton.addEventListener("click", () => drawer.open = true); </script> </div> <h1>Automated Tracking Documentation</h1> <div> <wa-button-group> <wa-button id="undocumented-button" appearance="outlined" variant="brand">Everything\'s up to date</wa-button> <wa-dropdown placement="bottom-end"> <wa-button slot="trigger" variant="brand" caret> <wa-visually-hidden>More options</wa-visually-hidden> </wa-button> <wa-menu> <wa-menu-item title="Download all tracking documentation" onclick="downloadFirestoreData()">Download as JSON</wa-menu-item> </wa-menu> </wa-dropdown> </wa-button-group> </div> </header> <nav class="border"> <wa-button size="large" appearance="text" variant="neutral" onclick="generateOverview()">Overview</wa-button> <wa-divider></wa-divider> <div id="events"> </div> <wa-divider></wa-divider> <wa-button id="document-new-event" size="large" appearance="filled" variant="brand">Document new event</wa-button> </nav> <main class="border"> <wa-callout variant="warning"> <wa-icon slot="icon" name="triangle-exclamation" variant="regular"></wa-icon> <strong>Your event needs an update</strong><br /> Please update the documentation according to received information. </wa-callout> <div class="upper-section"> <h2 id="event-name">Overview</h2> <p id="event-description">Overview of events in use.</p> </div> <wa-tab-group> <wa-tab slot="nav" panel="event">Event parameters</wa-tab> <wa-tab slot="nav" panel="user">User properties</wa-tab> <wa-tab slot="nav" panel="item">Item parameters</wa-tab> <wa-tab-panel name="event">No documented event parameters for this event.</wa-tab-panel> <wa-tab-panel name="user">No documented user properties for this event.</wa-tab-panel> <wa-tab-panel name="item">No documented item parameters for this event.</wa-tab-panel> </wa-tab-group> </main> <wa-dialog id="new-event" label="Document new event" with-header class="dialog-header"> <form class="wa-block-spacing-l" onsubmit="submitEvent(event);"> <wa-input label="Event name" placeholder="Placeholder"></wa-input> <wa-textarea label="Description" placeholder="Description of event"></wa-textarea> <wa-select id="documented-params" label="Select parameters / properties" multiple clearable> <small scope="event">Event parameters</small> <wa-divider></wa-divider> <small scope="user">User properties</small> <wa-divider></wa-divider> <small scope="item">Item paramters</small> </wa-select> <wa-switch id="switch-new-params">Create new parameters / properties</wa-switch> <div id="new-params"> <table id="new-params-table"> <thead> <th>Scope</th> <th>Name</th> <th>Type</th> <th>Example</th> <th>Description</th> <th>Action</th> </thead> <tbody> <tr> <td data-label="Scope"> <wa-select placeholder="Event parameter" value="event"> <wa-option value="event">Event parameter</wa-option> <wa-option value="user">User property</wa-option> <wa-option value="item">Item parameter</wa-option> </wa-select> </td> <td data-label="Name"><wa-input placeholder="Name"></wa-input></td> <td data-label="Type"> <wa-select placeholder="String" value="string"> <wa-option value="string">String</wa-option> <wa-option value="integer">Integer</wa-option> <wa-option value="float">Float</wa-option> <wa-option value="boolean">Boolean</wa-option> <wa-option value="timestamp">Timestamp</wa-option> </wa-select> </td> <td data-label="Example"><wa-input placeholder="Example"></wa-input></td> <td data-label="Description"><wa-input placeholder="Description"></wa-input></td> <td data-label="Action"> <div> <wa-icon-button name="plus" label="Add new row"></wa-icon-button> <wa-icon-button name="minus" label="Remove row" style="visibility:hidden;"></wa-icon-button> </div> </td> </tr> </tbody> </table> </div> <br /> <wa-switch id="selection-required">Set required fields</wa-switch> <br /> <wa-tree id="required-fields" style="display:none;" selection="multiple" > <wa-tree-item scope="event" disabled> Event parameters </wa-tree-item> <wa-tree-item scope="user" disabled> User properties </wa-tree-item> <wa-tree-item scope="item" disabled> Item properties </wa-tree-item> </wa-tree> <div> <wa-button type="submit">Submit new event</wa-button> <wa-button id="clear-form" appearance="outlined">Clear form</wa-button> </div> <script> </script> </form> </wa-dialog> <script> const firestoreData = '+ JSON.stringify(firestoreData) +'; firestoreData.forEach(entry => { entry.id = entry.id.replace("'+ data.firestoreCollection +'/",""); delete entry.data.SAFE_GUARD; }); const events = firestoreData.find(item => item.id === "events")?.data || {}; const last_modified = firestoreData.find(item => item.id === "last_modified")?.data || {}; const undocumented = firestoreData.find(item => item.id === "undocumented")?.data || {}; const eventParams = firestoreData.find(item => item.id === "event_parameters")?.data || {}; const userProps = firestoreData.find(item => item.id === "user_properties")?.data || {}; const itemParams = firestoreData.find(item => item.id === "item_parameters")?.data || {}; let undocumentedEvents = []; let sortDirection = false; const eventList = document.querySelector("#events"); const eventListResponsive = document.querySelector("#events-responsive div"); const navLists = [eventList, eventListResponsive]; const mainElement = document.querySelector("main"); if (Object.keys(undocumented).length > 0) { const undocumentedButton = document.querySelector("#undocumented-button"); const text = document.createTextNode("Update needed"); const prefix = createIcon("triangle-exclamation","prefix"); undocumentedButton.innerText = ""; undocumentedButton.setAttribute("appearance", "filled"); undocumentedButton.appendChild(prefix); undocumentedButton.appendChild(text); undocumentedButton.addEventListener("click", function () { resetMain(); const divider = document.createElement("wa-divider"); mainElement.querySelector("#event-name").innerText = "Undocumented data received"; mainElement.querySelector("#event-description").innerText = "These fields below are either new events which needs to be documented or old events which has received new data. If there is no data in any of the columns, the event has received a new parameter/property which it has not previously been associated with and needs to be updated with it either required or optional."; mainElement.querySelector("wa-tab-group").style.display = "none"; mainElement.querySelector("wa-callout").style.display = "none"; mainElement.appendChild(divider); mainElement.appendChild(createUndocumentedTable()); function createUndocumentedTable() { const table = document.createElement("table"); const tableBody = document.createElement("tbody"); table.setAttribute("id","undocumented-table"); const tableHeader = document.createElement("thead"); const columnNames = { "Event name":"20%;", "New event parameters":"25%;", "New user properties":"25%", "New item parameters":"25%", "Action":"5%", }; const scopeIndex = { "event_parameters": eventParams, "user_properties": userProps, "item_parameters": itemParams }; Object.entries(columnNames).forEach(([colName, colWidth]) => { const column = document.createElement("th"); column.setAttribute("style","width:" + colWidth); column.innerText = colName; tableHeader.appendChild(column); }); table.appendChild(tableHeader); table.appendChild(tableBody); Object.entries(undocumented).forEach(([event, scopes]) => { const tableRow = createTableRow(); const documentEventCell = document.createElement("td"); const documentEventButton = document.createElement("wa-icon-button"); tableRow.appendChild(createTableCell(event)); documentEventCell.setAttribute("style","text-align:center;"); documentEventButton.setAttribute("name","pen-to-square"); Object.entries(scopeIndex).forEach(([scope, alreadyDocumented]) => { const details = undocumented[event][scope]; if (!details) { tableRow.appendChild(createTableCell()); return; } let documentedKeys = events[event]?.required_parameters || []; documentedKeys = documentedKeys.concat(events[event]?.optional_parameters); const newFields = Object.keys(details).filter(param => !documentedKeys.includes(param)); tableRow.appendChild(createTableCell(newFields.join(", "))); }); documentEventButton.addEventListener("click", (event) => { const eventName = event.target.parentNode.parentNode.querySelector("td").innerText; const dialog = document.querySelector("#new-event"); const undocumentedEvent = undocumented[eventName]; const documentedEvent = events[eventName]; clearForm(); const allParams = [].concat(eventParams, userProps, itemParams).reduce((acc, array, index) => { let scopePrefix; switch (index) { case 0: scopePrefix = "event"; break; case 1: scopePrefix = "user"; break; case 2: scopePrefix = "item"; break; } Object.keys(array).forEach(param => { acc[param] = scopePrefix; }); return acc; }, {}); const alreadyDocumentedParams = Object.entries(undocumentedEvent).flatMap(([scope,details]) => { return Object.keys(details).filter(param => allParams.hasOwnProperty(param)); }); const newParams = Object.entries(undocumentedEvent).reduce((acc, [scope, details]) => { Object.keys(details).forEach(param => { if (!allParams.hasOwnProperty(param)) { acc[param] = scope.split("_")[0]; } }); return acc; }, {}); dialog.querySelector("wa-input[label=\'Event name\']").setAttribute("value", eventName); dialog.querySelector("#documented-params").value = alreadyDocumentedParams.map(param => allParams[param] + "-" + param); if(Object.keys(newParams).length > 0) { const switchNewParams = dialog.querySelector("#switch-new-params"); if (!switchNewParams.checked) switchNewParams.click(); const tbody = dialog.querySelector("#new-params-table tbody"); const initialRow = tbody.querySelector("tr"); tbody.innerHTML = ""; Object.entries(newParams).forEach(([paramName, scope]) => { const newRow = initialRow.cloneNode(true); const exampleValue = removeFirstAndLastQuotes(JSON.stringify(findKey(undocumentedEvent, paramName))); const scopeSelect = newRow.querySelector("td[data-label=\'Scope\'] wa-select"); scopeSelect.setAttribute("value",scope); const nameInput = newRow.querySelector("td[data-label=\'Name\'] wa-input"); nameInput.setAttribute("value", paramName); const typeSelect = newRow.querySelector("td[data-label=\'Type\'] wa-select"); typeSelect.setAttribute("value", "string"); const exampleInput = newRow.querySelector("td[data-label=\'Example\'] wa-input"); exampleInput.setAttribute("value", exampleValue); tbody.appendChild(newRow); }); updateMinusButton(); function findKey(obj, keyToFind) { let result; if (typeof obj !== "object" || obj === null) { return result || ""; } if (obj.hasOwnProperty(keyToFind)) { return obj[keyToFind]; } for (let key in obj) { if (obj.hasOwnProperty(key)) { const value = obj[key]; if (typeof value === "object") { result = findKey(value, keyToFind); if (result !== undefined) { return result || ""; } } } } return result; } function removeFirstAndLastQuotes(str) { if (str.startsWith(\'"\') && str.endsWith(\'"\')) { return str.slice(1, -1); } return str; } } if (documentedEvent && documentedEvent.required_parameters.length > 0) { const switchRequiredParams = dialog.querySelector("#selection-required"); const tree = document.querySelector("#required-fields"); const requiredParams = documentedEvent.required_parameters; document.addEventListener("wa-after-show", () => { if (!switchRequiredParams.checked) { switchRequiredParams.click(); } Array.from(tree.querySelectorAll("wa-tree-item")).forEach(node => { const param = node.innerText; const parentNode = node.parentNode; if (requiredParams.includes(param)) { parentNode.setAttribute("expanded", true); node.setAttribute("selected", true); } }); }); }; dialog.open = true; }); documentEventCell.appendChild(documentEventButton); tableRow.appendChild(documentEventCell); table.appendChild(tableRow); }); table.querySelectorAll("thead th").forEach((header, index) => { header.addEventListener("click", function() { sortTableByColumn(table, index); }); }); function createTableCell(content) { const tableCell = document.createElement("td"); if (!content) { tableCell.style["font-style"] = "italic"; tableCell.style.opacity = 0.5; tableCell.innerHTML = "No data"; } else { tableCell.innerHTML = content; } return tableCell; } return table; } }); Object.keys(undocumented).forEach(event => undocumentedEvents.push(event)); } generateOverview(); const dialog = document.querySelector("#new-event"); let openForm = document.querySelector("#document-new-event"); openForm.addEventListener("click", () => dialog.open = true); document.addEventListener("DOMContentLoaded", function () { navLists.forEach(list => { Object.entries(events).forEach(([event, details]) => { const eventName = event; const listItem = document.createElement("wa-button"); listItem.setAttribute("appearance","tinted"); listItem.setAttribute("variant","neutral"); listItem.innerText = eventName; if (undocumentedEvents.includes(eventName)) { const suffix = createIcon("triangle-exclamation","suffix"); listItem.appendChild(suffix); } list.appendChild(listItem); }); }); navLists.forEach(list => { const buttons = list.querySelectorAll("wa-button"); buttons.forEach(button => { button.addEventListener("click", () => { Object.entries(events).forEach(([event, details]) => { if (event !== button.innerText) return; const eventName = event; const eventDescription = details.event_description; const requiredParamsList = details.required_parameters || []; const allParams = requiredParamsList.concat(details.optional_parameters); const eventNameElement = mainElement.querySelector("#event-name"); const descriptionElement = mainElement.querySelector("#event-description"); resetMain(); eventNameElement.innerText = eventName; descriptionElement.innerText = eventDescription; mainElement.querySelector("wa-callout").style.display = undocumentedEvents.includes(eventName) ? "block" : "none"; const activeTab = mainElement.querySelector("wa-tab[active]")?.getAttribute("panel") || "event"; addToScopeTab(activeTab, allParams, requiredParamsList); }); }); }); }); document.addEventListener("wa-tab-show", function (event) { const tabShown = event.detail.name; const eventName = mainElement.querySelector("h2").innerText; const eventData = events[eventName]; const requiredFields = eventData.required_parameters; const allParams = requiredFields.concat(eventData.optional_parameters); addToScopeTab(tabShown, allParams, requiredFields); }); function resetEvent(scope, emptyList) { const scopeTab = mainElement.querySelector("wa-tab-panel[name="+scope+"]"); const suffix = scope === "user" ? " properties":" parameters"; scopeTab.querySelectorAll("table").forEach(element => element.remove()); if (emptyList) { scopeTab.innerHTML = "No documented " + scope + suffix + " for this event."; } else { scopeTab.innerHTML = ""; } return; }; function createTable(activeScope, parameterList = [], requiredFields = []) { const table = document.createElement("table"); const tableBody = document.createElement("tbody"); const tableHeader = document.createElement("thead"); const columnNames = { "Required":"5%;", "Name":"25%;", "Type":"10%", "Example":"20%", "Description":"40%" }; const scopeRestriction = { "event": eventParams, "user": userProps, "item": itemParams, }; Object.entries(columnNames).forEach(([colName, colWidth]) => { const column = document.createElement("th"); column.setAttribute("style","width:" + colWidth); column.innerText = colName; tableHeader.appendChild(column); }); table.appendChild(tableHeader); table.appendChild(tableBody); if (parameterList.length > 0) { parameterList.forEach(param => { const data = scopeRestriction[activeScope]; if (!Object.keys(data).includes(param)) return; const paramRow = createTableRow(); const requiredCell = requiredFields.includes(param) ? createTableCell("Required",true) : createTableCell("Required",""); const nameCell = createTableCell("Name", param); paramRow.appendChild(requiredCell); paramRow.appendChild(nameCell); const tableColumns = ["Type", "Example", "Description"]; tableColumns.forEach(cellValue => { const dataCell = createTableCell(cellValue, data[param][cellValue.toLowerCase()]); paramRow.appendChild(dataCell); }); table.appendChild(paramRow); }); if (!table.querySelector(":scope > tr")) { return resetEvent(activeScope, emptyList = true); } table.querySelectorAll("thead th").forEach((header, index) => { if (index === 0) return; header.addEventListener("click", function() { sortTableByColumn(table, index); }); }); return table; } function createTableCell(label, content) { const tableCell = document.createElement("td"); tableCell.setAttribute("data-label", label); if (label === "Required") { const icon = document.createElement("wa-icon"); icon.setAttribute("name", "certificate"); icon.setAttribute("style", "color: #0070ef;font-size: 1.2rem;"); tableCell.setAttribute("style", "text-align: center"); content ? tableCell.appendChild(icon) : tableCell.innerText = "" ; } else if (!content) { tableCell.style["font-style"] = "italic"; tableCell.style.opacity = 0.5; tableCell.innerText = "No data"; } else { tableCell.innerText = content; } return tableCell; }; }; function addToScopeTab(scope, paramsArray = [], requiredFields = []) { resetEvent(scope, paramsArray === 0); const scopeTab = mainElement.querySelector("wa-tab-panel[name="+scope+"]"); const scopeTable = createTable(scope, paramsArray, requiredFields); if (!scopeTable) return; scopeTab.appendChild(scopeTable); }; }); function generateOverview() { resetMain(); mainElement.querySelector("wa-tab-group").style.display = "none"; const table = document.createElement("table"); const thead = document.createElement("thead"); const tbody = document.createElement("tbody"); const divider = document.createElement("wa-divider"); const headers = ["Event","Required fields","Optional fields","Status","Action"]; headers.forEach(header => { const cell = document.createElement("th"); cell.innerText = header; thead.appendChild(cell); }); Object.keys(events).forEach(eventName => { const event = events[eventName]; const row = document.createElement("tr"); const eventCell = document.createElement("td"); eventCell.innerText = eventName; row.appendChild(eventCell); const requiredCell = document.createElement("td"); requiredCell.innerText = event.required_parameters ? event.required_parameters.join(", ") : "None"; row.appendChild(requiredCell); const optionalCell = document.createElement("td"); optionalCell.innerText = event.optional_parameters ? event.optional_parameters.join(", ") : "None"; row.appendChild(optionalCell); const statusCell = document.createElement("td"); statusCell.innerText = undocumentedEvents.includes(eventName) ? "Update needed": "Up to date"; row.appendChild(statusCell); const actionCell = document.createElement("td"); if (Object.keys(events).includes(eventName) && Object.keys(events[eventName]).includes("chart_data")) actionCell.appendChild(createIcon("chart-line", "suffix")); row.appendChild(actionCell); tbody.appendChild(row); }); table.appendChild(thead); table.appendChild(tbody); mainElement.querySelector("div").appendChild(divider); mainElement.appendChild(table); table.querySelectorAll("thead th").forEach((header, index) => { header.addEventListener("click", function() { sortTableByColumn(table, index); }); }); table.querySelectorAll("tbody tr").forEach((row, index) => { const eventRow = row.cells[0].innerText; if (events[eventRow].chart_data) {; row.style="cursor:pointer;"; row.addEventListener("click", function() { expandOverviewRow(table, index, eventRow); }); }; }); } function createTableRow() { const tableRow = document.createElement("tr"); return tableRow; }; function createIcon(icon, placement="suffix") { const triangle = document.createElement("wa-icon"); triangle.setAttribute("slot", placement); triangle.setAttribute("name", icon); return triangle; }; function sortTableByColumn(table, columnIndex) { const rows = Array.from(table.querySelectorAll("tr")); sortDirection = !sortDirection; const sortedRows = rows.sort((a, b) => { const aText = a.querySelectorAll("td")[columnIndex].textContent.toLowerCase().replace("no data","zzzzz").trim(); const bText = b.querySelectorAll("td")[columnIndex].textContent.toLowerCase().replace("no data","zzzzz").trim(); if (!isNaN(aText) && !isNaN(bText)) { return sortDirection ? aText - bText : bText - aText; } else { return sortDirection ? aText.localeCompare(bText) : bText.localeCompare(aText); } }); sortedRows.forEach(row => table.appendChild(row)); const sortArrow = document.createElement("wa-icon"); sortArrow.setAttribute("style", "float:inline-end;"); table.querySelectorAll("th").forEach(header => { header.querySelector("wa-icon")?.remove(); }); sortArrow.setAttribute("name", sortDirection ? "arrow-down-a-z" : "arrow-up-a-z"); table.querySelectorAll("th")[columnIndex].appendChild(sortArrow); }; function updateMinusButton() { const rows = document.querySelectorAll("#new-params-table tbody tr"); const showMinus = rows.length > 1; rows.forEach(row => { const minusButton = row.querySelector("[name=\\\'minus\\\']"); minusButton.style.visibility = showMinus ? "visible" : "hidden"; }); }; function clearForm() { const form = document.querySelector("wa-dialog form"); const switchNewParams = form.querySelector("#switch-new-params"); const requiredSelectionMode = form.querySelector("#required-fields"); form.reset(); form.querySelector("#new-params").style.display = switchNewParams.checked ? "block" : "none"; form.querySelector("#required-fields").style.display = requiredSelectionMode.checked ? "block" : "none"; }; document.addEventListener("DOMContentLoaded", () => { const switchNewParams = document.querySelector("#switch-new-params"); const inputTable = document.querySelector("#new-params"); const requiredSelectionMode = document.querySelector("#selection-required"); const tree = document.querySelector("#required-fields"); const newParamsTableBody = document.querySelector("#new-params-table tbody"); const oldParamsSelect = document.querySelector("#documented-params"); const updateSelectionEvent = new Event("wa-selection-change"); switchNewParams.addEventListener("wa-change", () => { inputTable.style.display = switchNewParams.checked ? "block" : "none"; updateRequiredFields(); }); document.getElementById("clear-form").addEventListener("click", function() { clearForm(); }); newParamsTableBody.addEventListener("click", event => { const target = event.target; if (target.name === "plus") { addRow(target); } else if (target.name === "minus") { removeRow(target); } }); newParamsTableBody.addEventListener("focusout", handleParamsChange); requiredSelectionMode.addEventListener("wa-change", handleSelectionModeChange); oldParamsSelect.addEventListener("wa-change", handleParamsChange); populateDocumentedOptions(); function populateDocumentedOptions() { const allParams = [].concat(eventParams, userProps, itemParams).forEach((array, index) => { let scopePrefix; switch (index) { case 0: scopePrefix = "event-"; break; case 1: scopePrefix = "user-"; break; case 2: scopePrefix = "item-"; break; } Object.keys(array).reverse().forEach(param => { const value = scopePrefix + param; const optionElement = document.createElement("wa-option"); optionElement.setAttribute("value", value); optionElement.innerText = param; switch (index) { case 0: document.querySelector("#documented-params [scope=\'event\']").insertAdjacentElement("afterend",optionElement); break; case 1: document.querySelector("#documented-params [scope=\'user\']").insertAdjacentElement("afterend",optionElement); break; case 2: document.querySelector("#documented-params [scope=\'item\']").insertAdjacentElement("afterend",optionElement); break; } }); }); } function handleSelectionModeChange() { tree.style.display = requiredSelectionMode.checked ? "block" : "none"; if (requiredSelectionMode.checked) { updateRequiredFields(); } else { resetTree(); } } function handleParamsChange() { if (requiredSelectionMode.checked) { updateRequiredFields(); } } function updateRequiredFields() { const params = [...getNewParams(), ...getOldParams()]; const paramKeys = new Set(params.map(p => `${p.scope}-${p.name}`)); const existingItems = new Map(); tree.querySelectorAll("wa-tree-item[scope]").forEach(scopeItem => { const scope = scopeItem.getAttribute("scope"); const children = scopeItem.querySelectorAll("wa-tree-item"); children.forEach(child => { const name = child.textContent.trim(); const key = `${scope}-${name}`; const selected = child.hasAttribute("selected"); existingItems.set(key, { item: child, selected }); }); }); params.forEach(({ scope, name }) => { const key = `${scope}-${name}`; if (!existingItems.has(key)) { const scopeItem = tree.querySelector(`wa-tree-item[scope="${scope}"]`); if (scopeItem) { const item = document.createElement("wa-tree-item"); item.textContent = name; scopeItem.appendChild(item); } } }); existingItems.forEach(({ item }, key) => { if (!paramKeys.has(key)) { item.closest("wa-tree-item[scope]").dispatchEvent(updateSelectionEvent); item.remove(); } }); updateScopeItemsDisabled(); sortTreeItems(); } function getNewParams() { if (getComputedStyle(document.querySelector("#new-params")).display === "block") { return Array.from(newParamsTableBody.querySelectorAll("tr")) .map(row => { const scope = row.querySelector("td:nth-child(1) wa-select")?.value || row.querySelector("td:nth-child(1) wa-select").getAttribute("value"); const name = row.querySelector("td:nth-child(2) wa-input")?.value; return scope && name ? { scope, name } : null; }) .filter(Boolean); } else { return []; } } function getOldParams() { return Array.from(oldParamsSelect.selectedOptions).map(option => { const value = option.value; const index = value.indexOf("-"); if (index !== -1) { const scope = value.substring(0, index); const name = value.substring(index + 1); return { scope, name }; } else { return { scope: "", name: value }; } }); } function updateScopeItemsDisabled() { tree.querySelectorAll("wa-tree-item[scope]").forEach(scopeItem => { const hasChildren = scopeItem.querySelector("wa-tree-item") !== null; const hasSelectedChildren = scopeItem.querySelector("wa-tree-item[selected]") !== null; if (hasChildren) { scopeItem.removeAttribute("disabled"); } else { scopeItem.setAttribute("disabled", ""); } if (!hasSelectedChildren) { scopeItem.setAttribute("selected",""); scopeItem.removeAttribute("selected"); } }); } function sortTreeItems() { tree.querySelectorAll("wa-tree-item[scope]").forEach(scopeItem => { const items = Array.from(scopeItem.querySelectorAll("wa-tree-item")); items.sort((a, b) => a.textContent.localeCompare(b.textContent)); items.forEach(item => scopeItem.appendChild(item)); }); } function resetTree() { tree.querySelectorAll("wa-tree-item[scope]").forEach(scopeItem => { scopeItem.removeAttribute("selected"); scopeItem.querySelectorAll("wa-tree-item").forEach(item => item.remove()); scopeItem.removeAttribute("disabled"); }); } function addRow(row) { const newRow = row.closest("tr").cloneNode(true); document.getElementById("new-params-table").querySelector("tbody").appendChild(newRow); updateMinusButton(); } function removeRow(row) { row.closest("tr").remove(); updateMinusButton(); updateRequiredFields(); } }); function resetMain() { mainElement.querySelector("#event-name").innerText = "Overview"; mainElement.querySelector("#event-description").innerText = "Overview of events in use"; mainElement.querySelectorAll("table")?.forEach(element => element.remove()); mainElement.querySelectorAll("wa-callout")?.forEach(element => element.style.display = "none"); mainElement.querySelectorAll("wa-divider")?.forEach(element => element.remove()); mainElement.querySelectorAll("wa-tab-group")?.forEach(element => element.style.display = "block"); }; function expandOverviewRow(table, index, eventName) { const tbody = table.querySelector("tbody"); const rows = tbody.querySelectorAll("tr"); const clickedRow = rows[index]; if (clickedRow.nextElementSibling && clickedRow.nextElementSibling.classList.contains("expanded-row")) { tbody.removeChild(clickedRow.nextElementSibling); return; } const eventData = events[eventName]?.chart_data; const expandedRows = tbody.querySelectorAll(".expanded-row"); expandedRows.forEach(function(row) { tbody.removeChild(row); }); const expandedRow = document.createElement("tr"); expandedRow.classList.add("expanded-row"); const expandedCell = document.createElement("td"); expandedCell.colSpan = table.querySelectorAll("thead th").length; const chartContainer = document.createElement("div"); chartContainer.style.width = "100%"; chartContainer.style.height = "400px"; const canvas = document.createElement("canvas"); canvas.style.width = "100%"; canvas.style.height = "100%"; chartContainer.appendChild(canvas); expandedCell.appendChild(chartContainer); expandedRow.appendChild(expandedCell); tbody.insertBefore(expandedRow, clickedRow.nextElementSibling); const ctx = canvas.getContext("2d"); const chartData = eventData; const chartOptions = { responsive: true, maintainAspectRatio: false, scales: { y: { beginAtZero: true, max: 100, ticks: { callback: function(value) { return value + "%"; } } } }, plugins: { legend: { display: true, position: "top", }, title: { display: true, text: "Event Reliability Over Past Month" } } }; const myChart = new Chart(ctx, { type: "line", data: chartData, options: chartOptions }); } function downloadFirestoreData() { const jsonData = JSON.stringify(firestoreData, null, 2); const blob = new Blob([jsonData], { type: "application/json" }); const link = document.createElement("a"); link.download = "tracking_documentation.json"; link.href = URL.createObjectURL(blob); document.body.appendChild(link); link.click(); document.body.removeChild(link); } async function submitEvent(event) { event.preventDefault(); const form = document.querySelector("wa-dialog form"); const eventName = form.querySelector("wa-input[label=\\\'Event name\\\']").value; const eventDescription = form.querySelector("wa-textarea[label=\\\'Description\\\']").value; const requiredParams = Array.from(document.querySelectorAll("wa-tree-item[slot=\\\'children\\\'][selected]")) .map(param => param.innerText.trim()); const oldParams = form.querySelector("wa-select#documented-params")?.value; const alreadyDocumentedParams = oldParams ? oldParams.flatMap(param => param.split(/-(.*)/)[1]) : []; const formData = { event_name: eventName, event_description: eventDescription }; const newParams = parseTableRows(); const newParamsNames = Object.values(newParams).flat().map(obj => obj.name); const allParams = newParamsNames.concat(alreadyDocumentedParams); const optionalParams = allParams.filter(param => !requiredParams.includes(param)); if (requiredParams.length > 0) formData.required_parameters = requiredParams; if (Object.keys(newParams).length > 0) formData.new_parameters = newParams; if (optionalParams.length > 0) formData.optional_parameters = optionalParams; try { const response = await fetch(document.location.protocol + "//" + document.location.hostname + "' + data.endpoint + '_update", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(formData) }); if (!response.ok) throw new Error("Network response was not ok."); location.reload(); } catch (error) { console.error("Error:", error); } function parseTableRows() { const suffixes = {"event":"_parameters", "user":"_properties", "item":"_parameters"}; const result = {}; const tableRows = Array.from(document.querySelectorAll("wa-dialog form tbody tr")); tableRows.forEach(row => { const scopeTd = row.querySelector("td[data-label=\\\'Scope\\\']"); const nameTd = row.querySelector("td[data-label=\\\'Name\\\']"); const typeTd = row.querySelector("td[data-label=\\\'Type\\\']"); const exampleTd = row.querySelector("td[data-label=\\\'Example\\\']"); const descriptionTd = row.querySelector("td[data-label=\\\'Description\\\']"); const scopeSelect = scopeTd.querySelector("wa-select"); const nameInput = nameTd.querySelector("wa-input"); const typeSelect = typeTd.querySelector("wa-select"); const exampleInput = exampleTd.querySelector("wa-input"); const descriptionInput = descriptionTd.querySelector("wa-input"); const scope = scopeSelect.value || scopeSelect.getAttribute("value"); const type = typeSelect.value || scopeSelect.getAttribute("value"); const name = nameInput.value || ""; const example = exampleInput.value || ""; const description = descriptionInput.value || ""; if (!scope || !name || !type) { return; } const key = scope + suffixes[scope]; if (!result.hasOwnProperty(key)) { result[key] = []; } const param = { name, type, example, description }; result[key].push(param); }); return result; }; }; </script> <footer> <p>Made by Theodor Öberg</p> </footer> </body> </html>';
  
return htmlContent;
}


___SERVER_PERMISSIONS___

[
  {
    "instance": {
      "key": {
        "publicId": "read_request",
        "versionId": "1"
      },
      "param": [
        {
          "key": "requestAccess",
          "value": {
            "type": 1,
            "string": "any"
          }
        },
        {
          "key": "headerAccess",
          "value": {
            "type": 1,
            "string": "any"
          }
        },
        {
          "key": "queryParameterAccess",
          "value": {
            "type": 1,
            "string": "any"
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "return_response",
        "versionId": "1"
      },
      "param": []
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "logging",
        "versionId": "1"
      },
      "param": [
        {
          "key": "environments",
          "value": {
            "type": 1,
            "string": "all"
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "access_firestore",
        "versionId": "1"
      },
      "param": [
        {
          "key": "allowedOptions",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "projectId"
                  },
                  {
                    "type": 1,
                    "string": "path"
                  },
                  {
                    "type": 1,
                    "string": "operation"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "*"
                  },
                  {
                    "type": 1,
                    "string": "*"
                  },
                  {
                    "type": 1,
                    "string": "read_write"
                  }
                ]
              }
            ]
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "access_template_storage",
        "versionId": "1"
      },
      "param": []
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "read_event_data",
        "versionId": "1"
      },
      "param": [
        {
          "key": "eventDataAccess",
          "value": {
            "type": 1,
            "string": "any"
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "access_response",
        "versionId": "1"
      },
      "param": [
        {
          "key": "writeResponseAccess",
          "value": {
            "type": 1,
            "string": "any"
          }
        },
        {
          "key": "writeHeaderAccess",
          "value": {
            "type": 1,
            "string": "specific"
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  }
]


___TESTS___

scenarios: []


___NOTES___

Created on 11/25/2024, 3:09:43 PM


